import XCTest

/// Today only scrolls vertically, in both modes: no card may make the scroll
/// content wider than the screen, or the whole screen pans and bounces sideways.
final class TodayLayoutUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testPregnancyTodayDoesNotPanSideways() {
        for language in ["vi", "en"] {
            let app = XCUIApplication.launchPinned(language: language, dueDate: UITestDates.dueAtWeek24)
            assertOnlyScrollsVertically(app, "pregnancy \(language)")
            app.terminate()
        }
    }

    @MainActor
    func testCycleTodayDoesNotPanSideways() {
        for language in ["vi", "en"] {
            let app = XCUIApplication.launchPinned(language: language, seedCycles: "fertile")
            assertOnlyScrollsVertically(app, "cycle \(language)")
            app.terminate()
        }
    }

    @MainActor
    private func assertOnlyScrollsVertically(_ app: XCUIApplication, _ context: String) {
        let header = app.descendants(matching: .any)["headerDate"]
        XCTAssertTrue(header.waitForExistence(timeout: 10), context)
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), context)
        let screenWidth = app.windows.firstMatch.frame.width
        // Content even a pixel wider than the screen widens the scroll view
        // and lets it scroll horizontally.
        XCTAssertLessThanOrEqual(scrollView.frame.width, screenWidth, "scroll view wider than the screen (\(context))")

        let minX = header.frame.minX
        // Drags start on the date, which is plain text: from a card or the
        // fetus they could open it instead.
        let start = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for dx in [150.0, -150.0] {
            // Diagonal, mostly sideways: the owner's gesture.
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 30)), withVelocity: .fast, thenHoldForDuration: 0)
        }
        for dx in [-250.0, 250.0] {
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)), withVelocity: .fast, thenHoldForDuration: 0)
        }
        XCTAssertTrue(header.isHittable, "Today is no longer showing (\(context))")
        // Wait for any bounce to settle, then compare.
        let settled = NSPredicate { _, _ in abs(header.frame.minX - minX) < 0.01 }
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 3)
        XCTAssertEqual(result, .completed, "header moved sideways from \(minX) to \(header.frame.minX) (\(context))")
    }
}
