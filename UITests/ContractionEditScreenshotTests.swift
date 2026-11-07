import XCTest

/// Edit spec 2026-11-06 §Tests: the edit sheet, the add-missed sheet and the
/// water-broke card, in vi light and dark, plus AX5.
final class ContractionEditScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(dark: Bool = false, largestText: Bool = false, seed: String? = nil) -> XCUIApplication {
        XCUIApplication.launchPinned(
            language: "vi", dark: dark, dueDate: UITestDates.dueAtWeek38, largestText: largestText,
            extraArguments: seed.map { ["-seedContractions", $0] } ?? []
        )
    }

    /// Opens the edit sheet of the newest row, the add-missed sheet, then the water-broke sheet and its card.
    @MainActor
    private func shoot(_ app: XCUIApplication, suffix: String) {
        app.openContractionTimer()
        let row = app.descendants(matching: .any).matching(identifier: "contractionRow").firstMatch
        app.scrollUntilHittable(row, maxSwipes: 20)
        let title = app.staticTexts["contractionEditTitle"]
        row.tapOpening(title, in: app)
        attachScreenshot(app, "contraction-edit-sheet-\(suffix)")
        app.buttons["contractionEditCancel"].tapOrScroll(app)

        let add = app.buttons["contractionAddMissed"]
        app.scrollDownUntilHittable(add, maxSwipes: 20)
        app.scrollUntilHittable(add, maxSwipes: 20)
        add.tapOpening(title, in: app)
        attachScreenshot(app, "contraction-add-missed-sheet-\(suffix)")
        app.buttons["contractionEditCancel"].tapOrScroll(app)

        let water = app.buttons["contractionWaterBroke"]
        app.scrollDownUntilHittable(water, maxSwipes: 20)
        app.scrollUntilHittable(water, maxSwipes: 20)
        water.tapOpening(app.staticTexts["contractionWaterBrokeTitle"], in: app)
        attachScreenshot(app, "contraction-water-broke-sheet-\(suffix)")
        app.buttons["contractionWaterBrokeSave"].tapOrScroll(app)

        let card = app.descendants(matching: .any)["contractionWaterBrokeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.scrollUntilHittable(app.buttons["contractionMarkerDelete"], maxSwipes: 20)
        attachScreenshot(app, "contraction-water-broke-card-\(suffix)")
    }

    @MainActor
    func testEditScreens() {
        for dark in [false, true] {
            let app = launch(dark: dark, seed: "511")
            shoot(app, suffix: UITestVariants.suffix("vi", dark))
            app.terminate()
        }
    }

    @MainActor
    func testEditScreensAtLargestText() {
        let app = launch(largestText: true, seed: "511")
        shoot(app, suffix: "vi-ax5")
    }
}

private extension XCUIElement {
    /// Taps, and taps once more if `screen` has not appeared: right after launch, or while a
    /// sheet is still dismissing, the first tap is sometimes swallowed.
    @MainActor
    func tapOpening(_ screen: XCUIElement, in app: XCUIApplication) {
        // XCUITest calls a button hittable while its centre is under the status bar, the
        // navigation bar or the tab bar, and the tap then lands on the bar. At AX5 a swipe can
        // stop with "Thêm cơn gò bị sót" (126 pt tall) centred at y 60, under the status bar.
        // Drag it, without momentum, until its centre sits between the bars.
        for _ in 0..<3 {
            let top = app.navigationBars.firstMatch.frame.maxY
            let bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.windows.firstMatch.frame.maxY
            let mid = frame.midY
            guard mid < top + 20 || mid > bottom - 20 else { break }
            let from = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(
                forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: (top + bottom) / 2 - mid)),
                withVelocity: .slow, thenHoldForDuration: 0.3
            )
        }
        tap()
        if !screen.waitForExistence(timeout: 5) { tap() }
        XCTAssertTrue(screen.waitForExistence(timeout: 5))
    }

    /// Scrolls the sheet (AX5 pushes Save and Cancel below the fold) until this is hittable, then taps it.
    @MainActor
    func tapOrScroll(_ app: XCUIApplication) {
        app.scrollUntilHittable(self, maxSwipes: 12)
        tap()
    }
}
