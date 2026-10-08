import XCTest

/// Phase 10 spec §5: the history and a cycle's detail in vi/en, light/dark and AX5.
final class CycleHistoryScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openHistory(_ app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        let link = app.buttons["cycleHistoryLink"]
        app.scrollUntilHittable(link, maxSwipes: 12)
        link.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cycleHistorySummary"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHistoryScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            let link = app.buttons["cycleHistoryLink"]
            XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
            app.scrollUntilHittable(link)
            attachScreenshot(app, "cycle-history-link-\(suffix)")
            openHistory(app)
            attachScreenshot(app, "cycle-history-\(suffix)")
            app.buttons.matching(identifier: "cycleHistoryRow").firstMatch.tap()
            XCTAssertTrue(app.buttons.matching(identifier: "cycleDetailDay").firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "cycle-detail-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testHistoryAtLargestText() {
        let app = XCUIApplication.launchPinned(language: "vi", seedCycles: "fertile", largestText: true)
        openHistory(app)
        attachScreenshot(app, "ax5-cycle-history-vi-light")
        let row = app.buttons.matching(identifier: "cycleHistoryRow").element(boundBy: 1)
        app.scrollUntilHittable(row, maxSwipes: 10)
        attachScreenshot(app, "ax5-cycle-history-rows-vi-light")
        row.tap()
        XCTAssertTrue(app.staticTexts["cycleDetailEmpty"].waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-cycle-detail-vi-light")
        app.terminate()
    }
}
