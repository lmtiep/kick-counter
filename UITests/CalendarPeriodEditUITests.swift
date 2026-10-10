import XCTest

/// Phase 19: "Edit period" on the cycle calendar (pinned clock Oct 2, 2026;
/// "fertile": periods Jun 28, Jul 26, Aug 23 and Sep 20, 5 days each).
final class CalendarPeriodEditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Calendar tab, then back `months` (October first) until the title shows `month`.
    @MainActor
    static func openCalendar(_ app: XCUIApplication, backTo months: [String]) {
        app.openCycleTab(.calendar)
        let title = app.staticTexts["calendarMonthTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let previous = app.buttons["calendarPrevious"]
        for month in months {
            // A tap that does not move the month is repeated (CI run 37810272723).
            for _ in 0..<3 where !title.label.contains(month) {
                previous.tap()
                let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", month), object: title)
                _ = XCTWaiter().wait(for: [moved], timeout: 2)
            }
            XCTAssertTrue(title.label.contains(month), title.label)
        }
    }

    @MainActor
    static func startEditing(_ app: XCUIApplication) {
        let edit = app.buttons["calendarEditPeriods"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        app.scrollUntilHittable(edit)
        edit.tap()
        XCTAssertTrue(app.buttons["periodEditSave"].waitForExistence(timeout: 5))
    }

    /// The edit-mode cell for `yyyymmdd`.
    @MainActor
    static func day(_ app: XCUIApplication, _ yyyymmdd: String) -> XCUIElement {
        app.buttons["periodEditDay-\(yyyymmdd)"]
    }

    @MainActor
    private func toggle(_ app: XCUIApplication, _ days: [String]) {
        for yyyymmdd in days {
            let cell = Self.day(app, yyyymmdd)
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            app.scrollUntilHittable(cell)
            let wasSelected = cell.isSelected
            cell.tap()
            let flipped = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in cell.isSelected != wasSelected }, object: nil)
            XCTAssertEqual(XCTWaiter().wait(for: [flipped], timeout: 3), .completed, "\(yyyymmdd) did not toggle")
        }
    }

    @MainActor
    private func save(_ app: XCUIApplication) {
        let save = app.buttons["periodEditSave"]
        app.scrollDownUntilHittable(save)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["calendarEditPeriods"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openHistory(_ app: XCUIApplication) {
        app.openCycleTab(.today)
        let link = app.buttons["cycleHistoryLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        app.scrollUntilHittable(link, maxSwipes: 12)
        link.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cycleHistorySummary"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func historyRow(_ app: XCUIApplication, startedOn day: String, period: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier == 'cycleHistoryRow' AND label CONTAINS %@ AND label CONTAINS %@", "\(day),", "period \(period)"
        )).firstMatch
    }

    // MARK: - Tests

    /// Spec §3: two runs ticked in August are saved at once and listed in History.
    @MainActor
    func testTickTwoRunsInAnEarlierMonthAndSave() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        Self.openCalendar(app, backTo: ["September"])
        Self.startEditing(app)
        // Ticks survive changing month until Save.
        let previous = app.buttons["calendarPrevious"]
        app.scrollDownUntilHittable(previous)
        previous.tap()
        waitForLabel(app.staticTexts["calendarMonthTitle"], containing: "August")
        XCTAssertTrue(Self.day(app, "20260823").isSelected)
        toggle(app, ["20260803", "20260804", "20260805", "20260810", "20260811"])
        save(app)

        openHistory(app)
        for (day, period) in [("August 3", "3 days"), ("August 10", "2 days"), ("August 23", "5 days")] {
            let row = historyRow(app, startedOn: day, period: period)
            app.scrollUntilHittable(row, maxSwipes: 10)
            XCTAssertTrue(row.exists, "no row for \(day)")
        }
    }

    /// Spec §3: unticking Sep 22 splits Sep 20–24 into two periods.
    @MainActor
    func testUntickingADaySplitsAPeriod() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        Self.openCalendar(app, backTo: ["September"])
        Self.startEditing(app)
        let middle = Self.day(app, "20260922")
        XCTAssertTrue(middle.waitForExistence(timeout: 5))
        XCTAssertTrue(middle.isSelected)
        XCTAssertTrue(middle.label.contains("period day"), middle.label)
        toggle(app, ["20260922"])
        XCTAssertFalse(middle.label.contains("period day"), middle.label)
        save(app)

        openHistory(app)
        let first = historyRow(app, startedOn: "September 20", period: "2 days")
        app.scrollUntilHittable(first, maxSwipes: 10)
        XCTAssertTrue(first.exists)
        let rows = app.buttons.matching(identifier: "cycleHistoryRow")
        XCTAssertTrue(rows.firstMatch.label.contains("Current cycle"), rows.firstMatch.label)
        XCTAssertTrue(rows.firstMatch.label.contains("period 2 days"), rows.firstMatch.label)
    }

    /// Spec §2.1: Cancel with changes asks first; without changes it just leaves.
    @MainActor
    func testCancelWithChangesAsksToConfirm() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        Self.openCalendar(app, backTo: [])
        Self.startEditing(app)
        let cancel = app.buttons["periodEditCancel"]
        cancel.tap()
        XCTAssertTrue(app.buttons["calendarEditPeriods"].waitForExistence(timeout: 5))

        Self.startEditing(app)
        XCTAssertFalse(app.buttons["periodEditSave"].isEnabled)
        toggle(app, ["20261001"])
        XCTAssertTrue(app.buttons["periodEditSave"].isEnabled)
        cancel.tap()
        XCTAssertTrue(app.staticTexts["Discard changes?"].waitForExistence(timeout: 5))
        app.confirmDialog("Discard")
        XCTAssertTrue(app.buttons["calendarEditPeriods"].waitForExistence(timeout: 5))

        // Nothing was saved: Oct 1 starts unticked again.
        Self.startEditing(app)
        XCTAssertFalse(Self.day(app, "20261001").isSelected)
    }

    /// Spec §2.1: future days are dimmed and cannot be tapped; today can.
    @MainActor
    func testFutureDaysCannotBeTicked() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        Self.openCalendar(app, backTo: [])
        Self.startEditing(app)
        let future = Self.day(app, "20261010")
        XCTAssertTrue(future.waitForExistence(timeout: 5))
        XCTAssertFalse(future.isEnabled)
        XCTAssertTrue(Self.day(app, "20261002").isEnabled)
        XCTAssertTrue(Self.day(app, "20261002").label.contains("today"), Self.day(app, "20261002").label)
        XCTAssertFalse(app.buttons["periodEditSave"].isEnabled)
    }

    /// Spec §2.2: a run longer than 10 days shows the error inline and stays in edit mode.
    @MainActor
    func testARunLongerThanTenDaysShowsTheError() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        Self.openCalendar(app, backTo: ["September"])
        Self.startEditing(app)
        // Sep 20–24 plus Sep 25–30: 11 days.
        toggle(app, ["20260925", "20260926", "20260927", "20260928", "20260929", "20260930"])
        let save = app.buttons["periodEditSave"]
        app.scrollDownUntilHittable(save)
        save.tap()
        let error = app.descendants(matching: .any)["periodEditError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("at most 10 days"), error.label)
        XCTAssertTrue(save.exists)
    }
}
