import Foundation
#if canImport(Combine)
import Combine
#else
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
#endif

struct LearningItem: Identifiable, Hashable {
    let sentence: Sentence
    let grammar: GrammarPoint
    let chapter: Chapter
    let index: Int
    let globalIndex: Int
    var id: String { sentence.id }
    var totalInGrammar: Int { grammar.examples.count }
}
struct ReviewItem: Identifiable, Hashable {
    let sentence: Sentence
    let grammar: GrammarPoint
    let chapter: Chapter
    var id: String { sentence.id }
}
enum ReviewOutcome: String, Codable { case correct, hard, incorrect, mastered }
enum ReviewOrder: String, Codable, CaseIterable { case mixed, reviewsFirst }
enum SentenceStatus: String {
    case locked, due, scheduled, completed, mastered
    var label: String {
        switch self {
        case .locked: return "学完本节后解锁"
        case .due: return "待背诵"
        case .scheduled: return "等待复习"
        case .completed: return "复习完成"
        case .mastered: return "已斩"
        }
    }
}
struct DailyPlanSettings: Codable, Equatable {
    var newPerDay = 10
    var reviewsPerDay = 30
    var order: ReviewOrder = .mixed
    var reminderEnabled = false
    var reminderHour = 20
    var reminderMinute = 0
    var isValid: Bool {
        (0...100).contains(newPerDay) && (1...200).contains(reviewsPerDay)
        && (0...23).contains(reminderHour) && (0...59).contains(reminderMinute)
    }
}
struct DailyActivity: Codable, Equatable {
    var learnedIDs: Set<String> = []
    var newIDs: [String] = []
    var reviewIDs: [String] = []
    var finishedIDs: Set<String> = []
    var extraNew = 0
    var extraReviews = 0
}
struct MemoryState: Codable, Equatable {
    var step = 0
    var relearningRemaining = 0
    var retryAfterSequence: Int?
    var hardCount = 0
    var lastOutcome: ReviewOutcome?
    var retired = false
}
struct ReviewProgress: Codable, Equatable {
    var unlockedAt: Date
    var firstCorrectAt: Date?
    var successfulReviews = 0
    var nextDueAt: Date?
    var lastReviewedAt: Date?
    var incorrectCount = 0
    var isMastered = false
    var memory: MemoryState?
    // A completed legacy cycle remains completed after upgrading.
    var isComplete: Bool { memory?.retired ?? (successfulReviews >= 4) }
    var needsReinforcement: Bool { (memory?.relearningRemaining ?? 0) > 0 }
    var isWeak: Bool { needsReinforcement || incorrectCount >= 3 || (memory?.hardCount ?? 0) >= 3 }
}
struct LearningProgress: Codable, Equatable {
    var schemaVersion = 2
    var learnedSentenceIDs: Set<String> = []
    var reviews: [String: ReviewProgress] = [:]
    var updatedAt: Date?
    // Optional additions keep v1 JSON decodable without discarding any old records.
    var plan: DailyPlanSettings? = DailyPlanSettings()
    var days: [String: DailyActivity]? = [:]
    var reviewSequence: Int? = 0
}
struct DailySummary {
    let learned: Int
    let newDone: Int
    let reviewDone: Int
    let newTarget: Int
    let reviewTarget: Int
    let newReady: Int
    let reviewReady: Int
    let remaining: Int
    let reinforcement: Int
    let overdue: Int
    let nextReadyAt: Date?
}

@MainActor final class LearningStore: ObservableObject {
    static let intervals = [1, 3, 7, 14, 30, 60, 120, 180]
    let curriculum: Curriculum
    let storageURL: URL
    @Published private(set) var progress = LearningProgress()
    @Published private(set) var saveError: String?
    @Published private(set) var loadError: String?
    private let calendar: Calendar
    private let orderedItems: [LearningItem]
    private let itemsByID: [String: LearningItem]
    private var protectsExistingFile = false

