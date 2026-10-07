import XCTest

/// Phase 9 spec §4.3 and §5: Profile's goal picker (track my cycle · trying to
/// conceive · pregnant), the contraception row and the LH/BBT override.
final class ProfileGoalUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Cycle mode's Profile, scrolled to the cycle card's tracking rows when they exist.
    @MainActor
    private func openCycleProfile(_ app: XCUIApplication) {
        app.openCycleTab(.profile)
        XCTAssertTrue(app.segmentedControls["settingsModePicker"].waitForExistence(timeout: 10))
    }

    /// Choosing "Track cycle" in Profile changes Today at once; choosing the pill
    /// then hides the fertile window.
    @MainActor
    func testSwitchingTheGoalInProfileUpdatesToday() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("High chance of conceiving"), status.label)

        openCycleProfile(app)
        let conceiving = app.segmentedControls.buttons["Trying to conceive"]
        XCTAssertTrue(conceiving.isSelected)
        XCTAssertFalse(app.buttons["profileContraception"].exists)
        app.segmentedControls.buttons["Track cycle"].tap()
        let contraception = app.buttons["profileContraception"]
        XCTAssertTrue(contraception.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected) // Profile stays open

        app.openCycleTab(.today)
        waitForLabel(status, containing: "High chance of pregnancy")

        openCycleProfile(app)
        app.scrollUntilHittable(contraception)
        contraception.tap()
        let pill = app.buttons["The pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        waitForLabel(contraception, containing: "The pill")

        app.openCycleTab(.today)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        waitForLabel(status, containing: "Expected bleed")
        XCTAssertFalse(app.descendants(matching: .any)["cycleFertileCard"].exists)
    }

    /// The override brings the LH test and temperature back to the day log.
    @MainActor
    func testTheOverrideShowsTheTestsWhileTracking() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile", cycleGoal: "tracking")
        openCycleProfile(app)
        let toggle = app.switches["profileShowFertilityTests"]
        app.scrollUntilHittable(toggle)
        XCTAssertTrue(toggle.exists)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")

        app.openCycleTab(.today)
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        app.scrollUntilHittable(logToday)
        logToday.tap()
        XCTAssertTrue(app.segmentedControls["dayLogLHPicker"].waitForExistence(timeout: 5))
    }

    /// From pregnancy, "Track cycle" switches mode at once (three cycle tabs,
    /// tracking rows) and, like "Trying to conceive", stops partner sharing.
    @MainActor
    func testTrackCycleFromPregnancyStopsSharing() {
        let app = XCUIApplication.launchPinned(
            language: "en",
            dueDate: UITestDates.dueAtWeek24,
            extraArguments: ["-uiTestingSharing", "joined"]
        )
        app.openTab(.profile)
        let row = app.buttons["partnerShareRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        waitForLabel(row, containing: "Baby's dad is following")

        for _ in 0..<3 { app.swipeDown() }
        let track = app.segmentedControls.buttons["Track cycle"]
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        track.tap()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profileContraception"].waitForExistence(timeout: 5))

        // Back to pregnancy: the share was stopped on the way out.
        app.segmentedControls.buttons["Pregnant"].tap()
        let save = app.buttons["imPregnantSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.tabBars.buttons["Kicks"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        waitForLabel(row, containing: "Invite baby's dad to follow the journey", timeout: 10)
    }

    @MainActor
    func testProfileGoalScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(
                language: language, dark: dark, seedCycles: "fertile", cycleGoal: "tracking", contraception: "copperIUD"
            )
            openCycleProfile(app)
            attachScreenshot(app, "profile-tracking-\(suffix)")
            let toggle = app.switches["profileShowFertilityTests"]
            app.scrollUntilHittable(toggle)
            attachScreenshot(app, "profile-tracking-rows-\(suffix)")
            app.terminate()
        }
        let large = XCUIApplication.launchPinned(
            language: "vi", seedCycles: "fertile", cycleGoal: "tracking", contraception: "copperIUD", largestText: true
        )
        large.openCycleTab(.profile)
        XCTAssertTrue(large.segmentedControls["settingsModePicker"].waitForExistence(timeout: 10))
        attachScreenshot(large, "ax5-profile-goal-vi-light")
        let toggle = large.switches["profileShowFertilityTests"]
        large.scrollUntilHittable(toggle, maxSwipes: 10)
        attachScreenshot(large, "ax5-profile-tracking-rows-vi-light")
    }
}
