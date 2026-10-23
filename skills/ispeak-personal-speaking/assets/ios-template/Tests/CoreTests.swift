import Foundation

struct TestFailure: Error, CustomStringConvertible { let description: String }
@main struct CoreTests {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ispeak-v2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 10))!
        let course = fixture()
        func make(_ name: String) -> LearningStore { LearningStore(curriculum: course, storageURL: root.appendingPathComponent(name), calendar: calendar) }
        func learnAll(_ store: LearningStore, _ count: Int = 20) { for n in 1...count { store.learn("s\(n)", now: now) } }
        let store = make("main.json")
        store.learn("missing", now: now)
        for n in 1...4 { store.learn("s\(n)", now: now) }
        try expect(store.dueSentences(now: now).isEmpty && store.learnedCount == 4, "partial grammar stays locked")
        store.learn("s5", now: now); store.learn("s5", now: now)
        try expect(store.dueSentences(now: now).count == 5 && store.activity(now: now).learnedIDs.count == 5, "five examples unlock together; duplicate study is harmless")
        try expect(store.nextLearning?.id == "s6", "study resumes in its original sequence")
        learnAll(store)
        let selected = store.beginDailySession(now: now)
        try expect(selected.count == 10 && Set(selected.map(\.id)).count == 10, "new-card daily budget is enforced")
        for item in selected { try expect(store.recordReview(sentenceID: item.id, outcome: .correct, now: now), "initial recall accepted") }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        try expect(store.dueDate(for: "s1") == tomorrow, "first clean recall returns the next calendar day")
        try expect(store.dailyItems(now: now).isEmpty && store.dailySummary(now: now).overdue == 10, "extra due cards remain visible outside today's budget")
        try expect(store.dailySummary(now: now).newDone == 10, "completion counts distinct sentences, not button presses")
        let restarted = make("main.json")
        try expect(restarted.progress == store.progress, "plan, daily counters, study and recall survive relaunch")
        try expect(!store.recordReview(sentenceID: "s1", outcome: .correct, now: now), "same scheduled answer cannot advance again early")
        var plan = store.settings; plan.newPerDay = 3; plan.reviewsPerDay = 3
        store.updatePlan(plan, now: tomorrow)
        let mixed = store.beginDailySession(now: tomorrow)
        try expect(mixed.count == 6 && mixed.prefix(3).map(\.id) == ["s1", "s2", "s11"], "mix two due reviews with one initial recall")
        plan.order = .reviewsFirst; store.updatePlan(plan, now: tomorrow)
        try expect(store.dailyItems(now: tomorrow).prefix(3).map(\.id) == ["s1", "s2", "s3"], "review-first preference changes order without changing admissions")
        for id in ["s1", "s2", "s3"] { store.recordReview(sentenceID: id, outcome: .correct, now: tomorrow) }
        let day4 = calendar.date(byAdding: .day, value: 3, to: tomorrow)!
        try expect(store.dueDate(for: "s1") == day4, "second clean recall uses a longer interval from the actual answer")
        store.addExtraPractice(now: tomorrow)
        try expect(store.beginDailySession(now: tomorrow).count > 3, "additional practice can explicitly expand the daily budget")
        try expect(store.nextLearning == nil, "daily plan never changes original learning completion")

        let retry = make("retry.json"); learnAll(retry, 10)
        retry.beginDailySession(now: now)
        retry.recordReview(sentenceID: "s1", outcome: .incorrect, now: now)
        try expect(!retry.canReview("s1", now: now) && retry.progress.reviews["s1"]?.needsReinforcement == true, "wrong card has a real short-term cooldown")
        try expect(!retry.recordReview(sentenceID: "s1", outcome: .correct, now: now), "revealing then immediately passing cannot graduate a wrong card")
        retry.recordReview(sentenceID: "s2", outcome: .correct, now: now)
        try expect(!retry.canReview("s1", now: now), "one intervening answer is insufficient")
        retry.recordReview(sentenceID: "s3", outcome: .correct, now: now)
        try expect(retry.canReview("s1", now: now), "two intervening cards permit the first retry")
        retry.recordReview(sentenceID: "s1", outcome: .correct, now: now)
        try expect(retry.progress.reviews["s1"]?.memory?.relearningRemaining == 1 && retry.progress.reviews["s1"]?.firstCorrectAt == nil, "one retry success does not erase the failure")
        for id in ["s4", "s5", "s6"] { retry.recordReview(sentenceID: id, outcome: .correct, now: now) }
        retry.recordReview(sentenceID: "s1", outcome: .correct, now: now)
        try expect(retry.dueDate(for: "s1") == tomorrow && retry.progress.reviews["s1"]?.successfulReviews == 1, "second separated success graduates to tomorrow")
        try expect(retry.progress.reviews["s1"]?.incorrectCount == 1, "failure history is retained")
        retry.recordReview(sentenceID: "s7", outcome: .hard, now: now)
        try expect(retry.progress.reviews["s7"]?.needsReinforcement == true, "hard first recall also needs another retrieval")
        let after = now.addingTimeInterval(301)
        try expect(retry.canReview("s7", now: after), "time fallback lets a lone hard card return")
        retry.recordReview(sentenceID: "s7", outcome: .correct, now: after)
        retry.recordReview(sentenceID: "s8", outcome: .mastered, now: now)
        try expect(retry.status(for: "s8", now: tomorrow) == .mastered, "cut permanently excludes a card")
        let finalState = retry.progress
        retry.recordReview(sentenceID: "s8", outcome: .incorrect, now: tomorrow)
        try expect(retry.progress == finalState, "cut cards reject future grading")
        retry.recordReview(sentenceID: "s9", outcome: .incorrect, now: now)
        let retryReload = make("retry.json")
        try expect(retryReload.progress == retry.progress && !retryReload.canReview("s9", now: now), "cooldowns and retry steps survive restart")
        try expect(retryReload.dailyItems(now: now).contains(where: { $0.id == "s9" }), "a waiting card is not falsely shown as completed")

        let growth = make("growth.json"); learnAll(growth, 5)
        growth.recordReview(sentenceID: "s1", outcome: .correct, now: now)
        var previous = tomorrow
        for interval in LearningStore.intervals.dropFirst() {
            growth.recordReview(sentenceID: "s1", outcome: .correct, now: previous)
            let next = calendar.date(byAdding: .day, value: interval, to: calendar.startOfDay(for: previous))!
            try expect(growth.dueDate(for: "s1") == next, "normal intervals expand without using the old absolute anchor")
            previous = next
        }
        try expect(growth.progress.reviews["s1"]?.isComplete == false, "new cards do not disappear automatically after day 30")
        try expect(growth.reminderDates(now: now).isEmpty, "reminders stay off unless explicitly enabled")
        let lastAnswer = calendar.date(byAdding: .day, value: -180, to: previous)!
        for n in 2...5 { growth.recordReview(sentenceID: "s\(n)", outcome: .mastered, now: lastAnswer) }
        var reminderPlan = growth.settings; reminderPlan.newPerDay = 0; reminderPlan.reminderEnabled = true
        growth.updatePlan(reminderPlan, now: lastAnswer)
        let reminders = growth.reminderDates(now: lastAnswer)
        try expect(reminders.count == 60 && calendar.isDate(reminders[0], inSameDayAs: previous), "long-interval reviews are reminded on their due date, even outside a short horizon")
        try expect(calendar.component(.hour, from: reminders[0]) == 20, "reminders respect the selected local hour")
        try expect(growth.reminderDates(now: lastAnswer, limit: 0).isEmpty, "zero reminder capacity is respected")
        growth.recordReview(sentenceID: "s1", outcome: .hard, now: previous)
        try expect(growth.dueDate(for: "s1") == calendar.date(byAdding: .day, value: 120, to: previous), "hard mature recall shortens the next interval")
        let lapseAt = growth.dueDate(for: "s1")!
        growth.recordReview(sentenceID: "s1", outcome: .incorrect, now: lapseAt)
        try expect(growth.progress.reviews["s1"]?.memory?.relearningRemaining == 2, "a mature lapse returns to relearning")

        try migration(root: root, course: course, calendar: calendar, now: now)
        try persistenceFailure(root: root, course: course, now: now)
        var dst = Calendar(identifier: .gregorian); dst.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let dstNow = dst.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        let dstStore = LearningStore(curriculum: course, storageURL: root.appendingPathComponent("dst.json"), calendar: dst)
        for n in 1...5 { dstStore.learn("s\(n)", now: dstNow) }
        dstStore.recordReview(sentenceID: "s1", outcome: .correct, now: dstNow)
        let nextDst = dstStore.dueDate(for: "s1")!
        try expect(dst.component(.day, from: nextDst) == 8 && dst.component(.hour, from: nextDst) == 0, "calendar boundary survives DST")
        if CommandLine.arguments.count > 1 {
            let actual = try Curriculum.load(from: URL(fileURLWithPath: CommandLine.arguments[1]))
            try expect(actual.sentenceCount > 0 && actual.sentenceCount == actual.allSentences.count, "the provided course validates without content loss")
        }
        print("PASS: unchanged section learning; daily quotas, mixing and rollover; two-step reinforcement; adaptive intervals and hard ratings; mastery; legacy migration/backup; relaunch; storage failure; DST; full course")
    }
    @MainActor private static func migration(root: URL, course: Curriculum, calendar: Calendar, now: Date) throws {
        let path = root.appendingPathComponent("legacy.json")
        let anchor = calendar.date(byAdding: .day, value: -7, to: now)!
        var reviews: [String: Any] = [:]
        for n in 1...5 {
            var r: [String: Any] = ["unlockedAt": anchor.timeIntervalSince1970 * 1000, "successfulReviews": n == 2 ? 4 : n == 1 ? 1 : 0, "incorrectCount": 0, "isMastered": n == 3]
            if n <= 2 { r["firstCorrectAt"] = anchor.timeIntervalSince1970 * 1000 }
            if n != 2 && n != 3 { r["nextDueAt"] = now.timeIntervalSince1970 * 1000 }
            reviews["s\(n)"] = r
        }
        let bytes = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "learnedSentenceIDs": (1...5).map { "s\($0)" }, "reviews": reviews])
        try bytes.write(to: path)
        let store = LearningStore(curriculum: course, storageURL: path, calendar: calendar)
        try expect(store.loadError == nil && store.progress.schemaVersion == 2 && store.learnedCount == 5, "v1 upgrades without resetting study")
        try expect(store.dueDate(for: "s1") == now && store.completedReviewCount == 1 && store.masteredCount == 1, "legacy due dates, completed cycles and cuts are preserved")
        try expect(try Data(contentsOf: path.appendingPathExtension("before-v2.json")) == bytes, "old progress is backed up byte for byte")
        let protectedFolder = root.appendingPathComponent("read-only-migration")
        try FileManager.default.createDirectory(at: protectedFolder, withIntermediateDirectories: true)
        let protectedPath = protectedFolder.appendingPathComponent("progress.json")
        try bytes.write(to: protectedPath)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: protectedFolder.path)
        let protectedStore = LearningStore(curriculum: course, storageURL: protectedPath, calendar: calendar)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: protectedFolder.path)
        try expect(protectedStore.learnedCount == 5 && protectedStore.saveError != nil, "backup failure still displays the valid old learning state")
        protectedStore.learn("s6", now: now)
        try expect(try Data(contentsOf: protectedPath) == bytes, "backup failure protects the original file from replacement")
        let recovered = LearningStore(curriculum: course, storageURL: protectedPath, calendar: calendar)
        try expect(recovered.loadError == nil && recovered.learnedCount == 5, "relaunch can retry a previously blocked migration")
        let again = LearningStore(curriculum: course, storageURL: path, calendar: calendar)
        try expect(again.progress == store.progress, "migration is idempotent")
        store.recordReview(sentenceID: "s1", outcome: .correct, now: now)
        try expect(store.dueDate(for: "s1") == calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: now)), "legacy active records adopt the new schedule after their next answer")
    }
    @MainActor private static func persistenceFailure(root: URL, course: Curriculum, now: Date) throws {
        let corrupt = root.appendingPathComponent("corrupt.json"), bytes = Data("keep this original".utf8)
        try bytes.write(to: corrupt)
        let bad = LearningStore(curriculum: course, storageURL: corrupt)
        bad.learn("s1", now: now); bad.retrySave()
        try expect(bad.loadError != nil && Data(contentsOf: corrupt) == bytes, "corrupt original is never overwritten by practice or retries")
        bad.resetProgress(); try expect(bad.loadError == nil && bad.learnedCount == 0, "only an explicit reset replaces protected data")
        let blocker = root.appendingPathComponent("not-a-folder")
        try Data("block".utf8).write(to: blocker)
        let store = LearningStore(curriculum: course, storageURL: blocker.appendingPathComponent("progress.json"))
        store.learn("s1", now: now); try expect(store.saveError != nil && store.learnedCount == 1, "write failure preserves the current in-memory action")
        try FileManager.default.removeItem(at: blocker); store.retrySave()
        try expect(store.saveError == nil, "retry recovers from a transient write error")
    }
    private static func fixture() -> Curriculum {
        Curriculum(chapters: (1...4).map { chapter in
            let grammar = GrammarPoint(id: "g\(chapter)", title: "Grammar", level: "B1", pattern: "Pattern", note: "Note", page: 1, examples: (1...5).map { index in
                let n = (chapter - 1) * 5 + index
                return Sentence(id: "s\(n)", en: "Sentence \(n)", zh: "句子 \(n)", kind: "example")
            })
            return Chapter(id: chapter, part: min(3, chapter), title: "Topic", subtitle: "话题", shortTitle: "话题", questions: [], practice: "", startPage: 1, grammar: [grammar])
        }, supplements: [])
    }
    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw TestFailure(description: message) }
    }
}
