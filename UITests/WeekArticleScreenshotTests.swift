import XCTest

/// Phase 6 spec §6: screenshots of the week article sheet (week 24, pinned clock).
final class WeekArticleScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openWeek24(language: String, dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        let fetus = app.buttons["fetusHeroButton"]
        XCTAssertTrue(fetus.waitForExistence(timeout: 10))
        fetus.tap()
        XCTAssertTrue(app.buttons["weekSheetHandle"].waitForExistence(timeout: 5))
        return app
    }

    /// Peek and expanded × Bé and Mẹ, vi light; then week 25 from its chip.
    @MainActor
    func testVietnameseLightPeekAndExpanded() {
        let app = openWeek24(language: "vi")
        let handle = app.buttons["weekSheetHandle"]
        attachScreenshot(app, "week-article-peek-baby-vi-light")
        handle.tap()
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "week-article-expanded-baby-vi-light")
        app.swipeUp()
        attachScreenshot(app, "week-article-expanded-baby-vi-light-scrolled")
        app.buttons["weekTab-mom"].tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        XCTAssertTrue(warnings.waitForExistence(timeout: 5))
        attachScreenshot(app, "week-article-expanded-mom-vi-light")
        app.scrollUntilHittable(warnings)
        attachScreenshot(app, "week-article-warnings-vi-light")
        handle.tap()
        waitForLabel(handle, containing: "Mở rộng bài viết")
        attachScreenshot(app, "week-article-peek-mom-vi-light")
        app.buttons["weekChip-25"].tap()
        waitForLabel(app.staticTexts["weekDetailTitle"], containing: "Tuần 25")
        attachScreenshot(app, "week-article-25-vi-light")
    }

    @MainActor
    func testEnglishDark() {
        let app = openWeek24(language: "en", dark: true)
        let handle = app.buttons["weekSheetHandle"]
        attachScreenshot(app, "week-article-peek-baby-en-dark")
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        attachScreenshot(app, "week-article-expanded-baby-en-dark")
        app.buttons["weekTab-mom"].tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        XCTAssertTrue(warnings.waitForExistence(timeout: 5))
        attachScreenshot(app, "week-article-expanded-mom-en-dark")
        app.scrollUntilHittable(warnings)
        attachScreenshot(app, "week-article-warnings-en-dark")
    }

    /// Phase 11: the week's fruit illustration replaces the emoji (weeks 12, 24, 38; vi light and dark).
    @MainActor
    func testFruitIllustrations() {
        let weeks = [(12, UITestDates.dueAtWeek12), (24, UITestDates.dueAtWeek24), (38, UITestDates.dueAtWeek38)]
        for (week, dueDate) in weeks {
            for dark in [false, true] {
                let app = XCUIApplication.launchPinned(language: "vi", dark: dark, dueDate: dueDate)
                let fetus = app.buttons["fetusHeroButton"]
                XCTAssertTrue(fetus.waitForExistence(timeout: 10))
                fetus.tap()
                let handle = app.buttons["weekSheetHandle"]
                XCTAssertTrue(handle.waitForExistence(timeout: 5))
                handle.tap()
                waitForLabel(handle, containing: "Thu gọn bài viết")
                waitForLabel(app.staticTexts["weekDetailTitle"], containing: "Tuần \(week)")
                attachScreenshot(app, "week-article-fruit-\(week)-vi-\(dark ? "dark" : "light")")
                app.terminate()
            }
        }
    }

    /// AX5 opens expanded; nothing is cut.
    @MainActor
    func testLargestText() {
        let app = openWeek24(language: "vi", largestText: true)
        let handle = app.buttons["weekSheetHandle"]
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "week-article-vi-ax5")
        app.swipeUp()
        attachScreenshot(app, "week-article-vi-ax5-scrolled")
        app.buttons["weekTab-mom"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(app, "week-article-mom-vi-ax5")
    }

    /// Opened from the symptoms safety card: expanded, Mẹ, at the warnings.
    @MainActor
    func testFromTheSafetyCard() {
        let app = XCUIApplication.launchPinned(language: "vi", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        app.scrollUntilHittable(contractions)
        contractions.tap()
        let action = app.buttons["symptomSafetyAction"]
        app.scrollUntilHittable(action)
        action.tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        let inView = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: warnings)
        XCTAssertEqual(XCTWaiter().wait(for: [inView], timeout: 5), .completed)
        attachScreenshot(app, "week-article-from-safety-vi-light")
    }
}
