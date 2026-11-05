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

    /// 1.1: the password step, the reminder card, the new-iPhone guide and the
    /// password prompt of a protected file, in vi light/dark.
    @MainActor
    func testProtectedBackupScreens() {
        for dark in [false, true] {
            let suffix = UITestVariants.suffix("vi", dark)
            let profile = XCUIApplication.launchPinned(
                language: "vi", dark: dark, dueDate: UITestDates.dueAtWeek24, extraArguments: ["-seedLastBackupDaysAgo", "45"]
            )
            profile.openTab(.profile)
            let reminder = profile.buttons["backupReminderNow"]
            XCTAssertTrue(reminder.waitForExistence(timeout: 10))
            profile.scrollUntilHittable(reminder, maxSwipes: 12)
            let text = profile.descendants(matching: .any)["backupReminderText"]
            XCTAssertTrue(text.label.contains("Đã lâu chưa sao lưu"), text.label)
            attachScreenshot(profile, "backup-reminder-\(suffix)")

            reminder.tap()
            let password = profile.secureTextFields["backupPassword"]
            XCTAssertTrue(password.waitForExistence(timeout: 10))
            password.tap()
            password.typeText("12345")
            XCTAssertTrue(profile.descendants(matching: .any)["backupPasswordTooShort"].waitForExistence(timeout: 5))
            attachScreenshot(profile, "backup-password-\(suffix)")
            profile.buttons["backupExportCancel"].tap()

            let move = profile.buttons["profileBackupMove"]
            XCTAssertTrue(move.waitForExistence(timeout: 10))
            profile.scrollUntilHittable(move, maxSwipes: 12)
            move.tap()
            XCTAssertTrue(profile.descendants(matching: .any)["moveStep3"].waitForExistence(timeout: 10))
            attachScreenshot(profile, "backup-move-\(suffix)")
            profile.terminate()

            let locked = BackupFiles.launch(BackupFiles.protected(), language: "vi", dark: dark, dueDate: UITestDates.dueAtWeek24)
            let field = locked.secureTextFields["restoreBackupPassword"]
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.tap()
            field.typeText("saimatkhau")
            locked.buttons["restoreBackupUnlock"].tap()
            let wrong = locked.descendants(matching: .any)["restoreBackupWrongPassword"]
            XCTAssertTrue(wrong.waitForExistence(timeout: 15))
            XCTAssertTrue(wrong.label.contains("Mật khẩu không đúng"), wrong.label)
            attachScreenshot(locked, "backup-unlock-\(suffix)")
            locked.terminate()
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
        restore.terminate()

        // 1.1 at AX5: the password step and the password prompt stay usable.
        let export = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek24, largestText: true, extraArguments: ["-seedLastBackupDaysAgo", "45"]
        )
        export.openTab(.profile)
        let reminder = export.buttons["backupReminderNow"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 10))
        export.scrollUntilHittable(reminder, maxSwipes: 16)
        attachScreenshot(export, "backup-reminder-vi-ax5")
        reminder.tap()
        XCTAssertTrue(export.switches["backupProtectToggle"].waitForExistence(timeout: 10))
        attachScreenshot(export, "backup-password-vi-ax5")
        let create = export.buttons["backupExportCreate"]
        export.scrollUntilHittable(create, maxSwipes: 10)
        XCTAssertTrue(create.isHittable)
        attachScreenshot(export, "backup-password-vi-ax5-bottom")
        export.terminate()

        let locked = BackupFiles.launch(BackupFiles.protected(), language: "vi", largestText: true, dueDate: UITestDates.dueAtWeek24)
        let unlock = locked.buttons["restoreBackupUnlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 10))
        locked.scrollUntilHittable(unlock)
        XCTAssertTrue(unlock.isHittable)
        attachScreenshot(locked, "backup-unlock-vi-ax5")
    }
}
