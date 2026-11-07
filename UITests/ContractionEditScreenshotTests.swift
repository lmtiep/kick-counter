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
        row.tap()
        let title = app.staticTexts["contractionEditTitle"]
        // Right after launch the list can still be settling and swallow the first tap.
        if !title.waitForExistence(timeout: 5) { row.tap() }
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        attachScreenshot(app, "contraction-edit-sheet-\(suffix)")
        app.buttons["contractionEditCancel"].tapOrScroll(app)

        let add = app.buttons["contractionAddMissed"]
        app.scrollDownUntilHittable(add, maxSwipes: 20)
        app.scrollUntilHittable(add, maxSwipes: 20)
        add.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForExistence(timeout: 5))
        attachScreenshot(app, "contraction-add-missed-sheet-\(suffix)")
        app.buttons["contractionEditCancel"].tapOrScroll(app)

        let water = app.buttons["contractionWaterBroke"]
        app.scrollDownUntilHittable(water, maxSwipes: 20)
        app.scrollUntilHittable(water, maxSwipes: 20)
        water.tap()
        XCTAssertTrue(app.staticTexts["contractionWaterBrokeTitle"].waitForExistence(timeout: 5))
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
    /// Scrolls the sheet (AX5 pushes Save and Cancel below the fold) until this is hittable, then taps it.
    @MainActor
    func tapOrScroll(_ app: XCUIApplication) {
        app.scrollUntilHittable(self, maxSwipes: 12)
        tap()
    }
}
