import XCTest

/// Phase 12 spec §4: Profile's "About" rows (privacy policy, support) and the
/// "Delete all data" dialog, in Vietnamese, light/dark and AX5.
final class AppStoreReadinessScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openProfile(dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(
            language: "vi",
            dark: dark,
            dueDate: UITestDates.dueAtWeek24,
            largestText: largestText
        )
        app.openTab(.profile)
        XCTAssertTrue(app.buttons["profileAppointments"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testInfoLinks() {
        for dark in [false, true] {
            let app = openProfile(dark: dark)
            let support = app.descendants(matching: .any)["profileSupport"]
            app.scrollUntilHittable(support)
            app.scrollUntilHittable(app.buttons["profileDeleteAllData"])
            XCTAssertTrue(support.isHittable)
            attachScreenshot(app, "profile-info-links-vi-\(dark ? "dark" : "light")")
        }
    }

    @MainActor
    func testDeleteDialog() {
        let app = openProfile()
        let delete = app.buttons["profileDeleteAllData"]
        app.scrollUntilHittable(delete)
        delete.tap()
        let alert = app.alerts["Xoá toàn bộ dữ liệu?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.buttons["Xoá"].firstMatch.exists)
        attachScreenshot(app, "profile-delete-dialog-vi-light")
    }

    @MainActor
    func testDeleteAtLargestText() {
        let app = openProfile(largestText: true)
        let delete = app.buttons["profileDeleteAllData"]
        app.scrollUntilHittable(delete, maxSwipes: 12)
        XCTAssertTrue(delete.isHittable)
        attachScreenshot(app, "ax5-profile-delete-vi-light")
        delete.tap()
        let alert = app.alerts["Xoá toàn bộ dữ liệu?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-profile-delete-dialog-vi-light")
    }
}
