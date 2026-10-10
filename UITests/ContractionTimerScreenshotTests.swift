import XCTest

/// Phase 20 spec §5: the contraction timer resting and running, both alert
/// cards, the history and Today's five shortcuts, in vi light and dark, plus AX5.
final class ContractionTimerScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(
        dark: Bool = false,
        largestText: Bool = false,
        dueDate: String = UITestDates.dueAtWeek38,
        seed: String? = nil
    ) -> XCUIApplication {
        XCUIApplication.launchPinned(
            language: "vi", dark: dark, dueDate: dueDate, largestText: largestText,
            extraArguments: seed.map { ["-seedContractions", $0] } ?? []
        )
    }

    @MainActor
    func testContractionScreens() {
        for dark in [false, true] {
            let suffix = UITestVariants.suffix("vi", dark)

            let today = launch(dark: dark, dueDate: UITestDates.dueAtWeek30)
            let shortcut = today.buttons["shortcutContractions"]
            XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
            today.scrollUntilHittable(shortcut)
            attachScreenshot(today, "contraction-today-shortcut-\(suffix)")
            shortcut.tap()
            let toggle = today.buttons["contractionToggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            attachScreenshot(today, "contraction-resting-\(suffix)")
            toggle.tap()
            waitForLabel(toggle, containing: "Hết cơn gò")
            attachScreenshot(today, "contraction-running-\(suffix)")
            today.terminate()

            let fiveOneOne = launch(dark: dark, seed: "511")
            fiveOneOne.openContractionTimer()
            XCTAssertTrue(fiveOneOne.descendants(matching: .any)["contractionFiveOneOneCard"].waitForExistence(timeout: 5))
            attachScreenshot(fiveOneOne, "contraction-511-\(suffix)")
            let history = fiveOneOne.buttons["contractionHistory"]
            fiveOneOne.scrollUntilHittable(history, maxSwipes: 10)
            attachScreenshot(fiveOneOne, "contraction-511-list-\(suffix)")
            history.tap()
            XCTAssertTrue(fiveOneOne.descendants(matching: .any)["contractionEpisodeRow"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(fiveOneOne, "contraction-history-\(suffix)")
            fiveOneOne.terminate()

            let preterm = launch(dark: dark, dueDate: UITestDates.dueAtWeek33, seed: "preterm")
            preterm.openContractionTimer()
            XCTAssertTrue(preterm.descendants(matching: .any)["contractionPretermCard"].waitForExistence(timeout: 5))
            attachScreenshot(preterm, "contraction-preterm-\(suffix)")
            preterm.terminate()
        }
    }

    @MainActor
    func testContractionScreensAtLargestText() {
        let today = launch(largestText: true, dueDate: UITestDates.dueAtWeek30)
        let shortcut = today.buttons["shortcutContractions"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        today.scrollUntilHittable(shortcut)
        XCTAssertTrue(shortcut.isHittable)
        attachScreenshot(today, "contraction-today-shortcut-vi-ax5")
        today.terminate()

        let app = launch(largestText: true, seed: "511")
        app.openContractionTimer()
        XCTAssertTrue(app.descendants(matching: .any)["contractionFiveOneOneCard"].waitForExistence(timeout: 5))
        attachScreenshot(app, "contraction-511-vi-ax5")
        let toggle = app.buttons["contractionToggle"]
        app.scrollUntilHittable(toggle)
        XCTAssertTrue(toggle.isHittable)
        toggle.tap()
        waitForLabel(toggle, containing: "Hết cơn gò")
        attachScreenshot(app, "contraction-running-vi-ax5")
        let endEpisode = app.buttons["contractionEndEpisode"]
        app.scrollUntilHittable(endEpisode)
        XCTAssertTrue(endEpisode.isHittable)
        attachScreenshot(app, "contraction-controls-vi-ax5")
        let delete = app.buttons["contractionDelete"].firstMatch
        app.scrollUntilHittable(delete)
        XCTAssertTrue(delete.isHittable)
        attachScreenshot(app, "contraction-list-vi-ax5")
        let history = app.buttons["contractionHistory"]
        app.scrollUntilHittable(history, maxSwipes: 20)
        XCTAssertTrue(history.isHittable)
        attachScreenshot(app, "contraction-bottom-vi-ax5")
        history.tap()
        XCTAssertTrue(app.descendants(matching: .any)["contractionEpisodeRow"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(app, "contraction-history-vi-ax5")
    }
}
