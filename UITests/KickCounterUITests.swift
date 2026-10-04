import XCTest

final class KickCounterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Fixed language so assertions can match the accessibility value text.
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        completeOnboarding()
        app.openTab(.counter)
    }

    private func completeOnboarding() {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        next.tap()
        app.buttons["onboardingAgree"].tap()
        let pregnant = app.buttons["onboardingModePregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
    }

    private func tapKick(times: Int) {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 5))
        for _ in 0..<times {
            kick.tap()
            Thread.sleep(forTimeInterval: 0.6) // stay above the 0.5 s debounce
        }
    }

    /// Accessibility value of the kick button, e.g. "2 of 10 movements".
    private var kickValue: String? {
        app.buttons["kickButton"].value as? String
    }

    /// Waits for the kick button's accessibility value to become `expected` and asserts it.
    ///
    /// Counter mutations (`recordKick`, `undo`, `cancelSession`) all run inside an async
    /// `Task` in `CounterView`, so the accessibility value updates asynchronously after
    /// the triggering tap. Reading `kickValue` immediately after a tap races that update and
    /// can observe the stale value (seen flaking on CI); wait for the predicate instead of
    /// asserting straight away.
    @MainActor
    private func waitForKickValue(
        _ expected: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let kick = app.buttons["kickButton"]
        let reached = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected),
            object: kick
        )
        XCTAssertEqual(XCTWaiter().wait(for: [reached], timeout: timeout), .completed, file: file, line: line)
        XCTAssertEqual(kickValue, expected, file: file, line: line)
    }

    @MainActor
    func testCountingTenMovementsShowsCompletionAndHistory() {
        tapKick(times: 10)

        XCTAssertTrue(app.staticTexts["completionTitle"].waitForExistence(timeout: 5))
        app.buttons["completionDone"].tap()

        app.openTab(.history)
        XCTAssertTrue(app.descendants(matching: .any)["sessionRow"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testUndoRemovesLastMovement() {
        tapKick(times: 3)
        app.buttons["undoButton"].tap()
        waitForKickValue("2 of 10 movements")
    }

    @MainActor
    func testCancelResetsCounter() {
        tapKick(times: 2)
        app.buttons["cancelSessionButton"].tap()
        let confirm = app.sheets.buttons["Cancel session"]
        if confirm.waitForExistence(timeout: 2) {
            confirm.tap()
        } else {
            // Newer iOS versions may render the dialog as a popover rather than a sheet.
            app.buttons.matching(identifier: "Cancel session").element(boundBy: 1).tap()
        }
        waitForKickValue("0 of 10 movements")
    }

    @MainActor
    func testDebounceIgnoresAccidentalDoubleTap() {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 5))
        kick.doubleTap()
        waitForKickValue("1 of 10 movements")

        // The debounce must hold: confirm the second tap of the double-tap never gets
        // counted later by asserting the value does NOT progress to "2 of 10 movements"
        // within a short settle window (an inverted expectation, not a fixed sleep gate).
        let regressed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "2 of 10 movements"),
            object: kick
        )
        let result = XCTWaiter().wait(for: [regressed], timeout: 1.5)
        XCTAssertEqual(result, .timedOut, "second tap of the double-tap must remain debounced")
    }
}
