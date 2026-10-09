import XCTest

/// Phase 15 spec §6: backup and restore by file.
final class BackupUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Export

    @MainActor
    func testExportShowsTheShareSheet() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let export = app.buttons["profileBackupExport"]
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        app.scrollUntilHittable(export)
        let footnote = app.staticTexts["profileBackupFootnote"]
        XCTAssertTrue(footnote.exists)
        XCTAssertTrue(footnote.label.contains("health data"), footnote.label)
        XCTAssertTrue(app.buttons["profileBackupImport"].exists)

        export.tap()

        // The system share sheet: its presence is enough (spec §6).
        let sheet = app.descendants(matching: .any)["backupShareSheet"]
        let activityList = app.otherElements["ActivityListView"]
        let appeared = XCTWaiter().wait(for: [
            XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in sheet.exists || activityList.exists },
                object: nil
            ),
        ], timeout: 15)
        XCTAssertEqual(appeared, .completed, "the share sheet did not appear")
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
        XCTAssertTrue(restore.label.contains("Restore from a backup"), restore.label)
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
    static func sample() -> Data {
        let bundle = Bundle(for: BackupUITests.self)
        guard let url = bundle.url(forResource: "sample", withExtension: "lunamom"),
              let data = try? Data(contentsOf: url)
        else {
            XCTFail("sample.lunamom is missing from the UI test bundle")
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
