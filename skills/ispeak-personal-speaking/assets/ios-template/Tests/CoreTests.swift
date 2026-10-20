import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct CoreTests {
    @MainActor
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("iSpeak-core-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let curriculum = fixture()
        try curriculum.validate()
        let url = root.appendingPathComponent("normal/progress.json")
        let store = LearningStore(curriculum: curriculum, storageURL: url, calendar: calendar)

        try expect(store.totalCount == 10 && store.learnedCount == 0, "fresh counters")
        try expect(store.dueSentences(now: now).isEmpty, "locked material must never enter recall")
        try expect(store.nextLearning?.id == "s1", "fresh learning begins at first example")
        store.recordReview(sentenceID: "s1", outcome: .correct, now: now)
        try expect(store.progress.reviews.isEmpty, "locked reviews cannot be submitted")
        store.learn("unknown", now: now)
        try expect(store.learnedCount == 0, "unknown sentence cannot be learned")
        for id in 1...4 { store.learn("s\(id)", now: now) }
        try expect(store.dueSentences(now: now).isEmpty, "first four examples cannot unlock section")
        try expect(store.progress(for: "g1") == 0.8, "partial grammar progress")
        try expect(store.nextLearning?.index == 4, "resume at fifth example")
        store.learn("s5", now: now)
        try expect(store.isGrammarUnlocked("g1") && !store.isGrammarUnlocked("g2"), "unlock completed grammar only")
        try expect(store.dueSentences(now: now).map(\.id) == ["s1", "s2", "s3", "s4", "s5"], "whole grammar unlocks together in source order")
        try expect(store.nextLearning?.id == "s6" && store.nextLearning?.index == 0, "next grammar resumes with index zero")
        try expect(store.progress(for: curriculum.chapters[0]) == 1, "chapter progress")
        try expect(store.status(for: "s6", now: now) == .locked, "next grammar stays locked")
        let afterLearning = store.progress
        store.learn("s5", now: now.addingTimeInterval(100))
        store.recordReview(sentenceID: "s6", outcome: .mastered, now: now)
        try expect(store.progress == afterLearning, "duplicate learn and locked mastery are no-ops")

        store.recordReview(sentenceID: "s1", outcome: .incorrect, now: now)
        try expect(store.status(for: "s1", now: now) == .due, "wrong answer stays due")
        try expect(store.progress.reviews["s1"]?.successfulReviews == 0 && store.progress.reviews["s1"]?.firstCorrectAt == nil, "wrong initial answer never starts schedule")
        store.recordReview(sentenceID: "s2", outcome: .mastered, now: now)
        try expect(store.masteredCount == 1 && store.status(for: "s2", now: now) == .mastered, "mastery count and status")
        store.recordReview(sentenceID: "s1", outcome: .correct, now: now)
        let day7 = calendar.date(byAdding: .day, value: 7, to: now)!
        let day14 = calendar.date(byAdding: .day, value: 14, to: now)!
        let day30 = calendar.date(byAdding: .day, value: 30, to: now)!
        try expect(store.dueDate(for: "s1") == day7, "initial correct schedules absolute day 7")
        try expect(store.scheduledCount(now: now) == 1 && store.nextReviewDate(now: now) == day7, "scheduled counters")
        try expect(!store.dueSentences(now: day7.addingTimeInterval(-1)).contains(where: { $0.id == "s1" }), "not due one second early")
        let beforeEarlyAnswer = store.progress
        store.recordReview(sentenceID: "s1", outcome: .correct, now: day7.addingTimeInterval(-1))
        try expect(store.progress == beforeEarlyAnswer, "cannot answer before eligible date")
        try expect(store.dueSentences(now: day7).contains(where: { $0.id == "s1" }), "due at exact checkpoint")
        store.recordReview(sentenceID: "s1", outcome: .incorrect, now: day7)
        try expect(store.dueDate(for: "s1") == day7 && store.progress.reviews["s1"]?.firstCorrectAt == now, "wrong checkpoint preserves original anchor and due date")
        try expect(store.progress.reviews["s1"]?.successfulReviews == 1 && store.progress.reviews["s1"]?.incorrectCount == 2, "wrong checkpoint preserves stage")
        let lateDay10 = calendar.date(byAdding: .day, value: 10, to: now)!
        store.recordReview(sentenceID: "s1", outcome: .correct, now: lateDay10)
        try expect(store.dueDate(for: "s1") == day14, "late day 7 success schedules day 14 from initial anchor, not day 24")
        store.recordReview(sentenceID: "s1", outcome: .correct, now: day14)
        try expect(store.dueDate(for: "s1") == day30, "day 14 success schedules absolute day 30")

        let restarted = LearningStore(curriculum: curriculum, storageURL: url, calendar: calendar)
        try expect(restarted.loadError == nil && restarted.saveError == nil, "valid file reloads")
        try expect(restarted.progress == store.progress, "all learning and review state survives restart")
        try expect(restarted.nextLearning?.id == "s6", "resume global learning after restart")
        try expect(restarted.masteredCount == 1 && restarted.dueDate(for: "s1") == day30, "mastery and schedule survive restart")
        restarted.recordReview(sentenceID: "s1", outcome: .correct, now: day30)
        try expect(restarted.completedReviewCount == 1 && restarted.status(for: "s1", now: day30) == .completed, "final checkpoint completes review cycle")
        try expect(restarted.dueDate(for: "s1") == nil, "completed review has no next due date")
        let terminalProgress = restarted.progress
        restarted.recordReview(sentenceID: "s1", outcome: .incorrect, now: day30.addingTimeInterval(100))
        restarted.recordReview(sentenceID: "s2", outcome: .correct, now: day30.addingTimeInterval(100))
        try expect(restarted.progress == terminalProgress, "completed and mastered records reject future submissions")
        let farFuture = calendar.date(byAdding: .day, value: 1_000, to: now)!
        try expect(!restarted.dueSentences(now: farFuture).contains(where: { ["s1", "s2"].contains($0.id) }), "completed and permanently mastered stay excluded")
        for id in 6...10 { restarted.learn("s\(id)", now: now) }
        try expect(restarted.nextLearning == nil && restarted.learnedCount == 10 && restarted.completedGrammarIDs.count == 2, "all learning completes and every section unlocks")
        try expect(restarted.dueSentences(now: now).count == 8, "second five examples unlock exactly once")

        try corruptFileProtection(root: root, curriculum: curriculum, now: now)
        try failedSaveRecovery(root: root, curriculum: curriculum, now: now)
        try daylightSavingCalendar(root: root, curriculum: curriculum)
        try curriculumValidation(root: root)
        if CommandLine.arguments.count > 1 {
            let actual = try Curriculum.load(from: URL(fileURLWithPath: CommandLine.arguments[1]))
            try expect(actual.sentenceCount > 0 && actual.allGrammarPoints.allSatisfy { !$0.examples.isEmpty }, "bundled curriculum contains nonempty sections")
            try expect(actual.allGrammarPoints.allSatisfy { !$0.examples.isEmpty }, "each source grammar point contains five examples")
            print("PASS: bundled curriculum — \(actual.chapters.count) chapters, \(actual.grammarCount) grammar points, \(actual.sentenceCount) bilingual examples")
        }
        print("PASS: learning unlocks, restart/resume, eligibility, wrong-answer retention, 7/14/30 scheduling, mastery, terminal completion, DST, atomic persistence and corrupt-file protection")
    }

    @MainActor
    private static func corruptFileProtection(root: URL, curriculum: Curriculum, now: Date) throws {
        let url = root.appendingPathComponent("corrupt.json")
        let original = Data("not valid JSON — preserve me".utf8)
        try original.write(to: url)
        let store = LearningStore(curriculum: curriculum, storageURL: url)
        try expect(store.loadError != nil && store.saveError != nil, "corrupt load presents an error")
        store.learn("s1", now: now)
        store.retrySave()
        try expect(try Data(contentsOf: url) == original, "learning and retries never overwrite corrupt input")
        store.resetProgress()
        try expect(store.loadError == nil && store.saveError == nil && store.learnedCount == 0, "explicit reset clears protected state")
        let restarted = LearningStore(curriculum: curriculum, storageURL: url)
        try expect(restarted.loadError == nil && restarted.learnedCount == 0, "reset writes valid empty progress")
    }

    @MainActor
    private static func failedSaveRecovery(root: URL, curriculum: Curriculum, now: Date) throws {
        let blocker = root.appendingPathComponent("file-instead-of-directory")
        try Data("block directory creation".utf8).write(to: blocker)
        let url = blocker.appendingPathComponent("progress.json")
        let store = LearningStore(curriculum: curriculum, storageURL: url)
        store.learn("s1", now: now)
        try expect(store.saveError != nil && store.learnedCount == 1, "failed save keeps in-memory learning and exposes error")
        try FileManager.default.removeItem(at: blocker)
        store.retrySave()
        try expect(store.saveError == nil, "save retry clears recovered IO error")
        let restarted = LearningStore(curriculum: curriculum, storageURL: url)
        try expect(restarted.learnedCount == 1 && restarted.nextLearning?.id == "s2", "save recovery persists prior in-memory change")
    }

    @MainActor
    private static func daylightSavingCalendar(root: URL, curriculum: Curriculum) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!
        let store = LearningStore(curriculum: curriculum, storageURL: root.appendingPathComponent("dst.json"), calendar: calendar)
        for id in 1...5 { store.learn("s\(id)", now: anchor) }
        store.recordReview(sentenceID: "s1", outcome: .correct, now: anchor)
        let due = store.dueDate(for: "s1")!
        let components = calendar.dateComponents([.month, .day, .hour], from: due)
        try expect(components.month == 3 && components.day == 8 && components.hour == 12, "calendar-day schedule preserves local hour across DST")
        try expect(due.timeIntervalSince(anchor) == 7 * 24 * 3600 - 3600, "DST schedule uses calendar days, not fixed 24-hour durations")
    }

    private static func curriculumValidation(root: URL) throws {
        let curriculum = fixture()
        let url = root.appendingPathComponent("curriculum.json")
        try JSONEncoder().encode(curriculum).write(to: url)
        try expect(try Curriculum.load(from: url) == curriculum, "structured curriculum decodes without content loss")
        do {
            try Curriculum(chapters: [], supplements: []).validate()
            throw TestFailure(description: "empty curriculum should fail validation")
        } catch is CurriculumError { }
        let duplicate = Curriculum(chapters: [curriculum.chapters[0], curriculum.chapters[0]], supplements: [])
        do {
            try duplicate.validate()
            throw TestFailure(description: "duplicate chapter IDs should fail validation")
        } catch is CurriculumError { }
    }

    private static func fixture() -> Curriculum {
        let chapters = (1...2).map { chapter in
            let grammar = GrammarPoint(id: "g\(chapter)", title: "Grammar \(chapter)", level: "7.5–8.0", pattern: "Pattern", note: "Note", page: chapter,
                                       examples: (1...5).map { index in
                let id = (chapter - 1) * 5 + index
                return Sentence(id: "s\(id)", en: "Example \(id)", zh: "例句 \(id)", kind: "example")
            })
            return Chapter(id: chapter, part: chapter, title: "Chapter \(chapter)", subtitle: "Subtitle", shortTitle: "Topic", questions: [], practice: "", startPage: chapter, grammar: [grammar])
        }
        return Curriculum(chapters: chapters, supplements: [])
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(description: message) }
    }
}
