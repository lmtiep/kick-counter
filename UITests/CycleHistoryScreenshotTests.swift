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
        let row = app.buttons.matching(identifier: "cycleHistoryRow").element(boundBy: 3)
        app.scrollUntilHittable(row, maxSwipes: 10)
        attachScreenshot(app, "ax5-cycle-history-rows-vi-light")
        row.tap()
        XCTAssertTrue(app.staticTexts["cycleDetailEmpty"].waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-cycle-detail-vi-light")
        app.terminate()
    }

    /// Phase 13 spec §4: the history with its "add a past period" button and
    /// the sheet in vi light/dark and AX5.
    @MainActor
    func testAddPastPeriodScreens() {
        for dark in [false, true] {
            let suffix = UITestVariants.suffix("vi", dark)
            let app = XCUIApplication.launchPinned(language: "vi", dark: dark, seedCycles: "fertile")
            openHistory(app)
            let add = app.buttons["cycleHistoryAddPast"]
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            if !dark { attachScreenshot(app, "cycle-history-with-add-\(suffix)") }
            add.tap()
            XCTAssertTrue(app.buttons["addPastSave"].waitForExistence(timeout: 5))
            attachScreenshot(app, "cycle-add-past-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testAddPastPeriodAtLargestText() {
        let app = XCUIApplication.launchPinned(language: "vi", seedCycles: "fertile", largestText: true)
        openHistory(app)
        let add = app.buttons["cycleHistoryAddPast"]
        app.scrollUntilHittable(add, maxSwipes: 10)
        add.tap()
        let save = app.buttons["addPastSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-cycle-add-past-vi-light")
        app.scrollUntilHittable(save, maxSwipes: 10)
        XCTAssertTrue(save.isHittable)
        attachScreenshot(app, "ax5-cycle-add-past-bottom-vi-light")
        app.terminate()
    }
}
