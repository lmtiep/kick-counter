import XCTest

/// Spec §4.8 and §6: the Profile tab.
final class ProfileUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 1.1 item 4: after "My pregnancy has ended" (the cycle tabs, on Today),
    /// "I'm pregnant" from Profile goes back to the pregnancy tabs.
    @MainActor
    func testPregnantAgainAfterTheEnding() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let end = app.buttons["profilePregnancyEnded"]
        XCTAssertTrue(end.waitForExistence(timeout: 10))
        end.tap()
        app.buttons["pregnancyEnd-birth"].tap()
        app.buttons["pregnancyEndContinue"].tap()
        app.buttons["pregnancyEndKeepNo"].tap()
        app.buttons["pregnancyEndConfirm"].tap()
        app.closeBirthCelebration()

        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
        app.openCycleTab(.profile)
        let switchBack = app.buttons["profileSwitchToPregnant"]
        XCTAssertTrue(switchBack.waitForExistence(timeout: 5))
        switchBack.tap()
        let save = app.buttons["imPregnantSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.tabBars.buttons["Kicks"].waitForExistence(timeout: 5))
        app.openTab(.today)
        XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 5))
    }

    /// Phase 5 spec §3.5: pre-pregnancy weight and height are edited from Profile.
    @MainActor
    func testMaternalRowEditsWeightAndHeight() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let row = app.buttons["profileMaternal"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("Not set"), row.label)
        app.scrollUntilHittable(row)
        row.tap()
        let weight = app.textFields["weightSetupPreWeight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        weight.typeText("52")
        let height = app.textFields["weightSetupHeight"]
        // Near the right edge: the cursor lands after any text already there.
        height.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        height.typeText("150")
        app.buttons["keyboardDone"].tap()
        app.buttons["weightSetupSave"].tap()
        waitForLabel(row, containing: "52.0 kg · 150 cm")

        // A height outside 120–220 cm is refused and the sheet stays open.
        row.tap()
        XCTAssertTrue(height.waitForExistence(timeout: 5))
        height.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        height.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5) + "99")
        app.buttons["keyboardDone"].tap()
        app.buttons["weightSetupSave"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupHeightError"].waitForExistence(timeout: 5))
        app.buttons["maternalCancel"].tap()
        XCTAssertTrue(row.label.contains("150 cm"), row.label)
    }

    @MainActor
    func testNotNowKeepsPregnancyMode() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let end = app.buttons["profilePregnancyEnded"]
        XCTAssertTrue(end.waitForExistence(timeout: 10))
        end.tap()
        let cancel = app.buttons["pregnancyEndCancel"]
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
        app.skipThroughReplayedOnboarding()

        app.openTab(.today)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("24 weeks, 3 days"), progress.label)
    }

    /// Replaying from trying-to-conceive mode and skipping changes nothing:
    /// same mode (three cycle tabs), same cycle day, no period logged.
    @MainActor
    func testReplayingTheIntroductionInCycleModeKeepsModeAndCycle() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let statusBefore = status.label

        app.openCycleTab(.profile)
        let replay = app.buttons["profileReplayOnboarding"]
        XCTAssertTrue(replay.waitForExistence(timeout: 10))
        app.scrollUntilHittable(replay)
        replay.tap()
        app.skipThroughReplayedOnboarding()

        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Kicks"].exists)
        app.openCycleTab(.today)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, statusBefore)
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
            XCTAssertTrue(pregnant.buttons["profilePregnancyEnded"].waitForExistence(timeout: 10))
            attachScreenshot(pregnant, "profile-pregnant-\(suffix)")
            if !dark {
                pregnant.swipeUp()
                attachScreenshot(pregnant, "profile-pregnant-bottom-\(suffix)")
                pregnant.swipeDown()
                pregnant.buttons["profilePregnancyEnded"].tap()
                XCTAssertTrue(pregnant.buttons["pregnancyEnd-birth"].waitForExistence(timeout: 5))
                attachScreenshot(pregnant, "end-pregnancy-\(suffix)")
            }
            if language == "vi" {
                if !dark { pregnant.buttons["pregnancyEndCancel"].tap() }
                let fontLicense = pregnant.buttons["profileFontLicense"]
                XCTAssertTrue(fontLicense.waitForExistence(timeout: 5))
                pregnant.scrollUntilHittable(fontLicense)
                fontLicense.tap()
                XCTAssertTrue(pregnant.staticTexts["fontLicenseText"].waitForExistence(timeout: 5))
                attachScreenshot(pregnant, "font-license-\(suffix)")
            }
            pregnant.terminate()

            let cycle = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            cycle.openCycleTab(.profile)
            XCTAssertTrue(cycle.descendants(matching: .any)["settingsCycleLength"].waitForExistence(timeout: 10))
            attachScreenshot(cycle, "profile-ttc-\(suffix)")
            cycle.terminate()
        }
    }

    /// "Your privacy" opens from About and shows the four promises and the policy link.
    @MainActor
    func testPrivacyPromiseScreenShowsTheFourPoints() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let row = app.descendants(matching: .any)["profilePrivacyPromise"]
        XCTAssertTrue(app.buttons["profileAppointments"].waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        row.tap()
        for id in ["privacyFree", "privacyNoAds", "privacyNoAccount", "privacyOnDevice"] {
            XCTAssertTrue(app.staticTexts[id].waitForExistence(timeout: 5), id)
        }
        XCTAssertTrue(app.descendants(matching: .any)["privacyPolicyLink"].exists)
    }

    @MainActor
    func testPrivacyPromiseScreens() {
        // Few launches: this shard is close to the 60-minute CI limit.
        let variants = [("vi", false, false), ("vi", true, false), ("en", false, true)]
        for (language, dark, largest) in variants {
            let suffix = UITestVariants.suffix(language, dark) + (largest ? "-ax5" : "")
            let app = XCUIApplication.launchPinned(
                language: language, dark: dark, dueDate: UITestDates.dueAtWeek24, largestText: largest)
            app.openTab(.profile)
            let row = app.descendants(matching: .any)["profilePrivacyPromise"]
            XCTAssertTrue(app.buttons["profileAppointments"].waitForExistence(timeout: 10))
            app.scrollUntilHittable(row)
            row.tap()
            XCTAssertTrue(app.staticTexts["privacyOnDevice"].waitForExistence(timeout: 5))
            attachScreenshot(app, "profile-privacy-\(suffix)")
            app.terminate()
        }
    }
}
