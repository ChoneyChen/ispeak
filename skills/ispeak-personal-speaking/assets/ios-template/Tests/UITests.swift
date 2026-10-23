import XCTest

@MainActor final class AppFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["-ui-testing", "-ui-reset"]; app.launch()
    }
    func testStudyStillUnlocksFiveAndWrongCardNeedsSpacedConfirmation() throws {
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 15))
        tabs.buttons["背诵"].tap()
        XCTAssertTrue(app.staticTexts["背诵库还在等第一节"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["startReview"].exists)
        shot("01-daily-plan-empty")
        tabs.buttons["学习"].tap(); app.buttons["startLearning"].tap()
        let english = app.staticTexts["englishSentence"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        let first = english.label
        XCTAssertTrue(app.buttons["nextSentence"].isHittable, "Next stays visible without scrolling.")
        shot("02-fitted-study-card")
        english.swipeLeft(); changed(english, from: first)
        let second = english.label
        app.buttons["退出学习"].tap()
        app.terminate(); app.launchArguments = ["-ui-testing"]; app.launch()
        XCTAssertTrue(app.buttons["startLearning"].waitForExistence(timeout: 10)); app.buttons["startLearning"].tap()
        XCTAssertTrue(english.waitForExistence(timeout: 5)); XCTAssertEqual(english.label, second)
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.63))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.43, dy: 0.33))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(english.label, second, "A vertical gesture still never learns a sentence.")
        for index in 1..<5 {
            let old = english.label; app.buttons["nextSentence"].tap()
            if index < 4 { changed(english, from: old) }
        }
        XCTAssertTrue(app.buttons["finishSection"].waitForExistence(timeout: 5))
        app.buttons["finishSection"].tap()
        XCTAssertTrue(app.buttons["startReview"].waitForExistence(timeout: 5))
        shot("03-ready-daily-plan")
        app.buttons["startReview"].tap()
        let chinese = app.staticTexts["reviewChinese"]
        XCTAssertTrue(chinese.waitForExistence(timeout: 5))
        let firstChinese = chinese.label
        XCTAssertFalse(app.staticTexts["reviewEnglish"].exists)
        XCTAssertFalse(app.buttons["reviewCorrect"].exists)
        XCTAssertFalse(app.buttons["朗读答案"].exists)
        XCTAssertFalse(app.buttons["reviewGrammar"].exists)
        shot("04-chinese-only")
        reveal(); XCTAssertEqual(app.staticTexts["reviewEnglish"].label, first)
        XCTAssertTrue(app.buttons["reviewHard"].isHittable)
        XCTAssertTrue(app.buttons["reviewCorrect"].isHittable)
        shot("05-reveal-and-three-ratings")
        app.buttons["reviewIncorrect"].tap(); changed(chinese, from: firstChinese)
        let secondChinese = chinese.label
        reveal(); app.buttons["reviewMastered"].tap(); changed(chinese, from: secondChinese)
        let thirdChinese = chinese.label
        reveal(); app.buttons["reviewCorrect"].tap(); changed(chinese, from: thirdChinese)
        XCTAssertEqual(chinese.label, firstChinese)
        XCTAssertEqual(app.staticTexts["reviewKind"].label, "加强")
        reveal(); app.buttons["reviewCorrect"].tap(); changed(chinese, from: firstChinese)
        XCTAssertFalse(app.staticTexts["这一轮，完成了。"].exists, "A single retry must not graduate the failed card.")
        for _ in 0..<2 {
            let old = chinese.label; reveal(); app.buttons["reviewCorrect"].tap(); changed(chinese, from: old)
        }
        XCTAssertEqual(chinese.label, firstChinese, "A second separated retrieval is required.")
        reveal(); app.buttons["reviewCorrect"].tap()
        XCTAssertTrue(app.staticTexts["这一轮，完成了。"].waitForExistence(timeout: 5))
        shot("06-two-spaced-retries-completed")
        app.buttons["退出背诵"].tap()
        app.terminate(); app.launchArguments = ["-ui-testing"]; app.launch()
        XCTAssertTrue(tabs.waitForExistence(timeout: 10)); tabs.buttons["背诵"].tap()
        XCTAssertFalse(app.buttons["startReview"].exists)
        tabs.buttons["学习"].tap(); app.buttons["startLearning"].tap()
        XCTAssertTrue(english.waitForExistence(timeout: 5)); XCTAssertNotEqual(english.label, first)
    }
    func testDailyPlanSettingPersists() throws {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons["背诵"].tap(); app.buttons["dailyPlan"].tap()
        XCTAssertTrue(app.navigationBars["每日计划"].waitForExistence(timeout: 5))
        app.buttons["newDailyGoal"].tap()
        let five = app.buttons["5 句"]
        XCTAssertTrue(five.waitForExistence(timeout: 5)); five.tap()
        app.buttons["reviewOrder"].tap(); app.buttons["先复习"].tap()
        shot("07-personal-daily-plan")
        app.buttons["saveDailyPlan"].tap()
        app.terminate(); app.launchArguments = ["-ui-testing"]; app.launch()
        XCTAssertTrue(app.staticTexts["今天已新学 0 / 5 句 · 目标之外也能继续学"].waitForExistence(timeout: 10))
    }
    func testDueAndNewCardsAreMixedAndLayoutIsFixed() throws {
        app.terminate(); app.launchArguments = ["-ui-testing", "-ui-reset", "-ui-seed-review"]; app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons["背诵"].tap()
        XCTAssertTrue(app.buttons["startReview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startReview"].isHittable)
        shot("08-mixed-daily-home")
        app.buttons["startReview"].tap()
        let chinese = app.staticTexts["reviewChinese"]
        XCTAssertTrue(chinese.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["reviewKind"].label, "复习")
        for _ in 0..<2 {
            let old = chinese.label; reveal(); app.buttons["reviewCorrect"].tap(); changed(chinese, from: old)
        }
        XCTAssertEqual(app.staticTexts["reviewKind"].label, "初背", "After two reviews, introduce a learned new sentence.")
        shot("09-mixed-new-recall")
        reveal(); app.buttons["reviewHard"].tap()
        XCTAssertTrue(chinese.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["reviewEnglish"].exists)
    }
    func testAccessibilityKeepsAnswerControlsReachable() throws {
        app.terminate()
        app.launchArguments = ["-ui-testing", "-ui-reset", "-ui-seed-review", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons["背诵"].tap()
        let start = app.buttons["startReview"]
        if !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.isHittable); start.tap()
        XCTAssertTrue(app.buttons["revealAnswer"].waitForExistence(timeout: 5))
        app.buttons["revealAnswer"].tap()
        XCTAssertTrue(app.buttons["reviewCorrect"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["reviewCorrect"].isHittable)
        XCTAssertTrue(app.buttons["reviewIncorrect"].isHittable)
        shot("11-large-text-fixed-controls")
    }
    func testLibraryPreviewDoesNotChangeStudyProgress() throws {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.firstMatch.buttons["句库"].tap()
        let search = app.searchFields.firstMatch
        if !search.waitForExistence(timeout: 3) { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("G001\n")
        XCTAssertTrue(app.staticTexts["找到 5 个例句"].waitForExistence(timeout: 5))
        let cells = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "G001"))
        XCTAssertGreaterThan(cells.count, 0); cells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["englishSentence"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["预览不计入学习进度"].exists)
        let before = app.staticTexts["englishSentence"].label
        app.buttons["下一句"].tap(); changed(app.staticTexts["englishSentence"], from: before)
        app.buttons["上一句"].tap(); XCTAssertEqual(app.staticTexts["englishSentence"].label, before)
        if app.buttons["查看原页"].exists {
            app.buttons["查看原页"].tap()
            XCTAssertTrue(app.otherElements["sourcePDF"].waitForExistence(timeout: 5))
            app.buttons["完成"].tap()
        }
        shot("10-library-preview")
    }
    private func reveal() {
        let button = app.buttons["revealAnswer"]
        XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
        XCTAssertTrue(app.staticTexts["reviewEnglish"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["reviewCorrect"].exists)
    }
    private func changed(_ element: XCUIElement, from value: String) {
        expectation(for: NSPredicate { _, _ in element.exists && element.label != value }, evaluatedWith: nil)
        waitForExpectations(timeout: 6)
    }
    private func shot(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
