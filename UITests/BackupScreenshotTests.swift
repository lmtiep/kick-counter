import XCTest

/// Phase 15 spec §6: Profile's "Dữ liệu" section and the restore sheet, in vi
/// light/dark and at AX5.
final class BackupScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openDataSection(_ app: XCUIApplication) {
        app.openTab(.profile)
        let restore = app.buttons["profileBackupImport"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        app.scrollUntilHittable(restore, maxSwipes: 12)
        XCTAssertTrue(app.buttons["profileBackupExport"].exists)
    }

    @MainActor
    func testBackupScreens() {
        for dark in [false, true] {
            let suffix = UITestVariants.suffix("vi", dark)
            let profile = XCUIApplication.launchPinned(language: "vi", dark: dark, dueDate: UITestDates.dueAtWeek24)
            openDataSection(profile)
            attachScreenshot(profile, "backup-profile-\(suffix)")
            profile.terminate()

            // A kick count running on this phone adds its note to the warning.
            let restore = BackupFiles.launch(
                BackupFiles.sample(), language: "vi", dark: dark,
                extraArguments: ["-seedActiveSession"], dueDate: UITestDates.dueAtWeek24
            )
            XCTAssertTrue(restore.buttons["restoreBackupConfirm"].waitForExistence(timeout: 10))
            let warning = restore.descendants(matching: .any)["restoreBackupWarning"]
            XCTAssertTrue(warning.label.contains("Lượt đếm đang chạy sẽ bị dừng."), warning.label)
            attachScreenshot(restore, "backup-restore-\(suffix)")
            restore.terminate()

            let error = BackupFiles.launch(Data(#"{"format":"other"}"#.utf8), language: "vi", dark: dark)
            XCTAssertTrue(error.descendants(matching: .any)["restoreBackupError"].waitForExistence(timeout: 10))
            attachScreenshot(error, "backup-error-\(suffix)")
            error.terminate()
        }
    }

    @MainActor
    func testBackupScreensAtLargestText() {
        let profile = XCUIApplication.launchPinned(language: "vi", dueDate: UITestDates.dueAtWeek24, largestText: true)
        openDataSection(profile)
        attachScreenshot(profile, "backup-profile-vi-ax5")
        profile.terminate()

        let restore = BackupFiles.launch(BackupFiles.sample(), language: "vi", largestText: true, dueDate: UITestDates.dueAtWeek24)
        let confirm = restore.buttons["restoreBackupConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        attachScreenshot(restore, "backup-restore-vi-ax5")
        restore.scrollUntilHittable(confirm)
        XCTAssertTrue(confirm.isHittable)
        attachScreenshot(restore, "backup-restore-vi-ax5-bottom")
    }
}
