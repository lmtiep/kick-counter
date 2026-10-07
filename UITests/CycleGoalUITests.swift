import XCTest

/// Phase 9 spec §4.2 and §5: Today, the calendar and the day log by goal.
/// "fertile" is cycle day 13, inside the fertile window, with signals logged.
final class CycleGoalUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Opens today's log from Today.
    @MainActor
    private func openTodaysLog(_ app: XCUIApplication) {
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        app.scrollUntilHittable(logToday)
        logToday.tap()
        XCTAssertTrue(app.buttons["dayLogSave"].waitForExistence(timeout: 5))
    }

    /// A cycle-mode user from before phase 9 (no goal stored) is not shown
    /// onboarding again and keeps the trying-to-conceive screens.
    @MainActor
    func testLegacyCycleUserKeepsTryingToConceive() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboardingNext"].exists)
        XCTAssertTrue(status.label.contains("High chance of conceiving"), status.label)
        let fertile = app.descendants(matching: .any)["cycleFertileCard"]
        app.scrollUntilHittable(fertile)
        XCTAssertTrue(fertile.label.contains("Fertile window"), fertile.label)
        XCTAssertFalse(app.staticTexts["cycleNotContraceptionNote"].exists)
        app.scrollDownUntilHittable(app.buttons["cycleLogTodayButton"])
        openTodaysLog(app)
        XCTAssertTrue(app.segmentedControls["dayLogLHPicker"].exists)
    }

    /// Tracking: the window is "High chance of pregnancy" with the
    /// "not contraception" note, and the day log has no LH or BBT rows.
    @MainActor
    func testTrackingLabelsTheWindowAndHidesTheTests() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile", cycleGoal: "tracking")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("High chance of pregnancy"), status.label)
        let fertile = app.descendants(matching: .any)["cycleFertileCard"]
        app.scrollUntilHittable(fertile)
        XCTAssertTrue(fertile.label.contains("High chance of pregnancy"), fertile.label)
        let note = app.staticTexts["cycleNotContraceptionNote"]
        app.scrollUntilHittable(note)
        XCTAssertTrue(note.exists)
        XCTAssertTrue(note.label.contains("not a method of contraception"), note.label)

        app.scrollDownUntilHittable(app.buttons["cycleLogTodayButton"])
        openTodaysLog(app)
        XCTAssertFalse(app.segmentedControls["dayLogLHPicker"].exists)
        XCTAssertFalse(app.textFields["dayLogBBTField"].exists)
        let mucus = app.descendants(matching: .any)["dayLogMucusPicker"]
        app.scrollUntilHittable(mucus)
        XCTAssertTrue(mucus.exists)
    }

    /// Tracking on the pill: no fertile window or ovulation anywhere, the
    /// hormonal note, and "Expected bleed" instead of "Next period".
    @MainActor
    func testTrackingOnThePillHidesTheFertileWindow() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile", cycleGoal: "tracking", contraception: "pill")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertFalse(status.label.contains("chance"), status.label)
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
        XCTAssertTrue(status.label.contains("Expected bleed"), status.label)
        let next = app.descendants(matching: .any)["cycleNextPeriodCard"]
        app.scrollUntilHittable(next)
        XCTAssertTrue(next.label.contains("Expected bleed"), next.label)
        XCTAssertFalse(app.descendants(matching: .any)["cycleFertileCard"].exists)
        XCTAssertFalse(app.staticTexts["cycleNotContraceptionNote"].exists)
        let hormonal = app.staticTexts["cycleHormonalNote"]
        app.scrollUntilHittable(hormonal)
        XCTAssertTrue(hormonal.exists)

        app.openCycleTab(.calendar)
        let legend = app.descendants(matching: .any)["calendarLegend"]
        XCTAssertTrue(legend.waitForExistence(timeout: 5))
        XCTAssertTrue(legend.label.contains("Expected bleed"), legend.label)
        XCTAssertFalse(legend.label.contains("Fertile window"), legend.label)
        XCTAssertFalse(legend.label.contains("Ovulation"), legend.label)
        let selected = app.descendants(matching: .any)["calendarSelectedDay"]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        XCTAssertTrue(selected.label.contains("Day 13 of your cycle"), selected.label)
    }

    /// Tracking without hormonal contraception: an ordinary day outside the
    /// window (October 10, cycle day 21 of the "fertile" seed; the window is
    /// 09-29…10-05) has no status at all, never "Low chance of conceiving".
    @MainActor
    func testTrackingOrdinaryDayHasNoLowChanceLabel() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile", cycleGoal: "tracking", contraception: "copperIUD")
        app.openCycleTab(.calendar)
        XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
        let day = app.buttons.matching(NSPredicate(format: "identifier == 'calendarDay' AND label BEGINSWITH %@", "October 10,")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        XCTAssertFalse(day.label.contains("chance"), day.label)
        day.tap()
        let selected = app.descendants(matching: .any)["calendarSelectedDay"]
        waitForLabel(selected, containing: "Oct 10")
        XCTAssertTrue(selected.label.contains("Day 21 of your cycle"), selected.label)
        XCTAssertFalse(selected.label.contains("Low chance"), selected.label)
        XCTAssertFalse(selected.label.contains("chance"), selected.label)
    }
}
