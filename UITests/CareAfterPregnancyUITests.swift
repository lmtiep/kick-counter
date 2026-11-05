import XCTest

/// 1.1 item 4 (spec §4.4–§4.6): the cycle Today after a pregnancy ended — the
/// paused predictions, the first-period question and the gentle check-ins.
/// `-seedPregnancyEnded <branch>:<days>` ends it that many days before the pinned today.
final class CareAfterPregnancyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ seed: String, extra: [String] = []) -> XCUIApplication {
        XCUIApplication.launchPinned(language: "en", extraArguments: ["-seedPregnancyEnded", seed] + extra)
    }

    @MainActor
    func testPausedCardShowsAfterLoss() {
        let app = launch("loss:30")
        let text = app.staticTexts["cyclePausedText"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertEqual(text.label, "Your period may take a while to come back. When it does, just log it.")
        XCTAssertFalse(app.descendants(matching: .any)["cycleStatusCard"].exists, "no prediction while paused")
        XCTAssertFalse(app.buttons["cycleMaybePregnantCard"].exists)
        XCTAssertFalse(app.tabBars.buttons["Kicks"].exists)
    }

    @MainActor
    func testPausedLineAfterBirth() {
        let app = launch("birth:30")
        let text = app.staticTexts["cyclePausedText"]
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertTrue(text.label.hasPrefix("After birth, your period may take weeks or months"), text.label)
    }

    @MainActor
    func testFirstPeriodYesResumesForecast() {
        let app = launch("loss:30")
        let start = app.buttons["cyclePausedStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let alert = app.alerts["Is this your first period since the pregnancy?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Yes"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["cyclePausedCard"].exists)
    }

    @MainActor
    func testFirstPeriodNoKeepsPause() {
        let app = launch("birth:30")
        let start = app.buttons["cyclePausedStart"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let alert = app.alerts["Is this your first period since giving birth?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Not this one"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["cyclePausedText"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["cycleStatusCard"].exists)
        // Not asked again about the same period.
        app.openCycleTab(.calendar)
        app.openCycleTab(.today)
        XCTAssertTrue(app.staticTexts["cyclePausedText"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2))
    }

    @MainActor
    func testCheckInDueAt21Days() {
        let app = launch("loss:21")
        let card = app.descendants(matching: .any)["careCheckInCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["How are you today?"].exists)
        app.buttons["careFeeling-okay"].tap()
        let reply = app.staticTexts["careReply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        XCTAssertEqual(reply.label, "One day at a time.")
        XCTAssertTrue(app.staticTexts["careTip"].exists)
        XCTAssertFalse(app.staticTexts["careShareLine"].exists)
        app.buttons["careClose"].tap()
        // Answered: not again this week.
        XCTAssertFalse(card.waitForExistence(timeout: 2))
    }

    @MainActor
    func testNotDueAt20Days() {
        let app = launch("loss:20")
        XCTAssertTrue(app.staticTexts["cyclePausedText"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["careCheckInCard"].exists)
    }

    @MainActor
    func testImOkayStopsCheckIns() {
        let app = launch("loss:21")
        let card = app.descendants(matching: .any)["careCheckInCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.buttons["careStop"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))

        app.openCycleTab(.profile)
        let toggle = app.switches["careEnabledToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        app.scrollUntilHittable(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.switches["careNotifyToggle"].isEnabled)
    }

    @MainActor
    func testSkipHidesTheCardForAWeek() {
        let app = launch("birth:21")
        let card = app.descendants(matching: .any)["careCheckInCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.buttons["careSkip"].tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
    }

    @MainActor
    func testTwoLowShowsShareLine() {
        let app = launch("loss:28", extra: ["-seedCareLowStreak", "1"])
        let card = app.descendants(matching: .any)["careCheckInCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.buttons["careFeeling-sad"].tap()
        let reply = app.staticTexts["careReply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        XCTAssertEqual(reply.label, "I'm here with you. Every feeling is allowed.")
        let share = app.staticTexts["careShareLine"]
        XCTAssertTrue(share.exists)
        XCTAssertEqual(share.label, "If the sadness lingers, share it with someone close or a friend you trust.")
    }

    @MainActor
    func testOneLowAloneHasNoShareLine() {
        let app = launch("birth:21")
        XCTAssertTrue(app.descendants(matching: .any)["careCheckInCard"].waitForExistence(timeout: 10))
        app.buttons["careFeeling-heavy"].tap()
        let reply = app.staticTexts["careReply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        XCTAssertEqual(reply.label, "These days can hold a lot of feelings. I'm here with you.")
        XCTAssertFalse(app.staticTexts["careShareLine"].exists)
    }
}
