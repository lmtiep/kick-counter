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
        app.openTab(.kicks)
    }

    private func completeOnboarding() {
        app.completeOnboardingPregnantWithoutDates()
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
    /// `Task` in `KicksView`, so the accessibility value updates asynchronously after
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

        app.openHistory()
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
        // Wait for the dialog itself (a sheet, or a popover on newer iOS) instead of
        // guessing after 2 s: on a slow runner it appeared late and the fallback tapped
        // a button that wasn't there yet.
        let sheetButton = app.sheets.buttons["Cancel session"]
        let named = app.buttons.matching(identifier: "Cancel session")
        let deadline = Date().addingTimeInterval(10)
        while !(sheetButton.exists || named.count > 1), Date() < deadline {
            _ = sheetButton.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(sheetButton.exists || named.count > 1, "cancel confirmation never appeared")
        (sheetButton.exists ? sheetButton : named.element(boundBy: 1)).tap()
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
