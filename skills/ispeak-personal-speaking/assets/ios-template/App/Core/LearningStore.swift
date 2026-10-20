import Foundation
#if canImport(Combine)
import Combine
#else
// The scheduling engine can also be verified with the Swift CLI on Linux.
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
    /// Zero based position within this grammar point.
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

enum ReviewOutcome { case correct, incorrect, mastered }

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

struct ReviewProgress: Codable, Equatable {
    var unlockedAt: Date
    var firstCorrectAt: Date?
    /// 0: initial recall; 1: day 7; 2: day 14; 3: day 30; 4: finished.
    var successfulReviews: Int = 0
    var nextDueAt: Date?
    var lastReviewedAt: Date?
    var incorrectCount: Int = 0
    var isMastered: Bool = false
    var isComplete: Bool { successfulReviews >= 4 }
}

struct LearningProgress: Codable, Equatable {
    var schemaVersion: Int = 1
    var learnedSentenceIDs: Set<String> = []
    var reviews: [String: ReviewProgress] = [:]
    var updatedAt: Date?
}

@MainActor
final class LearningStore: ObservableObject {
    let curriculum: Curriculum
    let storageURL: URL
    @Published private(set) var progress: LearningProgress
    @Published private(set) var saveError: String?
    @Published private(set) var loadError: String?

    private let calendar: Calendar
    private let orderedItems: [LearningItem]
    private let itemsByID: [String: LearningItem]
    /// A failed or corrupt load must never be silently overwritten by subsequent activity.
    private var protectsExistingFile = false

    init(curriculum: Curriculum, storageURL: URL? = nil, calendar: Calendar = .current) {
        self.curriculum = curriculum
        self.storageURL = storageURL ?? Self.defaultStorageURL
        self.calendar = calendar
        var ordered: [LearningItem] = []
        for chapter in curriculum.chapters {
            for grammar in chapter.grammar {
                for (index, sentence) in grammar.examples.enumerated() {
                    ordered.append(LearningItem(sentence: sentence, grammar: grammar, chapter: chapter,
                                                index: index, globalIndex: ordered.count))
                }
            }
        }
        self.orderedItems = ordered
        // Curriculum.load validates unique IDs. Avoid a crash even with a hand-built fixture.
        self.itemsByID = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.progress = LearningProgress()
        loadProgress()
    }

