import XCTest

/// Spec §4.9: the redesigned sheets keep their behaviour.
final class SheetsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// ±1 day moves the date; switching between last period and due date keeps the pregnancy.
    @MainActor
    func testImPregnantSheetMovesTheDateADayAtATime() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "late")
        let button = app.buttons["imPregnantButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        app.scrollUntilHittable(button)
        button.tap()

        // Prefilled with the latest period (2026-08-31): 32 days.
        let result = app.staticTexts["pregnancyEstimatedDue"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("4 weeks, 4 days"), result.label)
        XCTAssertTrue(result.label.contains("June 7, 2027"), result.label)
        XCTAssertTrue(app.buttons["imPregnantSourceLMP"].isSelected)

        app.buttons["imPregnantEarlier"].tap()
        waitForLabel(result, containing: "4 weeks, 5 days")
        app.buttons["imPregnantSourceDue"].tap()
        waitForLabel(result, containing: "June 6, 2027")
        XCTAssertTrue(result.label.contains("4 weeks, 5 days"), result.label)
        XCTAssertTrue(app.buttons["imPregnantSourceDue"].isSelected)

        app.buttons["imPregnantCancel"].tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
    }

    /// The day log keeps Save above the keyboard and picks mucus with chips.
    @MainActor
    func testDayLogSavesMucusFromChips() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "period")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday)
        logToday.tap()
        XCTAssertTrue(app.staticTexts["lunaSheetTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["lunaSheetTitle"].label, "Today, Oct 2")
        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("36.6")
        XCTAssertTrue(app.buttons["dayLogSave"].isHittable) // stays above the keyboard
        let sticky = app.buttons["Sticky"]
        app.scrollUntilHittable(sticky)
        sticky.tap()
        XCTAssertTrue(sticky.isSelected)
        app.buttons["dayLogSave"].tap()
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.buttons["dayLogSave"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 5), .completed)
        XCTAssertTrue(logToday.label.contains("Sticky"), logToday.label)
        XCTAssertTrue(logToday.label.contains("36.6"), logToday.label)
    }
}
