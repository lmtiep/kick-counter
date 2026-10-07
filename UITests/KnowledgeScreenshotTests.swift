import XCTest

/// Phase 7 spec §5: screenshots of the knowledge card, library and reading
/// screen (week 24, pinned clock). The reading screen shows safe-exercise.
final class KnowledgeScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAtWeek24(language: String, dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        XCTAssertTrue(app.buttons["fetusHeroButton"].waitForExistence(timeout: 10))
        app.scrollUntilHittable(app.buttons["knowledgeSeeMore"], maxSwipes: largestText ? 20 : 8)
        return app
    }

    /// Today → "See more" → the library on trimester 2.
    @MainActor
    private func openLibrary(_ app: XCUIApplication) {
        app.buttons["knowledgeSeeMore"].tap()
        XCTAssertTrue(app.buttons["knowledgeTrimester-2"].waitForExistence(timeout: 5))
    }

    /// Library → safe-exercise.
    @MainActor
    private func openSafeExercise(_ app: XCUIApplication) -> XCUIElement {
        let row = app.buttons["knowledgeArticle-safe-exercise"]
        app.scrollUntilHittable(row)
        row.tap()
        let handle = app.buttons["knowledgeSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        return handle
    }

    @MainActor
    func testVietnameseLight() {
        let app = launchAtWeek24(language: "vi")
        attachScreenshot(app, "knowledge-card-vi-light")
        openLibrary(app)
        attachScreenshot(app, "knowledge-library-vi-light")
        let handle = openSafeExercise(app)
        attachScreenshot(app, "knowledge-reading-peek-vi-light")
        handle.tap()
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "knowledge-reading-expanded-vi-light")
        app.swipeUp()
        app.swipeUp()
        attachScreenshot(app, "knowledge-reading-expanded-vi-light-scrolled")
    }

    @MainActor
    func testEnglishDark() {
        let app = launchAtWeek24(language: "en", dark: true)
        attachScreenshot(app, "knowledge-card-en-dark")
        openLibrary(app)
        attachScreenshot(app, "knowledge-library-en-dark")
        let handle = openSafeExercise(app)
        attachScreenshot(app, "knowledge-reading-peek-en-dark")
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        attachScreenshot(app, "knowledge-reading-expanded-en-dark")
    }

    /// AX5: the library wraps, and the reading screen opens expanded.
    @MainActor
    func testLargestText() {
        let app = launchAtWeek24(language: "vi", largestText: true)
        attachScreenshot(app, "knowledge-card-vi-ax5")
        openLibrary(app)
        attachScreenshot(app, "knowledge-library-vi-ax5")
        let handle = openSafeExercise(app)
        waitForLabel(handle, containing: "Thu gọn bài viết")
        attachScreenshot(app, "knowledge-reading-vi-ax5")
    }
}
