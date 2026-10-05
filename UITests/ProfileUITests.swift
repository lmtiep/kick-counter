import XCTest

/// Spec §4.8 and §6: the Profile tab.
final class ProfileUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Spec §6: ending the pregnancy → the three trying-to-conceive tabs; the dates are kept.
    @MainActor
    func testEndingThePregnancyReturnsToCycleTrackingAndKeepsTheDates() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let end = app.buttons["profileEndPregnancy"]
        XCTAssertTrue(end.waitForExistence(timeout: 10))
        end.tap()
        let confirm = app.buttons["endPregnancyConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected)
        let switchBack = app.buttons["profileSwitchToPregnant"]
        XCTAssertTrue(switchBack.waitForExistence(timeout: 5))

        // Back to pregnant: no period logged, so the sheet starts from the kept due date.
        switchBack.tap()
        let save = app.buttons["imPregnantSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        app.openTab(.today)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("24 weeks, 3 days"), progress.label)
    }

    @MainActor
    func testNotNowKeepsPregnancyMode() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let end = app.buttons["profileEndPregnancy"]
        XCTAssertTrue(end.waitForExistence(timeout: 10))
        end.tap()
        let cancel = app.buttons["endPregnancyCancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Kicks"].exists)
    }

    /// Spec §4.8: replaying the introduction opens onboarding without deleting anything.
    @MainActor
    func testReplayingTheIntroductionKeepsTheData() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let replay = app.buttons["profileReplayOnboarding"]
        XCTAssertTrue(replay.waitForExistence(timeout: 10))
        app.scrollUntilHittable(replay)
        replay.tap()
        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        app.buttons["onboardingSkipDate"].tap()

        app.openTab(.today)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("24 weeks, 3 days"), progress.label)
    }

    @MainActor
    func testKickReminderRowOpensKickSettings() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let row = app.buttons["profileKickReminder"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Off"), row.label)
        app.scrollUntilHittable(row)
        row.tap()
        XCTAssertTrue(app.switches["kickSettingsHapticsToggle"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFontLicenseIsShown() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let row = app.buttons["profileFontLicense"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        row.tap()
        let license = app.staticTexts["fontLicenseText"]
        XCTAssertTrue(license.waitForExistence(timeout: 5))
        XCTAssertTrue(license.label.contains("SIL OPEN FONT LICENSE"), String(license.label.prefix(200)))
    }

    @MainActor
    func testProfileScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let pregnant = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            pregnant.openTab(.profile)
            XCTAssertTrue(pregnant.buttons["profileEndPregnancy"].waitForExistence(timeout: 10))
            attachScreenshot(pregnant, "profile-pregnant-\(suffix)")
            if !dark {
                pregnant.swipeUp()
                attachScreenshot(pregnant, "profile-pregnant-bottom-\(suffix)")
                pregnant.swipeDown()
                pregnant.buttons["profileEndPregnancy"].tap()
                XCTAssertTrue(pregnant.buttons["endPregnancyConfirm"].waitForExistence(timeout: 5))
                attachScreenshot(pregnant, "end-pregnancy-\(suffix)")
            }
            pregnant.terminate()

            let cycle = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            cycle.openCycleTab(.profile)
            XCTAssertTrue(cycle.descendants(matching: .any)["settingsCycleLength"].waitForExistence(timeout: 10))
            attachScreenshot(cycle, "profile-ttc-\(suffix)")
            cycle.terminate()
        }
    }
}
