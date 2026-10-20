import XCTest

@MainActor
final class AppFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-reset"]
        app.launch()
    }

    func testLearnRevealRetryMasterAndPersist() throws {
        let progress = app.staticTexts["learningProgressCount"]
        XCTAssertTrue(progress.waitForExistence(timeout: 15))
        let total = progress.label.components(separatedBy: "/").last!.trimmingCharacters(in: .whitespaces)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        tabBar.buttons["背诵"].tap()
        XCTAssertTrue(app.staticTexts["背诵库还在等第一节"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["startReview"].exists)
        attachScreenshot("01-empty-review")

        tabBar.buttons["学习"].tap()
        app.buttons["startLearning"].tap()
        let english = app.staticTexts["englishSentence"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        let firstEnglish = english.label
        attachScreenshot("02-first-learning-card")
        // A real horizontal gesture verifies the primary card interaction.
        english.swipeLeft()
        waitForLabel(english, toDifferFrom: firstEnglish)
        let secondEnglish = english.label
        app.buttons["退出学习"].tap()
        XCTAssertTrue(app.staticTexts["1 / \(total)"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["startLearning"].waitForExistence(timeout: 10))
        app.buttons["startLearning"].tap()
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        XCTAssertEqual(english.label, secondEnglish, "Learning must resume after the last completed card.")
        // A mostly vertical gesture with leftward drift must scroll, not learn a card.
        let scrollStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.63))
        let scrollEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.33))
        scrollStart.press(forDuration: 0.1, thenDragTo: scrollEnd)
        XCTAssertEqual(english.label, secondEnglish, "Vertical scrolling must not advance learning.")
        for sentenceIndex in 1..<5 {
            let oldEnglish = english.label
            app.buttons["nextSentence"].tap()
            if sentenceIndex < 4 { waitForLabel(english, toDifferFrom: oldEnglish) }
        }
        XCTAssertTrue(app.buttons["finishSection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["这一节，学会了。"].exists)
        app.buttons["finishSection"].tap()
        XCTAssertTrue(app.buttons["startReview"].waitForExistence(timeout: 5))
        app.buttons["startReview"].tap()

        let chinese = app.staticTexts["reviewChinese"]
        XCTAssertTrue(chinese.waitForExistence(timeout: 5))
        let firstChinese = chinese.label
        XCTAssertFalse(app.staticTexts["reviewEnglish"].exists)
        XCTAssertFalse(app.buttons["reviewCorrect"].exists)
        XCTAssertFalse(app.buttons["reviewIncorrect"].exists)
        attachScreenshot("03-chinese-only-recall")
        revealAnswer()
        XCTAssertEqual(app.staticTexts["reviewEnglish"].label, firstEnglish)
        attachScreenshot("04-revealed-answer")

        app.buttons["reviewIncorrect"].tap()
        waitForLabel(chinese, toDifferFrom: firstChinese)
        XCTAssertTrue(app.staticTexts["剩余 5 句"].exists, "A wrong answer must stay in the active queue.")
        XCTAssertFalse(app.staticTexts["reviewEnglish"].exists)
        let secondChinese = chinese.label
        revealAnswer()
        app.buttons["reviewMastered"].tap()
        waitForLabel(chinese, toDifferFrom: secondChinese)

        // Sentences 3, 4 and 5 pass; the initial wrong sentence must then return.
        for _ in 0..<3 {
            let oldChinese = chinese.label
            revealAnswer()
            app.buttons["reviewCorrect"].tap()
            waitForLabel(chinese, toDifferFrom: oldChinese)
        }
        XCTAssertEqual(chinese.label, firstChinese, "The wrong sentence must return after the other cards.")
        XCTAssertTrue(app.staticTexts["剩余 1 句"].exists)
        revealAnswer()
        app.buttons["reviewCorrect"].tap()
        XCTAssertTrue(app.staticTexts["这一轮，完成了。"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["背对 4 句 · 斩掉 1 句"].exists)
        app.buttons["收好今天的进步"].tap()
        XCTAssertTrue(app.staticTexts["此刻，没有待背句子"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["startReview"].exists)
        attachScreenshot("05-completed-review")

        // Relaunch the isolated test store, without resetting it.
        app.terminate()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.firstMatch.buttons["背诵"].tap()
        XCTAssertTrue(app.staticTexts["此刻，没有待背句子"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["startReview"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "下次复习：")).count, 1)
        app.tabBars.firstMatch.buttons["学习"].tap()
        XCTAssertTrue(app.staticTexts["5 / \(total)"].waitForExistence(timeout: 5), "Learning progress must survive relaunch.")
        XCTAssertTrue(app.buttons["startLearning"].exists)
        attachScreenshot("06-persisted-progress")
    }

    func testLibrarySearchPreviewAndPDFSource() throws {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons["句库"].tap()
        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 3) { app.swipeDown() }
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("G001\n")
        XCTAssertTrue(app.staticTexts["找到 5 个例句"].waitForExistence(timeout: 5))
        let firstResult = app.staticTexts["libraryResultEnglish"].firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 5))
        let firstEnglish = firstResult.label
        XCTAssertTrue(app.staticTexts[firstEnglish].exists)
        attachScreenshot("07-library-search")
        app.staticTexts[firstEnglish].tap()
        let previewEnglish = app.staticTexts["englishSentence"]
        XCTAssertTrue(previewEnglish.waitForExistence(timeout: 5))
        XCTAssertEqual(previewEnglish.label, firstEnglish)
        XCTAssertTrue(app.staticTexts["预览不计入学习进度"].exists)
        app.buttons["下一句"].tap()
        waitForLabel(previewEnglish, toDifferFrom: firstEnglish)
        app.buttons["上一句"].tap()
        XCTAssertEqual(previewEnglish.label, firstEnglish)
        guard app.buttons["查看原页"].exists else { return }
        app.buttons["查看原页"].tap()
        XCTAssertFalse(app.staticTexts["没有找到原版教材"].exists)
        let pdf = app.otherElements["sourcePDF"]
        XCTAssertTrue(pdf.waitForExistence(timeout: 5))
        XCTAssertFalse((pdf.value as? String ?? "").hasPrefix("0 "), "The generated guide must have pages.")
        attachScreenshot("08-source-pdf")
        app.buttons["完成"].tap()
        XCTAssertTrue(previewEnglish.waitForExistence(timeout: 5))
        app.tabBars.firstMatch.buttons["学习"].tap()
        XCTAssertTrue(app.staticTexts["learningProgressCount"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["learningProgressCount"].label.hasPrefix("0 /"), "Browsing must not count as learning.")
    }

    private func revealAnswer() {
        let reveal = app.buttons["revealAnswer"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5))
        reveal.tap()
        XCTAssertTrue(app.staticTexts["reviewEnglish"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["reviewCorrect"].exists)
    }

    private func waitForLabel(_ element: XCUIElement, toDifferFrom oldLabel: String) {
        let changed = NSPredicate { _, _ in element.exists && element.label != oldLabel }
        expectation(for: changed, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