    static var defaultStorageURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("iSpeak", isDirectory: true).appendingPathComponent("progress.json")
    }

    var totalCount: Int { orderedItems.count }
    var learnedCount: Int { orderedItems.filter { progress.learnedSentenceIDs.contains($0.id) }.count }
    var completedGrammarIDs: Set<String> {
        Set(curriculum.allGrammarPoints.filter { grammar in
            !grammar.examples.isEmpty && grammar.examples.allSatisfy { progress.learnedSentenceIDs.contains($0.id) }
        }.map(\.id))
    }
    var nextLearning: LearningItem? {
        orderedItems.first { !progress.learnedSentenceIDs.contains($0.id) }
    }
    var masteredCount: Int { progress.reviews.values.filter(\.isMastered).count }
    var completedReviewCount: Int { progress.reviews.values.filter { $0.isComplete && !$0.isMastered }.count }
    var scheduledCount: Int { scheduledCount(now: Date()) }
    var nextReviewDate: Date? { nextReviewDate(now: Date()) }

    func scheduledCount(now: Date) -> Int {
        progress.reviews.values.filter {
            !$0.isMastered && !$0.isComplete && ($0.nextDueAt.map { $0 > now } ?? false)
        }.count
    }

    func nextReviewDate(now: Date) -> Date? {
        progress.reviews.values.filter { !$0.isMastered && !$0.isComplete }
            .compactMap(\.nextDueAt).filter { $0 > now }.min()
    }

    func progress(for grammar: GrammarPoint) -> Double {
        guard !grammar.examples.isEmpty else { return 0 }
        return Double(grammar.examples.filter { progress.learnedSentenceIDs.contains($0.id) }.count)
            / Double(grammar.examples.count)
    }

    func progress(for chapter: Chapter) -> Double {
        let sentences = chapter.grammar.flatMap(\.examples)
        guard !sentences.isEmpty else { return 0 }
        return Double(sentences.filter { progress.learnedSentenceIDs.contains($0.id) }.count) / Double(sentences.count)
    }

    func progress(for grammarID: String) -> Double {
        guard let grammar = curriculum.allGrammarPoints.first(where: { $0.id == grammarID }) else { return 0 }
        return progress(for: grammar)
    }

    func isGrammarUnlocked(_ grammar: GrammarPoint) -> Bool { isGrammarUnlocked(grammar.id) }
    func isGrammarUnlocked(_ grammarID: String) -> Bool { completedGrammarIDs.contains(grammarID) }
    func hasLearned(_ sentenceID: String) -> Bool { progress.learnedSentenceIDs.contains(sentenceID) }
    func learningItem(for sentenceID: String) -> LearningItem? { itemsByID[sentenceID] }
    func dueDate(for sentenceID: String) -> Date? {
        guard let entry = progress.reviews[sentenceID], !entry.isMastered, !entry.isComplete else { return nil }
        return entry.nextDueAt
    }

    func status(for sentenceID: String, now: Date = Date()) -> SentenceStatus {
        guard let entry = progress.reviews[sentenceID] else { return .locked }
        if entry.isMastered { return .mastered }
        if entry.isComplete { return .completed }
        return (entry.nextDueAt ?? .distantFuture) <= now ? .due : .scheduled
    }

    func statusLabel(for sentenceID: String, now: Date = Date()) -> String {
        status(for: sentenceID, now: now).label
    }

    /// Stable curriculum ordering makes relaunches and queue rotation predictable.
    func dueSentences(now: Date = Date()) -> [ReviewItem] {
        let unlocked = completedGrammarIDs
        return orderedItems.compactMap { item in
            guard unlocked.contains(item.grammar.id),
                  let entry = progress.reviews[item.id], !entry.isMastered, !entry.isComplete,
                  let due = entry.nextDueAt, due <= now else { return nil }
            return ReviewItem(sentence: item.sentence, grammar: item.grammar, chapter: item.chapter)
        }
    }

    func learn(_ sentenceID: String, now: Date = Date()) {
        guard let item = itemsByID[sentenceID], !progress.learnedSentenceIDs.contains(sentenceID) else { return }
        var updated = progress
        updated.learnedSentenceIDs.insert(sentenceID)
        // Reviewing a section is available only after its final example has been learned.
        if item.grammar.examples.allSatisfy({ updated.learnedSentenceIDs.contains($0.id) }) {
            for sentence in item.grammar.examples where updated.reviews[sentence.id] == nil {
                updated.reviews[sentence.id] = ReviewProgress(unlockedAt: now, nextDueAt: now)
            }
        }
        updated.updatedAt = now
        progress = updated
        saveProgress()
    }

    func recordReview(sentenceID: String, outcome: ReviewOutcome, now: Date = Date()) {
        guard let item = itemsByID[sentenceID], isGrammarUnlocked(item.grammar.id),
              var entry = progress.reviews[sentenceID], !entry.isMastered, !entry.isComplete,
              let due = entry.nextDueAt, due <= now else { return }
        switch outcome {
        case .incorrect:
            // Keep the due date, anchor and checkpoint. The session rotates it to the back.
            entry.incorrectCount += 1
        case .mastered:
            entry.isMastered = true
            entry.nextDueAt = nil
        case .correct:
            if entry.firstCorrectAt == nil { entry.firstCorrectAt = now }
            entry.successfulReviews += 1
            if entry.isComplete {
                entry.nextDueAt = nil
            } else if let anchor = entry.firstCorrectAt {
                let days = [7, 14, 30][entry.successfulReviews - 1]
                // Absolute calendar-day checkpoints from the FIRST correct recall.
                entry.nextDueAt = calendar.date(byAdding: .day, value: days, to: anchor)
            }
        }
        entry.lastReviewedAt = now
        var updated = progress
        updated.reviews[sentenceID] = entry
        updated.updatedAt = now
        progress = updated
        saveProgress()
    }

    /// Explicit reset is the only action permitted to replace a corrupt progress file.
    func resetProgress() {
        protectsExistingFile = false
        loadError = nil
        progress = LearningProgress()
        saveProgress()
    }

    func retrySave() { saveProgress() }

    private func loadProgress() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let loaded = try decoder.decode(LearningProgress.self, from: Data(contentsOf: storageURL))
            try validate(loaded)
            progress = loaded
        } catch {
            protectsExistingFile = true
            loadError = "无法读取已保存的进度，原文件已保留。\(error.localizedDescription)"
            saveError = "进度文件读取失败；当前学习暂时不会覆盖原文件。"
        }
    }

    private func validate(_ loaded: LearningProgress) throws {
        guard loaded.schemaVersion == 1,
              loaded.learnedSentenceIDs.isSubset(of: Set(itemsByID.keys)) else {
            throw ProgressFileError.incompatible
        }
        for (id, entry) in loaded.reviews {
            guard let item = itemsByID[id],
                  item.grammar.examples.allSatisfy({ loaded.learnedSentenceIDs.contains($0.id) }),
                  (0...4).contains(entry.successfulReviews), entry.incorrectCount >= 0,
                  entry.successfulReviews == 0 || entry.firstCorrectAt != nil,
                  entry.isMastered || entry.isComplete || entry.nextDueAt != nil else {
                throw ProgressFileError.inconsistent
            }
        }
        for grammar in curriculum.allGrammarPoints where grammar.examples.allSatisfy({ loaded.learnedSentenceIDs.contains($0.id) }) {
            guard grammar.examples.allSatisfy({ loaded.reviews[$0.id] != nil }) else {
                throw ProgressFileError.inconsistent
            }
        }
    }

    private func saveProgress() {
        guard !protectsExistingFile else { return }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(progress)
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: storageURL, options: .atomic)
            saveError = nil
        } catch {
            saveError = "本次进度暂未保存：\(error.localizedDescription)"
        }
    }
}

private enum ProgressFileError: LocalizedError {
    case incompatible, inconsistent
    var errorDescription: String? {
        switch self {
        case .incompatible: return "进度版本或课程内容不匹配。"
        case .inconsistent: return "进度文件中的复习记录不完整。"
        }
    }
}
