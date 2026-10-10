import XCTest

/// Phase 19 spec §3: the calendar's period edit mode in vi light and dark, and AX5.
final class CalendarPeriodEditScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Calendar tab → "Sửa kỳ kinh" → September (Sep 20–24 ticked).
    @MainActor
    private func openEditInSeptember(_ app: XCUIApplication, attachingButtonAs name: String? = nil) {
        app.openCycleTab(.calendar)
        XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
        if let name { attachScreenshot(app, name) }
        CalendarPeriodEditUITests.startEditing(app)
        let previous = app.buttons["calendarPrevious"]
        let september = CalendarPeriodEditUITests.day(app, "20260915")
        for _ in 0..<3 where !september.exists {
            previous.tap()
            _ = september.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(september.exists)
    }

    @MainActor
    func testEditScreens() {
        for dark in [false, true] {
            let suffix = UITestVariants.suffix("vi", dark)
            let app = XCUIApplication.launchPinned(language: "vi", dark: dark, seedCycles: "fertile")
            openEditInSeptember(app, attachingButtonAs: "calendar-edit-button-\(suffix)")
            attachScreenshot(app, "calendar-period-edit-\(suffix)")
            // Sep 25–30 on top of Sep 20–24: 11 days, the inline error.
            for day in 25...30 {
                let cell = CalendarPeriodEditUITests.day(app, "202609\(day)")
                app.scrollUntilHittable(cell)
                cell.tap()
            }
            let save = app.buttons["periodEditSave"]
            app.scrollDownUntilHittable(save)
            save.tap()
            XCTAssertTrue(app.descendants(matching: .any)["periodEditError"].waitForExistence(timeout: 5))
            attachScreenshot(app, "calendar-period-edit-error-\(suffix)")
            app.buttons["periodEditCancel"].tap()
            XCTAssertTrue(app.staticTexts["Bỏ các thay đổi?"].waitForExistence(timeout: 5))
            attachScreenshot(app, "calendar-period-edit-discard-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testEditAtLargestText() {
        let app = XCUIApplication.launchPinned(language: "vi", seedCycles: "fertile", largestText: true)
        openEditInSeptember(app)
        attachScreenshot(app, "ax5-calendar-period-edit-vi-light")
        let day = CalendarPeriodEditUITests.day(app, "20260924")
        app.scrollUntilHittable(day)
        attachScreenshot(app, "ax5-calendar-period-edit-grid-vi-light")
        let hint = app.descendants(matching: .any)["periodEditHint"]
        app.scrollUntilHittable(hint)
        attachScreenshot(app, "ax5-calendar-period-edit-hint-vi-light")
        app.terminate()
    }
}
