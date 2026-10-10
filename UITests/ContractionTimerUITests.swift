import XCTest

/// Phase 20 spec §5: the contraction timer's entries, timing, delete, undo and
/// the two alert cards from the DEBUG seeds.
final class ContractionTimerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTodayShortcutFromWeek28AndKicksRowInAnyWeek() {
        let week30 = XCUIApplication.launchPinned(dueDate: UITestDates.dueAtWeek30)
        let shortcut = week30.buttons["shortcutContractions"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        week30.scrollUntilHittable(shortcut)
        shortcut.tap()
        XCTAssertTrue(week30.buttons["contractionToggle"].waitForExistence(timeout: 5))
        week30.terminate()

        let week20 = XCUIApplication.launchPinned(dueDate: UITestDates.dueAtWeek20)
        XCTAssertTrue(week20.buttons["shortcutKicks"].waitForExistence(timeout: 10))
        XCTAssertFalse(week20.buttons["shortcutContractions"].exists)
        week20.openContractionTimer()
        XCTAssertTrue(week20.descendants(matching: .any)["contractionListEmpty"].exists)
    }

    @MainActor
    func testTimesContractionsThenDeletesAndUndoes() {
        // "Hoàn tác" for 30 s, not 5: a slow CI simulator may not tap it in time.
        let app = XCUIApplication.launchPinned(
            dueDate: UITestDates.dueAtWeek38, extraArguments: ["-contractionUndoWindow", "30"]
        )
        app.openContractionTimer()
        let toggle = app.buttons["contractionToggle"]
        for _ in 0..<3 {
            timeOneContraction(app, toggle)
        }
        XCTAssertEqual(rows(app).count, 3)
        let count = app.descendants(matching: .any)["contractionStatsCount"]
        waitForLabel(count, containing: "3")
        XCTAssertTrue(app.descendants(matching: .any)["contractionSafety"].exists)

        // Delete the newest, with a confirmation.
        let delete = app.buttons["contractionDelete"].firstMatch
        app.scrollUntilHittable(delete)
        delete.tap()
        app.confirmDialog("Delete")
        waitForCount(app, 2)
        waitForLabel(count, containing: "2")

        // A tap, then "Undo": nothing started.
        app.scrollDownUntilHittable(toggle)
        toggle.tap()
        waitForLabel(toggle, containing: "Contraction over")
        let undo = app.buttons["contractionUndo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        waitForLabel(toggle, containing: "Start contraction")
        waitForCount(app, 2)

        // "End tracking" asks first: cancelling keeps the session.
        let endEpisode = app.buttons["contractionEndEpisode"]
        app.scrollUntilHittable(endEpisode)
        endEpisode.tap()
        app.confirmDialog("Cancel")
        waitForCount(app, 2)
        app.scrollUntilHittable(endEpisode)
        endEpisode.tap()
        app.confirmDialog("End tracking")
        XCTAssertTrue(app.descendants(matching: .any)["contractionListEmpty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFiveOneOneSeedShowsTheCardWithTheCallButton() {
        let app = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedContractions", "511"]
        )
        app.openContractionTimer()
        XCTAssertTrue(app.descendants(matching: .any)["contractionFiveOneOneCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["contractionPretermCard"].exists)
        XCTAssertEqual(app.buttons["contractionCallButton"].label, "Gọi cấp cứu 115")
        XCTAssertTrue(app.descendants(matching: .any)["contractionSafety"].exists)
    }

    @MainActor
    func testPretermSeedAtWeek33ShowsTheUrgentCard() {
        let app = XCUIApplication.launchPinned(
            dueDate: UITestDates.dueAtWeek33, extraArguments: ["-seedContractions", "preterm"]
        )
        app.openContractionTimer()
        XCTAssertTrue(app.descendants(matching: .any)["contractionPretermCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["contractionFiveOneOneCard"].exists)
        // English has no single emergency number, as the kick alert.
        XCTAssertFalse(app.buttons["contractionCallButton"].exists)
    }

    @MainActor
    func testHistoryShowsThePastEpisode() {
        let app = XCUIApplication.launchPinned(
            dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedContractions", "511"]
        )
        app.openContractionTimer()
        let history = app.buttons["contractionHistory"]
        app.scrollUntilHittable(history, maxSwipes: 10)
        history.tap()
        let row = app.descendants(matching: .any)["contractionEpisodeRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        waitForLabel(row, containing: "3 contractions")
    }

    // MARK: - Helpers

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "contractionRow")
    }

    /// Starts a contraction, waits until it has run 3 s (shorter is a mis-tap),
    /// and stops it.
    @MainActor
    private func timeOneContraction(_ app: XCUIApplication, _ toggle: XCUIElement) {
        app.scrollDownUntilHittable(toggle)
        toggle.tap()
        waitForLabel(toggle, containing: "Contraction over")
        let pastMinimum = NSPredicate(format: "value MATCHES %@", ".*0:0[4-9].*")
        let waited = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: pastMinimum, object: toggle)], timeout: 10)
        XCTAssertEqual(waited, .completed, "the timer did not reach 0:04: \(toggle.value ?? "")")
        toggle.tap()
        waitForLabel(toggle, containing: "Start contraction")
    }

    @MainActor
    private func waitForCount(_ app: XCUIApplication, _ count: Int, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "count == %d", count)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: rows(app))], timeout: 5)
        XCTAssertEqual(result, .completed, "expected \(count) rows, found \(rows(app).count)", file: file, line: line)
    }
}