    init(curriculum: Curriculum, storageURL: URL? = nil, calendar: Calendar = .current) {
        self.curriculum = curriculum
        self.storageURL = storageURL ?? Self.defaultStorageURL
        self.calendar = calendar
        var ordered: [LearningItem] = []
        for chapter in curriculum.chapters {
            for grammar in chapter.grammar {
                for (index, sentence) in grammar.examples.enumerated() {
                    ordered.append(LearningItem(sentence: sentence, grammar: grammar, chapter: chapter, index: index, globalIndex: ordered.count))
                }
            }
        }
        orderedItems = ordered
        itemsByID = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        loadProgress()
    }
    static var defaultStorageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("iSpeak", isDirectory: true).appendingPathComponent("progress.json")
    }
    var settings: DailyPlanSettings { progress.plan ?? DailyPlanSettings() }
    var totalCount: Int { orderedItems.count }
    var learnedCount: Int { progress.learnedSentenceIDs.count }
    var nextLearning: LearningItem? { orderedItems.first { !progress.learnedSentenceIDs.contains($0.id) } }
    var completedGrammarIDs: Set<String> {
        Set(curriculum.allGrammarPoints.filter { !$0.examples.isEmpty && $0.examples.allSatisfy { progress.learnedSentenceIDs.contains($0.id) } }.map(\.id))
    }
    var masteredCount: Int { progress.reviews.values.filter(\.isMastered).count }
    var completedReviewCount: Int { progress.reviews.values.filter { $0.isComplete && !$0.isMastered }.count }
    var scheduledCount: Int { scheduledCount(now: Date()) }
    var nextReviewDate: Date? { nextReviewDate(now: Date()) }
    var weakCount: Int { progress.reviews.values.filter { !$0.isMastered && !$0.isComplete && $0.isWeak }.count }
    func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    func activity(now: Date = Date()) -> DailyActivity { progress.days?[dayKey(now)] ?? DailyActivity() }
    func scheduledCount(now: Date) -> Int {
        progress.reviews.values.filter { !$0.isMastered && !$0.isComplete && !isReady($0, now: now) }.count
    }
    func nextReviewDate(now: Date) -> Date? {
        progress.reviews.values.filter { !$0.isMastered && !$0.isComplete && !isReady($0, now: now) }.compactMap(\.nextDueAt).min()
    }
    func progress(for grammar: GrammarPoint) -> Double {
        guard !grammar.examples.isEmpty else { return 0 }
        return Double(grammar.examples.filter { progress.learnedSentenceIDs.contains($0.id) }.count) / Double(grammar.examples.count)
    }
    func progress(for chapter: Chapter) -> Double {
        let sentences = chapter.grammar.flatMap(\.examples)
        guard !sentences.isEmpty else { return 0 }
        return Double(sentences.filter { progress.learnedSentenceIDs.contains($0.id) }.count) / Double(sentences.count)
    }
    func progress(for grammarID: String) -> Double {
        curriculum.allGrammarPoints.first(where: { $0.id == grammarID }).map { progress(for: $0) } ?? 0
    }
    func isGrammarUnlocked(_ grammar: GrammarPoint) -> Bool { isGrammarUnlocked(grammar.id) }
    func isGrammarUnlocked(_ id: String) -> Bool { completedGrammarIDs.contains(id) }
    func hasLearned(_ id: String) -> Bool { progress.learnedSentenceIDs.contains(id) }
    func learningItem(for id: String) -> LearningItem? { itemsByID[id] }
    func reviewItem(for id: String) -> ReviewItem? { itemsByID[id].map { ReviewItem(sentence: $0.sentence, grammar: $0.grammar, chapter: $0.chapter) } }
    func dueDate(for id: String) -> Date? {
        guard let r = progress.reviews[id], !r.isMastered, !r.isComplete else { return nil }
        return r.nextDueAt
    }
    func isReady(_ entry: ReviewProgress, now: Date) -> Bool {
        guard !entry.isMastered, !entry.isComplete, let due = entry.nextDueAt else { return false }
        if due <= now { return true }
        // Separate failed cards by other answers, or wait for the minimum retry time.
        if entry.needsReinforcement, let sequence = entry.memory?.retryAfterSequence {
            return (progress.reviewSequence ?? 0) >= sequence
        }
        return false
    }
    func canReview(_ id: String, now: Date = Date()) -> Bool { progress.reviews[id].map { isReady($0, now: now) } ?? false }
    func status(for id: String, now: Date = Date()) -> SentenceStatus {
        guard let r = progress.reviews[id] else { return .locked }
        if r.isMastered { return .mastered }
        if r.isComplete { return .completed }
        return isReady(r, now: now) ? .due : .scheduled
    }
    func statusLabel(for id: String, now: Date = Date()) -> String { status(for: id, now: now).label }
    func dueSentences(now: Date = Date()) -> [ReviewItem] {
        sortedPending(now: now).filter { canReview($0.id, now: now) }
    }
    private func sortedPending(now: Date) -> [ReviewItem] {
        let unlocked = completedGrammarIDs
        return orderedItems.compactMap { item -> ReviewItem? in
            guard unlocked.contains(item.grammar.id), let r = progress.reviews[item.id],
                  !r.isMastered, !r.isComplete, (r.nextDueAt.map { $0 <= now } ?? false) || r.needsReinforcement else { return nil }
            return reviewItem(for: item.id)
        }.sorted { a, b in
            let ar = progress.reviews[a.id]!, br = progress.reviews[b.id]!
            if ar.needsReinforcement != br.needsReinforcement { return ar.needsReinforcement }
            let ad = ar.nextDueAt ?? now, bd = br.nextDueAt ?? now
            if ad != bd { return ad < bd }
            if ar.isWeak != br.isWeak { return ar.isWeak }
            return itemsByID[a.id]!.globalIndex < itemsByID[b.id]!.globalIndex
        }
    }
    private func selectedActivity(now: Date) -> DailyActivity {
        var day = activity(now: now)
        let candidates = sortedPending(now: now)
        let already = Set(day.newIDs + day.reviewIDs)
        let fresh = candidates.filter { !already.contains($0.id) && progress.reviews[$0.id]?.firstCorrectAt == nil }
        let old = candidates.filter { !already.contains($0.id) && progress.reviews[$0.id]?.firstCorrectAt != nil }
        day.newIDs += fresh.prefix(max(0, settings.newPerDay + day.extraNew - day.newIDs.count)).map(\.id)
        day.reviewIDs += old.prefix(max(0, settings.reviewsPerDay + day.extraReviews - day.reviewIDs.count)).map(\.id)
        return day
    }
    func dailyItems(now: Date = Date()) -> [ReviewItem] {
        let day = selectedActivity(now: now)
        let pending = Set(sortedPending(now: now).map(\.id))
        var new = day.newIDs.filter { pending.contains($0) }
        var old = day.reviewIDs.filter { pending.contains($0) }
        // Pending retries always survive quota reductions and remain part of the same day's task.
        let reinforcement = (new + old).filter { progress.reviews[$0]?.needsReinforcement == true }
        new.removeAll { reinforcement.contains($0) }; old.removeAll { reinforcement.contains($0) }
        var result = reinforcement
        if settings.order == .reviewsFirst { result += old + new }
        else {
            while !new.isEmpty || !old.isEmpty {
                result += old.prefix(2); old.removeFirst(min(2, old.count))
                if !new.isEmpty { result.append(new.removeFirst()) }
            }
        }
        return result.compactMap { reviewItem(for: $0) }
    }
    @discardableResult func beginDailySession(now: Date = Date()) -> [ReviewItem] {
        var updated = progress
        updated.days = updated.days ?? [:]
        updated.days?[dayKey(now)] = selectedActivity(now: now)
        progress = updated; saveProgress()
        return dailyItems(now: now)
    }
    func dailySummary(now: Date = Date()) -> DailySummary {
        let day = selectedActivity(now: now), items = dailyItems(now: now)
        let ready = items.filter { canReview($0.id, now: now) }
        let newSet = Set(day.newIDs)
        let oldDone = Set(day.reviewIDs).intersection(day.finishedIDs).count
        let freshDone = newSet.intersection(day.finishedIDs).count
        return DailySummary(learned: day.learnedIDs.count, newDone: freshDone, reviewDone: oldDone,
                            newTarget: settings.newPerDay + day.extraNew, reviewTarget: settings.reviewsPerDay + day.extraReviews,
                            newReady: ready.filter { newSet.contains($0.id) }.count,
                            reviewReady: ready.filter { !newSet.contains($0.id) }.count,
                            remaining: items.count, reinforcement: items.filter { progress.reviews[$0.id]?.needsReinforcement == true }.count,
                            overdue: dueSentences(now: now).filter { !Set(day.newIDs + day.reviewIDs).contains($0.id) }.count,
                            nextReadyAt: items.filter { !canReview($0.id, now: now) }.compactMap { dueDate(for: $0.id) }.min())
    }
    /// Earliest useful reminder dates; bounded by the OS pending-notification budget.
    func reminderDates(now: Date = Date(), limit: Int = 60) -> [Date] {
        guard settings.reminderEnabled, limit > 0 else { return [] }
        let plan = settings
        var dates: [Date] = []
        for offset in 0..<366 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let time = calendar.date(bySettingHour: plan.reminderHour, minute: plan.reminderMinute, second: 0, of: day), time > now else { continue }
            let hasDue = progress.reviews.values.contains { r in
                !r.isMastered && !r.isComplete && (r.firstCorrectAt != nil || plan.newPerDay > 0 || r.needsReinforcement)
                && (r.nextDueAt.map { $0 <= time } ?? false)
            }
            let hasNew = plan.newPerDay > 0 && nextLearning != nil
            guard hasDue || hasNew else { continue }
            if offset == 0 {
                let summary = dailySummary(now: now)
                if summary.remaining == 0 && summary.learned >= summary.newTarget && summary.overdue == 0 { continue }
            }
            dates.append(time)
            if dates.count >= min(60, limit) { break }
        }
        return dates
    }
    func updatePlan(_ plan: DailyPlanSettings, now: Date = Date()) {
        guard plan.isValid else { return }
        var updated = progress; updated.plan = plan; updated.updatedAt = now
        progress = updated; saveProgress()
    }
    func addExtraPractice(now: Date = Date()) {
        var updated = progress, day = activity(now: now)
        day.extraNew += 5; day.extraReviews += 10
        updated.days = updated.days ?? [:]; updated.days?[dayKey(now)] = day
        updated.updatedAt = now; progress = updated; saveProgress()
    }
    func learn(_ id: String, now: Date = Date()) {
        guard let item = itemsByID[id], !hasLearned(id) else { return }
        var updated = progress
        updated.learnedSentenceIDs.insert(id)
        if item.grammar.examples.allSatisfy({ updated.learnedSentenceIDs.contains($0.id) }) {
            for s in item.grammar.examples where updated.reviews[s.id] == nil {
                updated.reviews[s.id] = ReviewProgress(unlockedAt: now, nextDueAt: now, memory: MemoryState())
            }
        }
        var day = activity(now: now); day.learnedIDs.insert(id)
        updated.days = updated.days ?? [:]; updated.days?[dayKey(now)] = day
        updated.updatedAt = now; progress = updated; saveProgress()
    }
    @discardableResult func recordReview(sentenceID id: String, outcome: ReviewOutcome, now: Date = Date()) -> Bool {
        guard let item = itemsByID[id], isGrammarUnlocked(item.grammar.id), var entry = progress.reviews[id], isReady(entry, now: now) else { return false }
        var memory = entry.memory ?? MemoryState()
        var updated = progress
        let sequence = (updated.reviewSequence ?? 0) + 1
        let wasNew = entry.firstCorrectAt == nil
        func retry(_ seconds: TimeInterval, otherAnswers: Int) {
            entry.nextDueAt = now.addingTimeInterval(seconds)
            memory.retryAfterSequence = sequence + otherAnswers
        }
        switch outcome {
        case .incorrect:
            entry.incorrectCount += 1
            memory.step = max(0, memory.step - 2)
            memory.relearningRemaining = 2
            retry(60, otherAnswers: 2)
        case .hard:
            memory.hardCount += 1
            if wasNew || entry.needsReinforcement {
                memory.relearningRemaining = max(1, memory.relearningRemaining)
                retry(300, otherAnswers: 2)
            } else {
                memory.step = max(0, memory.step - 1)
                entry.nextDueAt = nextDay(now, days: Self.intervals[memory.step])
            }
        case .correct:
            if memory.relearningRemaining > 1 {
                memory.relearningRemaining -= 1
                retry(600, otherAnswers: 2)
            } else {
                let relearning = memory.relearningRemaining == 1
                memory.relearningRemaining = 0; memory.retryAfterSequence = nil
                if wasNew || relearning { memory.step = 0 }
                else { memory.step = min(Self.intervals.count - 1, memory.step + 1) }
                entry.firstCorrectAt = entry.firstCorrectAt ?? now
                entry.successfulReviews += 1
                entry.nextDueAt = nextDay(now, days: Self.intervals[memory.step])
            }
        case .mastered:
            entry.isMastered = true; entry.nextDueAt = nil
            memory.relearningRemaining = 0; memory.retryAfterSequence = nil
        }
        memory.lastOutcome = outcome; entry.memory = memory; entry.lastReviewedAt = now
        updated.reviews[id] = entry; updated.reviewSequence = sequence; updated.updatedAt = now
        var day = activity(now: now)
        // Free/manual review is counted once too; it cannot inflate a day's completed count.
        if !day.newIDs.contains(id) && !day.reviewIDs.contains(id) {
            if wasNew { day.newIDs.append(id) } else { day.reviewIDs.append(id) }
        }
        if !entry.needsReinforcement { day.finishedIDs.insert(id) }
        else { day.finishedIDs.remove(id) }
        updated.days = updated.days ?? [:]; updated.days?[dayKey(now)] = day
        progress = updated; saveProgress()
        return true
    }
    private func nextDay(_ now: Date, days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: now))!
    }
    func resetProgress() {
        protectsExistingFile = false; loadError = nil; progress = LearningProgress(); saveProgress()
    }
    func retrySave() { saveProgress() }
    private func loadProgress() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
            var loaded = try decoder.decode(LearningProgress.self, from: data)
            try validate(loaded)
            let old = loaded.schemaVersion == 1
            if old {
                for (id, var entry) in loaded.reviews {
                    var memory = MemoryState()
                    memory.retired = entry.successfulReviews >= 4
                    memory.step = [0, 2, 3, 4, 4][min(4, entry.successfulReviews)]
                    entry.memory = memory; loaded.reviews[id] = entry
                }
                loaded.schemaVersion = 2
                loaded.plan = DailyPlanSettings(); loaded.days = [:]; loaded.reviewSequence = 0
            }
            progress = loaded
            if old {
                do {
                    var backup = storageURL.appendingPathExtension("before-v2.json")
                    if FileManager.default.fileExists(atPath: backup.path) && (try? Data(contentsOf: backup)) != data {
                        backup = storageURL.appendingPathExtension("before-v2-\(UUID().uuidString).json")
                    }
                    if !FileManager.default.fileExists(atPath: backup.path) { try data.write(to: backup, options: .atomic) }
                    saveProgress()
                } catch {
                    protectsExistingFile = true
                    loadError = "原进度已载入，但暂时无法创建升级备份。"
                    saveError = "无法备份旧进度，本次练习不会覆盖原记录。请稍后重新打开。"
                }
            }
        } catch {
            protectsExistingFile = true
            loadError = "暂时无法读取进度，原记录已保留。"
            saveError = "进度尚未恢复，本次练习不会覆盖原记录。"
        }
    }
    private func validate(_ p: LearningProgress) throws {
        let known = Set(itemsByID.keys)
        guard [1, 2].contains(p.schemaVersion), p.learnedSentenceIDs.isSubset(of: known), (p.plan ?? DailyPlanSettings()).isValid,
              (p.reviewSequence ?? 0) >= 0 else { throw ProgressFileError.incompatible }
        for (id, r) in p.reviews {
            guard let item = itemsByID[id], item.grammar.examples.allSatisfy({ p.learnedSentenceIDs.contains($0.id) }),
                  r.successfulReviews >= 0, (p.schemaVersion == 2 || r.successfulReviews <= 4), r.incorrectCount >= 0,
                  r.successfulReviews == 0 || r.firstCorrectAt != nil,
                  r.isMastered || r.isComplete || r.nextDueAt != nil else { throw ProgressFileError.inconsistent }
            if let m = r.memory {
                guard (0..<Self.intervals.count).contains(m.step), (0...2).contains(m.relearningRemaining), m.hardCount >= 0,
                      m.retryAfterSequence.map({ $0 >= 0 }) ?? true else { throw ProgressFileError.inconsistent }
            } else if p.schemaVersion == 2 { throw ProgressFileError.inconsistent }
        }
        for grammar in curriculum.allGrammarPoints where grammar.examples.allSatisfy({ p.learnedSentenceIDs.contains($0.id) }) {
            guard grammar.examples.allSatisfy({ p.reviews[$0.id] != nil }) else { throw ProgressFileError.inconsistent }
        }
        for day in (p.days ?? [:]).values {
            let ids = Set(day.newIDs + day.reviewIDs)
            guard day.learnedIDs.isSubset(of: known), ids.isSubset(of: Set(p.reviews.keys)), day.finishedIDs.isSubset(of: ids),
                  Set(day.newIDs).count == day.newIDs.count, Set(day.reviewIDs).count == day.reviewIDs.count,
                  Set(day.newIDs).isDisjoint(with: Set(day.reviewIDs)), day.extraNew >= 0, day.extraReviews >= 0 else { throw ProgressFileError.inconsistent }
        }
    }
    private func saveProgress() {
        guard !protectsExistingFile else { return }
        do {
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(progress)
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: storageURL, options: .atomic)
            saveError = nil
        } catch { saveError = "本次进度暂未保存，请稍后重试。" }
    }
}
private enum ProgressFileError: Error { case incompatible, inconsistent }
