import XCTest

/// 1.1 item 4 (spec §6): the ending sheet and the memory page, in vi light,
/// vi dark and vi at AX5, both branches.
final class PregnancyEndingScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let variants: [(dark: Bool, largest: Bool)] = [(false, false), (true, false), (false, true)]

    private static func suffix(dark: Bool, largest: Bool) -> String {
        UITestVariants.suffix("vi", dark) + (largest ? "-ax5" : "")
    }

    @MainActor
    func testEndingSheetScreens() {
        for (dark, largest) in Self.variants {
            let suffix = Self.suffix(dark: dark, largest: largest)
            let app = XCUIApplication.launchPinned(
                language: "vi", dark: dark, dueDate: UITestDates.dueAtWeek24, largestText: largest
            )
            app.openTab(.profile)
            let row = app.buttons["profilePregnancyEnded"]
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            app.scrollUntilHittable(row)
            row.tap()
            XCTAssertTrue(app.buttons["pregnancyEnd-loss"].waitForExistence(timeout: 5))
            attachScreenshot(app, "ending-choose-\(suffix)")

            app.buttons["pregnancyEnd-loss"].tap()
            XCTAssertTrue(app.staticTexts["pregnancyEndOpener"].waitForExistence(timeout: 5))
            attachScreenshot(app, "ending-loss-opener-\(suffix)")
            let next = app.buttons["pregnancyEndContinue"]
            app.scrollUntilHittable(next)
            next.tap()
            let yes = app.buttons["pregnancyEndKeepYes"]
            XCTAssertTrue(yes.waitForExistence(timeout: 5))
            yes.tap()
            XCTAssertTrue(app.textFields["memoryTitleField"].waitForExistence(timeout: 5))
            attachScreenshot(app, "ending-keep-yes-\(suffix)")
            let no = app.buttons["pregnancyEndKeepNo"]
            no.tap()
            XCTAssertTrue(app.switches["pregnancyEndDeleteData"].waitForExistence(timeout: 5))
            attachScreenshot(app, "ending-keep-no-\(suffix)")
            let cancel = app.buttons["pregnancyEndCancel"]
            app.scrollUntilHittable(cancel)
            cancel.tap()

            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
            XCTAssertTrue(app.buttons["pregnancyEnd-birth"].waitForExistence(timeout: 5))
            app.buttons["pregnancyEnd-birth"].tap()
            XCTAssertTrue(app.staticTexts["pregnancyEndOpener"].waitForExistence(timeout: 5))
            attachScreenshot(app, "ending-birth-opener-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testMemoryScreens() {
        for (dark, largest) in Self.variants {
            let suffix = Self.suffix(dark: dark, largest: largest)
            for branch in ["loss", "birth"] {
                let app = XCUIApplication.launchPinned(
                    language: "vi", dark: dark, largestText: largest,
                    extraArguments: ["-seedPregnancyEnded", "\(branch):30"]
                )
                app.openCycleTab(.profile)
                let memories = app.buttons["profileMemories"]
                XCTAssertTrue(memories.waitForExistence(timeout: 10))
                app.scrollUntilHittable(memories)
                memories.tap()
                let row = app.buttons["memoryRow"].firstMatch
                XCTAssertTrue(row.waitForExistence(timeout: 5))
                if branch == "loss" { attachScreenshot(app, "memory-list-\(suffix)") }
                row.tap()
                XCTAssertTrue(app.staticTexts["memoryDetailTitle"].waitForExistence(timeout: 5))
                attachScreenshot(app, "memory-\(branch)-\(suffix)")
                app.swipeUp()
                attachScreenshot(app, "memory-\(branch)-bottom-\(suffix)")
                app.terminate()
            }
        }
    }
}
