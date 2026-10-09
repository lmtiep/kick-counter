import XCTest

/// Phase 17 spec §5: the pill reminder sheet and the Today card, in vi
/// light/dark and at AX5.
final class PillReminderScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(dark: Bool = false, largestText: Bool = false, seedPill: String = "21+7:11") -> XCUIApplication {
        XCUIApplication.launchPinned(
            language: "vi", dark: dark, seedCycles: "fertile", cycleGoal: "tracking", contraception: "pill",
            largestText: largestText, extraArguments: ["-seedPill", seedPill]
        )
    }

    @MainActor
    private func showCard(_ app: XCUIApplication) {
        let card = app.descendants(matching: .any)["pillTodayCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollUntilHittable(card, maxSwipes: 10)
    }

    @MainActor
    private func openSheet(_ app: XCUIApplication) {
        app.openCycleTab(.profile)
        let row = app.buttons["profilePillReminder"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.scrollUntilHittable(row, maxSwipes: 12)
        row.tap()
        XCTAssertTrue(app.switches["pillReminderToggle"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPillScreens() {
        for dark in [false, true] {
            let suffix = UITestVariants.suffix("vi", dark)
            let app = launch(dark: dark)
            showCard(app)
            attachScreenshot(app, "pill-today-\(suffix)")
            let take = app.buttons["pillTakeToday"]
            app.scrollUntilHittable(take)
            take.tap()
            XCTAssertTrue(app.buttons["pillUndo"].waitForExistence(timeout: 5))
            attachScreenshot(app, "pill-today-taken-\(suffix)")
            openSheet(app)
            attachScreenshot(app, "pill-sheet-\(suffix)")
            app.terminate()

            let breakWeek = launch(dark: dark, seedPill: "21+7:23")
            showCard(breakWeek)
            attachScreenshot(breakWeek, "pill-today-break-\(suffix)")
            breakWeek.terminate()
        }
    }

    @MainActor
    func testPillScreensAtLargestText() {
        let app = launch(largestText: true)
        showCard(app)
        let take = app.buttons["pillTakeToday"]
        app.scrollUntilHittable(take)
        XCTAssertTrue(take.isHittable)
        attachScreenshot(app, "pill-today-vi-ax5")
        take.tap()
        let undo = app.buttons["pillUndo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        app.scrollUntilHittable(undo)
        XCTAssertTrue(undo.isHittable)
        attachScreenshot(app, "pill-today-taken-vi-ax5")
        openSheet(app)
        attachScreenshot(app, "pill-sheet-vi-ax5")
        // Nothing (a compact date picker) may widen the sheet past the screen.
        let title = app.staticTexts["pillSheetTitle"]
        XCTAssertGreaterThanOrEqual(title.frame.minX, 0)
        XCTAssertLessThanOrEqual(title.frame.maxX, app.frame.maxX)
        let done = app.buttons["pillReminderDone"]
        scrollSheetUntilHittable(app, done)
        XCTAssertTrue(done.isHittable)
        attachScreenshot(app, "pill-sheet-vi-ax5-bottom")
    }

    /// Swipes along the sheet's left edge, outside the card: at AX5 the centre
    /// of the screen is often a date wheel, which a swipe would spin instead.
    @MainActor
    private func scrollSheetUntilHittable(_ app: XCUIApplication, _ element: XCUIElement, maxSwipes: Int = 12) {
        var remaining = maxSwipes
        while !(element.exists && element.isHittable), remaining > 0 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.8))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.3)))
            remaining -= 1
        }
    }
}
