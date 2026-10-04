import XCTest

/// Spec §4.2 and §6: the trying-to-conceive Today screen.
final class CycleTodayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// "Period started" → "Undo" → back to how it was.
    @MainActor
    func testStartingAPeriodCanBeUndone() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "late")
        let late = app.descendants(matching: .any)["cycleLateCard"]
        XCTAssertTrue(late.waitForExistence(timeout: 10))
        XCTAssertTrue(late.label.contains("Your period is 4 days late"), late.label)
        // While late the status is neutral, never "Low chance of conceiving".
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.label.contains("Your period is late"), status.label)
        // While late, the past fertile window is not shown.
        XCTAssertTrue(app.descendants(matching: .any)["cycleNextPeriodCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["cycleFertileCard"].exists)

        let periodButton = app.buttons["cyclePeriodButton"]
        XCTAssertEqual(periodButton.label, "Period started today")
        periodButton.tap()
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 2))
        waitForLabel(status, containing: "Day 1 of your cycle")
        XCTAssertFalse(late.exists)
        XCTAssertEqual(periodButton.label, "Undo period start")

        periodButton.tap()
        waitForLabel(status, containing: "Day 33 of your cycle")
        XCTAssertTrue(late.waitForExistence(timeout: 5))
        XCTAssertEqual(periodButton.label, "Period started today")
    }

    /// An ongoing period (started yesterday) is ended from the ring.
    @MainActor
    func testEndingTheOngoingPeriod() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "period")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Day 2 of your cycle"), status.label)
        let periodButton = app.buttons["cyclePeriodButton"]
        XCTAssertEqual(periodButton.label, "Period ended today")
        periodButton.tap()
        waitForLabel(periodButton, containing: "Period started today")

        let logToday = app.buttons["cycleLogTodayButton"]
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let periodInfo = app.descendants(matching: .any)["dayLogPeriodInfo"]
        XCTAssertTrue(periodInfo.waitForExistence(timeout: 5))
        XCTAssertEqual(periodInfo.label, "Period October 1 – October 2")
    }

    /// Spec §2.3: the avatar opens Profile, the calendar icon opens Calendar,
    /// and a day in the strip opens its log (VoiceOver reads it like the calendar).
    @MainActor
    func testHeaderAndStripNavigation() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let avatar = app.buttons["headerAvatar"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        avatar.tap()
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        XCTAssertTrue(profileTab.isSelected)

        app.openCycleTab(.today)
        app.buttons["headerCalendar"].tap()
        XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 5))

        app.openCycleTab(.today)
        let yesterday = app.buttons.matching(
            NSPredicate(format: "identifier == 'stripDay' AND label BEGINSWITH 'October 1,'")
        ).firstMatch
        XCTAssertTrue(yesterday.waitForExistence(timeout: 5))
        XCTAssertTrue(yesterday.label.contains("negative LH test logged"), yesterday.label)
        yesterday.tap()
        XCTAssertTrue(app.buttons["dayLogSave"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls.buttons["Negative"].isSelected)
    }

    @MainActor
    func testMaybePregnantCardOpensTheSwitchSheet() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let card = app.buttons["cycleMaybePregnantCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollUntilHittable(card)
        card.tap()
        XCTAssertTrue(app.buttons["imPregnantSave"].waitForExistence(timeout: 5))
    }
}
