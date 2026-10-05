import XCTest

/// Spec §4.7 and §6: 7 days / 4 weeks and the sessions list, with `-seedSessions`.
final class HistoryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchSeeded(language: String = "en", dark: Bool = false) -> XCUIApplication {
        XCUIApplication.launchPinned(
            language: language, dark: dark, dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedSessions"]
        )
    }

    @MainActor
    func testSevenDaysAndFourWeeks() {
        let app = launchSeeded()
        app.openHistory()
        let average = app.descendants(matching: .any)["historyAverage"]
        XCTAssertTrue(average.waitForExistence(timeout: 10))
        // 19, 31, 16 (and a later 75), 27, 21 and 18 minutes over the last 7 days.
        XCTAssertTrue(average.label.contains("30 min"), average.label)
        XCTAssertTrue(app.buttons["historyRange7"].isSelected)

        app.buttons["historyRange28"].tap()
        waitForLabel(average, containing: "26 min")
        XCTAssertTrue(app.buttons["historyRange28"].isSelected)
        app.buttons["historyRange7"].tap()
        waitForLabel(average, containing: "30 min")
    }

    @MainActor
    func testSessionsListMarksTheCancelledSession() {
        let app = launchSeeded()
        app.openHistory()
        let rows = app.descendants(matching: .any).matching(identifier: "sessionRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(rows.firstMatch.label.contains("10 movements"), rows.firstMatch.label)
        XCTAssertTrue(rows.firstMatch.label.contains("18 min"), rows.firstMatch.label)
        let cancelled = rows.matching(NSPredicate(format: "label CONTAINS 'Cancelled'")).firstMatch
        app.scrollUntilHittable(cancelled)
        XCTAssertTrue(cancelled.exists)
        XCTAssertTrue(cancelled.label.contains("4 movements"), cancelled.label)
    }

    @MainActor
    func testEmptyHistory() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38)
        app.openHistory()
        XCTAssertTrue(app.staticTexts["No sessions yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["historyAverage"].label.contains("–"))
    }
}
