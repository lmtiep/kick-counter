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
}
