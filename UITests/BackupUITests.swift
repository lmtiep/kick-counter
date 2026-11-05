import XCTest

/// Phase 15 spec §6: backup and restore by file.
final class BackupUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Export

    /// 1.1: the password step comes first, protection on by default; the share
    /// sheet only after two matching passwords of 6+ characters.
    @MainActor
    func testExportAsksForAPasswordThenShowsTheShareSheet() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let export = app.buttons["profileBackupExport"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        app.scrollUntilHittable(export)
        let footnote = app.staticTexts["profileBackupFootnote"]
        XCTAssertTrue(footnote.exists)
        XCTAssertTrue(footnote.label.contains("health data"), footnote.label)
        XCTAssertTrue(app.buttons["profileBackupImport"].exists)
        XCTAssertTrue(app.buttons["profileBackupMove"].exists)

        export.tap()

        let toggle = app.switches["backupProtectToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "1", "protection is on by default")
        XCTAssertTrue(toggle.label.contains("email or Zalo"), toggle.label)
        let warning = app.descendants(matching: .any)["backupProtectWarning"]
        XCTAssertTrue(warning.label.contains("Luna Mom doesn't keep the password anywhere"), warning.label)
        let create = app.buttons["backupExportCreate"]
        XCTAssertFalse(create.isEnabled)

        // Turning it off is the user's choice.
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["backupProtectOff"].waitForExistence(timeout: 5))
        XCTAssertTrue(create.isEnabled)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(warning.waitForExistence(timeout: 5))

        let password = app.secureTextFields["backupPassword"]
        password.tap()
        password.typeText("12345")
        XCTAssertTrue(app.descendants(matching: .any)["backupPasswordTooShort"].waitForExistence(timeout: 5))
        password.typeText("6")
        let confirmation = app.secureTextFields["backupPasswordConfirm"]
        confirmation.tap()
        confirmation.typeText("123457")
        XCTAssertTrue(app.descendants(matching: .any)["backupPasswordMismatch"].waitForExistence(timeout: 5))
        XCTAssertFalse(create.isEnabled)
        confirmation.typeText(XCUIKeyboardKey.delete.rawValue + "6")
        XCTAssertFalse(app.descendants(matching: .any)["backupPasswordMismatch"].exists)
        XCTAssertTrue(create.isEnabled)

        // Show/hide reveals the same text.
        app.buttons["backupPasswordReveal"].tap()
        XCTAssertEqual(app.textFields["backupPassword"].value as? String, "123456")

        app.scrollUntilHittable(create)
        create.tap()

        // The system share sheet: its presence is enough (spec §6).
        let sheet = app.descendants(matching: .any)["backupShareSheet"]
        let activityList = app.otherElements["ActivityListView"]
        let appeared = XCTWaiter().wait(for: [
            XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in sheet.exists || activityList.exists },
                object: nil
            ),
        ], timeout: 20)
        XCTAssertEqual(appeared, .completed, "the share sheet did not appear")
    }

    // MARK: - Reminder and new iPhone

    @MainActor
    func testAnOldBackupShowsTheReminderCard() {
        let app = XCUIApplication.launchPinned(
            language: "en", dueDate: UITestDates.dueAtWeek24, extraArguments: ["-seedLastBackupDaysAgo", "45"]
        )
        app.openTab(.profile)
        let card = app.descendants(matching: .any)["backupReminderText"]
        let now = app.buttons["backupReminderNow"]
        XCTAssertTrue(now.waitForExistence(timeout: 10))
        app.scrollUntilHittable(now, maxSwipes: 12)
        XCTAssertTrue(card.label.contains("It's been a while since your last backup"), card.label)
        XCTAssertTrue(card.label.contains("Last backup"), card.label)

        now.tap()
        let cancel = app.buttons["backupExportCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))

        let later = app.buttons["backupReminderLater"]
        app.scrollUntilHittable(later)
        later.tap()
        XCTAssertTrue(now.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profileBackupExport"].exists)
    }

    @MainActor
    func testARecentBackupShowsNoReminderCard() {
        let app = XCUIApplication.launchPinned(
            language: "en", dueDate: UITestDates.dueAtWeek24, extraArguments: ["-seedLastBackupDaysAgo", "29"]
        )
        app.openTab(.profile)
        let export = app.buttons["profileBackupExport"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        app.scrollUntilHittable(export, maxSwipes: 12)
        XCTAssertFalse(app.buttons["backupReminderNow"].exists)
    }

    @MainActor
    func testMoveToANewIPhoneGuideStartsTheBackup() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let move = app.buttons["profileBackupMove"]
        XCTAssertTrue(move.waitForExistence(timeout: 10))
        app.scrollUntilHittable(move, maxSwipes: 12)
        move.tap()
        for number in 1...3 {
            XCTAssertTrue(app.descendants(matching: .any)["moveStep\(number)"].waitForExistence(timeout: 10))
        }
        let backUp = app.buttons["moveBackUpNow"]
        backUp.tap()
        XCTAssertTrue(app.switches["backupProtectToggle"].waitForExistence(timeout: 10))
    }

    // MARK: - Restore

    @MainActor
    func testRestoringTheSampleFileReplacesTheData() {
        // Four weeks of sessions on the phone; the file has three.
        let app = BackupFiles.launch(BackupFiles.sample(), extraArguments: ["-seedSessions"], dueDate: UITestDates.dueAtWeek38)
        let summary = app.descendants(matching: .any)["restoreBackupSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.label.contains("Backup from Oct 1, 2026"), summary.label)
        XCTAssertTrue(
            summary.label.contains("3 kick counts, 1 period, 2 logged days, 3 weigh-ins, 2 check-ups"), summary.label
        )
        XCTAssertTrue(summary.label.contains("Pregnancy mode"), summary.label)
        let warning = app.descendants(matching: .any)["restoreBackupWarning"]
        XCTAssertTrue(warning.label.contains("will be replaced"), warning.label)

        app.buttons["restoreBackupConfirm"].tap()

        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 10))
        XCTAssertTrue(toast.label.contains("Data restored"), toast.label)
        // Today, from the file's due date (24w3d on the pinned day) and its check-up.
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        waitForLabel(progress, containing: "24 weeks, 3 days")
        XCTAssertTrue(app.tabBars.buttons.element(boundBy: AppTab.today.rawValue).isSelected)
        let checkUp = app.buttons["nextAppointmentCard"]
        app.scrollUntilHittable(checkUp)
        waitForLabel(checkUp, containing: "Siêu âm hình thái")

        // History holds exactly the file's three sessions.
        app.openHistory()
        let rows = app.descendants(matching: .any).matching(identifier: "sessionRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows.firstMatch.label.contains("10 movements"), rows.firstMatch.label)
        XCTAssertTrue(rows.firstMatch.label.contains("20 min"), rows.firstMatch.label)
    }

    /// 1.1: a protected file asks for its password; a wrong one changes nothing and
    /// asks again; the right one leads to the usual summary and restore.
    @MainActor
    func testRestoringAProtectedFileAsksForThePassword() {
        let app = BackupFiles.launch(BackupFiles.protected(), extraArguments: ["-seedSessions"], dueDate: UITestDates.dueAtWeek38)
        let password = app.secureTextFields["restoreBackupPassword"]
        XCTAssertTrue(password.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["restoreBackupTitle"].label.contains("This file has a password"))
        XCTAssertFalse(app.buttons["restoreBackupConfirm"].exists)
        let unlock = app.buttons["restoreBackupUnlock"]
        XCTAssertFalse(unlock.isEnabled)

        password.tap()
        password.typeText("matkhau124")
        unlock.tap()
        let wrong = app.descendants(matching: .any)["restoreBackupWrongPassword"]
        XCTAssertTrue(wrong.waitForExistence(timeout: 15))
        XCTAssertTrue(wrong.label.contains("Wrong password"), wrong.label)
        XCTAssertFalse(app.buttons["restoreBackupConfirm"].exists)

        password.tap()
        password.typeText("matkhau123")
        unlock.tap()

        let summary = app.descendants(matching: .any)["restoreBackupSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 15))
        XCTAssertTrue(summary.label.contains("3 kick counts, 1 period, 2 logged days, 3 weigh-ins, 2 check-ups"), summary.label)
        app.buttons["restoreBackupConfirm"].tap()
        let toast = app.descendants(matching: .any)["toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 10))
        XCTAssertTrue(toast.label.contains("Data restored"), toast.label)
        app.openHistory()
        let rows = app.descendants(matching: .any).matching(identifier: "sessionRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 3)
    }

    @MainActor
    func testCancellingAProtectedFileKeepsTheData() {
        let app = BackupFiles.launch(BackupFiles.protected(), dueDate: UITestDates.dueAtWeek38)
        let cancel = app.buttons["restoreBackupCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        waitForLabel(progress, containing: "38 weeks")
    }

    @MainActor
    func testCancellingKeepsTheData() {
        let app = BackupFiles.launch(BackupFiles.sample(), extraArguments: ["-seedSessions"], dueDate: UITestDates.dueAtWeek38)
        let cancel = app.buttons["restoreBackupCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        waitForLabel(progress, containing: "38 weeks")
        XCTAssertFalse(app.descendants(matching: .any)["toast"].exists)
    }

    @MainActor
    func testAnUnreadableFileShowsTheErrorAndTouchesNothing() {
        let app = BackupFiles.launch(Data("not a backup".utf8), dueDate: UITestDates.dueAtWeek38)
        let error = app.descendants(matching: .any)["restoreBackupError"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.label.contains("Couldn't read the file."), error.label)
        XCTAssertFalse(app.buttons["restoreBackupConfirm"].exists)
        app.buttons["restoreBackupClose"].tap()
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        waitForLabel(progress, containing: "38 weeks")
    }

    @MainActor
    func testAFileFromANewerVersionAsksToUpdate() {
        let newer = Data(#"{"format":"luna-mom-backup","version":2}"#.utf8)
        let app = BackupFiles.launch(newer, dueDate: UITestDates.dueAtWeek38)
        let error = app.descendants(matching: .any)["restoreBackupError"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.label.contains("newer version of Luna Mom"), error.label)
    }

    /// Final review: a file opened while another sheet is up still shows the restore
    /// sheet, over it. The file opens when the app comes back to the foreground.
    @MainActor
    func testAFileOpenedOverASheetShowsTheRestoreSheet() {
        let app = BackupFiles.launch(
            BackupFiles.sample(), extraArguments: ["-uiTestingRestoreOnReactivate"], dueDate: UITestDates.dueAtWeek38
        )
        app.openTab(.profile)
        let reminder = app.buttons["profileKickReminder"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 10))
        reminder.tap()
        XCTAssertTrue(app.buttons["kickSettingsDone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["restoreBackupConfirm"].exists)

        XCUIDevice.shared.press(.home)
        app.activate()

        let confirm = app.buttons["restoreBackupConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        let summary = app.descendants(matching: .any)["restoreBackupSummary"]
        XCTAssertTrue(summary.label.contains("3 kick counts"), summary.label)
        app.buttons["restoreBackupCancel"].tap()
        XCTAssertTrue(app.buttons["kickSettingsDone"].waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.waitForExistence(timeout: 2))
    }

    // MARK: - Onboarding

    @MainActor
    func testOnboardingOffersRestore() {
        let app = XCUIApplication.launchPinned(language: "en", skipOnboarding: false)
        let restore = app.buttons["onboardingRestore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        app.scrollUntilHittable(restore)
        XCTAssertTrue(restore.isHittable)
        XCTAssertTrue(restore.label.contains("Restore from backup"), restore.label)
    }

    /// A new phone: the file opens above onboarding, and restoring finishes it.
    @MainActor
    func testRestoringDuringOnboardingLandsOnToday() {
        let app = BackupFiles.launch(BackupFiles.sample(), skipOnboarding: false)
        let confirm = app.buttons["restoreBackupConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        confirm.tap()
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        waitForLabel(progress, containing: "24 weeks, 3 days")
        XCTAssertFalse(app.buttons["onboardingNext"].exists)
    }
}

/// The restore flow at launch, as an opened `.lunamom` file (`-uiTestingRestoreFile`).
enum BackupFiles {
    /// `UITests/Fixtures/sample.lunamom`, written by KickCore's encoder (`BackupFixtureTests`).
    static func sample() -> Data { fixture("sample") }

    /// The same file sealed with the password "matkhau123" (`BackupFixtureTests.protectedPassword`).
    static func protected() -> Data { fixture("sample-protected") }

    private static func fixture(_ name: String) -> Data {
        let bundle = Bundle(for: BackupUITests.self)
        guard let url = bundle.url(forResource: name, withExtension: "lunamom"),
              let data = try? Data(contentsOf: url)
        else {
            XCTFail("\(name).lunamom is missing from the UI test bundle")
            return Data()
        }
        return data
    }

    @MainActor
    static func launch(
        _ file: Data,
        language: String = "en",
        dark: Bool = false,
        largestText: Bool = false,
        extraArguments: [String] = [],
        dueDate: String? = nil,
        skipOnboarding: Bool = true
    ) -> XCUIApplication {
        XCUIApplication.launchPinned(
            language: language,
            dark: dark,
            dueDate: dueDate,
            skipOnboarding: skipOnboarding,
            largestText: largestText,
            extraArguments: extraArguments + ["-uiTestingRestoreFile", "LunaMom-2026-10-01.lunamom"],
            environment: ["UITEST_RESTORE_FILE_BASE64": file.base64EncodedString()]
        )
    }
}
