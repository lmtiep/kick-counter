import XCTest

/// Phase 10: the cycle history page and a cycle's detail (pinned clock,
/// "fertile": three 28-day cycles, cycle day 13, logs on Sep 28 – Oct 2).
final class CycleHistoryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openHistory(_ app: XCUIApplication) {
        let link = app.buttons["cycleHistoryLink"]
        app.scrollUntilHittable(link)
        link.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cycleHistorySummary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryShowsTheSummaryAndEveryCycle() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        XCTAssertTrue(app.staticTexts["cycleHistoryAverageCycle"].label.contains("28 days"))
        XCTAssertTrue(app.staticTexts["cycleHistoryAveragePeriod"].label.contains("5 days"))
        let rows = app.buttons.matching(identifier: "cycleHistoryRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(rows.firstMatch.label.contains("Current cycle"), rows.firstMatch.label)
        app.scrollUntilHittable(rows.element(boundBy: 3))
        XCTAssertEqual(rows.count, 4)
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("28 days"), rows.element(boundBy: 1).label)
        XCTAssertTrue(rows.element(boundBy: 1).label.contains("period 5 days"), rows.element(boundBy: 1).label)
    }

    @MainActor
    func testCycleDetailListsLoggedDaysAndEditsOne() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        app.buttons.matching(identifier: "cycleHistoryRow").firstMatch.tap()
        let days = app.buttons.matching(identifier: "cycleDetailDay")
        XCTAssertTrue(days.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(days.count, 5)
        XCTAssertTrue(days.firstMatch.label.hasPrefix("Day 9"), days.firstMatch.label)
        let last = days.element(boundBy: 4)
        app.scrollUntilHittable(last)
        XCTAssertTrue(last.label.hasPrefix("Day 13"), last.label)
        last.tap()
        // `TextField(axis: .vertical)` shows up as a text field (CI hierarchy, run 37708044169).
        let note = app.textFields["dayLogNoteField"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        app.scrollUntilHittable(note)
        note.tap()
        note.typeText("Mild back pain")
        app.buttons["dayLogSave"].tap()
        let edited = app.buttons.matching(NSPredicate(format: "identifier == 'cycleDetailDay' AND label CONTAINS %@", "Mild back pain")).firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAnOlderCycleWithoutLogsSaysSo() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        let rows = app.buttons.matching(identifier: "cycleHistoryRow")
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
        rows.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["cycleDetailEmpty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testIrregularCyclesShowTheRangeLine() {
        // CycleSeed.irregular: 24/35/26/34-day cycles (all within 21...45), so
        // all four count toward the average: range 24...35 (final review —
        // `cycleHistoryRange` must stay reachable, not swallowed by a `.combine`
        // container's own identifier).
        let app = XCUIApplication.launchPinned(seedCycles: "irregular")
        openHistory(app)
        let range = app.staticTexts["cycleHistoryRange"]
        XCTAssertTrue(range.waitForExistence(timeout: 5))
        XCTAssertTrue(range.label.contains("24–35 days"), range.label)
    }

    @MainActor
    func testHormonalUsersReadBleedingNotPeriod() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile", cycleGoal: "tracking", contraception: "pill")
        openHistory(app)
        XCTAssertTrue(app.staticTexts["cycleHistoryAveragePeriod"].label.contains("Average bleed"))
        let row = app.buttons.matching(identifier: "cycleHistoryRow").element(boundBy: 1)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("bleeding 5 days"), row.label)
    }

    // MARK: - Phase 13: past periods

    /// Opens "Add a past period"; the start picker shows May 2026 (one typical
    /// cycle before the oldest period, Jun 28). Picks `day` in June.
    @MainActor
    private func addPastPeriod(_ app: XCUIApplication, juneDay day: Int) {
        let add = app.buttons["cycleHistoryAddPast"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        app.scrollUntilHittable(add)
        add.tap()
        let next = app.buttons["Next Month"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        // Day cells read e.g. "Thursday, June 4".
        let dayButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "June \(day)")).firstMatch
        XCTAssertTrue(dayButton.waitForExistence(timeout: 5))
        dayButton.tap()
        let range = app.descendants(matching: .any)["addPastRange"]
        waitForLabel(range, containing: "June \(day)")
        let save = app.buttons["addPastSave"]
        app.scrollUntilHittable(save)
        save.tap()
    }

    /// Spec §3.2: a period 120 days before the pinned clock (Jun 4, 5 days) is
    /// added; the history gains a row and confirms with a toast.
    @MainActor
    func testAddPastPeriodFromHistory() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        let rows = app.buttons.matching(identifier: "cycleHistoryRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 4)
        addPastPeriod(app, juneDay: 4)
        XCTAssertTrue(app.staticTexts["toast"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["toast"].label.contains("Period added"))
        let added = app.buttons.matching(NSPredicate(format: "identifier == 'cycleHistoryRow' AND label CONTAINS %@", "June 4")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(added.label.contains("24 days"), added.label) // to Jun 28
        XCTAssertTrue(added.label.contains("period 5 days"), added.label)
    }

    /// Spec §3.2: a start inside a logged period (Jun 28 – Jul 2) shows the
    /// overlap inline and saves nothing.
    @MainActor
    func testAddPastPeriodOverlapShowsError() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        openHistory(app)
        addPastPeriod(app, juneDay: 30)
        let error = app.descendants(matching: .any)["addPastError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("overlaps a period"), error.label)
        let cancel = app.buttons["addPastCancel"]
        app.scrollUntilHittable(cancel)
        cancel.tap()
        let rows = app.buttons.matching(identifier: "cycleHistoryRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 4)
    }

    /// Calendar tab → June 2026 (well before the Jun 28 period).
    @MainActor
    private func openCalendarAtJune(_ app: XCUIApplication) {
        app.openCycleTab(.calendar)
        let title = app.staticTexts["calendarMonthTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let previous = app.buttons["calendarPrevious"]
        for month in ["September", "August", "July", "June"] {
            // CI run 37810272723: one of several back-to-back taps left the month
            // unchanged, so a tap that does not move the month is repeated.
            for _ in 0..<3 where !title.label.contains(month) {
                previous.tap()
                let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", month), object: title)
                _ = XCTWaiter().wait(for: [moved], timeout: 2)
            }
            XCTAssertTrue(title.label.contains(month), title.label)
        }
    }

    /// Selects `June <day>` in the calendar and opens its day log.
    @MainActor
    private func openDayLog(_ app: XCUIApplication, juneDay day: Int) {
        // A plain day reads "June 10"; a day with something on it "June 10, …".
        let cell = app.buttons.matching(NSPredicate(
            format: "identifier == 'calendarDay' AND (label == %@ OR label BEGINSWITH %@)", "June \(day)", "June \(day),"
        )).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        let logButton = app.buttons["calendarLogButton"]
        app.scrollUntilHittable(logButton)
        XCTAssertTrue(logButton.isEnabled)
        logButton.tap()
    }

    @MainActor
    private func closeDayLog(_ app: XCUIApplication) {
        let cancel = app.buttons["dayLogCancel"]
        app.scrollUntilHittable(cancel)
        cancel.tap()
        XCTAssertTrue(app.buttons["calendarLogButton"].waitForExistence(timeout: 5))
    }

    /// Starts a period on Jun 10 from the calendar's day log.
    @MainActor
    private func startPeriodOnJune10(_ app: XCUIApplication) {
        openCalendarAtJune(app)
        openDayLog(app, juneDay: 10)
        let start = app.buttons["dayLogStartPeriod"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.scrollUntilHittable(start)
        start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dayLogPeriodInfo"].waitForExistence(timeout: 5))
        closeDayLog(app)
    }

    @MainActor
    private func historyRow(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.openCycleTab(.today)
        openHistory(app)
        let row = app.buttons.matching(NSPredicate(format: "identifier == 'cycleHistoryRow' AND label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        return row
    }

    /// Spec §3.1: starting a period on an old calendar day stores it closed at
    /// the typical length (5 days), not open for 10.
    @MainActor
    func testStartingAPeriodOnAnOldDayClosesIt() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        startPeriodOnJune10(app)
        let row = historyRow(app, containing: "June 10")
        XCTAssertTrue(row.label.contains("period 5 days"), row.label)
    }

    /// Final review: the day after an assumed end offers to end that period
    /// there first, so day 7 lengthens it to 7 days instead of starting a new one.
    @MainActor
    func testEndingAnAutoClosedPeriodLaterExtendsIt() {
        let app = XCUIApplication.launchPinned(seedCycles: "fertile")
        startPeriodOnJune10(app)
        openDayLog(app, juneDay: 16)
        let extend = app.buttons["dayLogExtendPeriod"]
        XCTAssertTrue(extend.waitForExistence(timeout: 5))
        XCTAssertEqual(extend.label, "End the period on this day")
        let start = app.buttons["dayLogStartPeriod"]
        XCTAssertLessThan(extend.frame.minY, start.frame.minY, "ending the earlier period comes first")
        app.scrollUntilHittable(extend)
        extend.tap()
        let info = app.descendants(matching: .any)["dayLogPeriodInfo"]
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        XCTAssertTrue(info.label.contains("June 16"), info.label)
        closeDayLog(app)
        let row = historyRow(app, containing: "June 10")
        XCTAssertTrue(row.label.contains("period 7 days"), row.label)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier == 'cycleHistoryRow' AND label CONTAINS %@", "June 16")).firstMatch.exists)
    }
}
