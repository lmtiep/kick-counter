import XCTest

/// Spec §4.1 and §6: both onboarding branches, the language on the first step,
/// "Skip", and screenshots of every step.
final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Trying to conceive: a day picked in the 14-day grid → Today shows the right cycle day.
    @MainActor
    func testCycleBranchUsesTheDayPickedInTheGrid() {
        let app = XCUIApplication.launchPinned(language: "en", skipOnboarding: false)
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        XCTAssertTrue(app.buttons["onboardingModeTTC"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled) // nothing chosen yet
        app.buttons["onboardingModeTTC"].tap()
        next.tap()

        let day = app.buttons.matching(
            NSPredicate(format: "identifier == 'onboardingDay' AND label BEGINSWITH 'September 20'")
        ).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        XCTAssertTrue(day.isSelected)
        app.buttons["onboardingSaveCycle"].tap()

        // 2026-09-20 → 2026-10-02 is cycle day 13, in trying-to-conceive mode.
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
    }

    /// Pregnant: −/+ move the due date a week at a time → the matching week on Today.
    @MainActor
    func testPregnancyBranchMovesTheDueDateAWeekAtATime() {
        let app = XCUIApplication.launchPinned(language: "en", skipOnboarding: false)
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let pregnant = app.buttons["onboardingModePregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        next.tap()

        // The default due date is 140 days ahead: 20 weeks today.
        let weeks = app.staticTexts["onboardingDueWeeks"]
        XCTAssertTrue(weeks.waitForExistence(timeout: 5))
        XCTAssertEqual(weeks.label, "20 weeks, 0 days")
        app.buttons["onboardingDueLater"].tap()
        waitForLabel(weeks, containing: "19 weeks, 0 days")
        app.buttons["onboardingDueEarlier"].tap()
        app.buttons["onboardingDueEarlier"].tap()
        waitForLabel(weeks, containing: "21 weeks, 0 days")
        app.buttons["onboardingSaveDate"].tap()

        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("Week 21 + 0 days"), progress.label)
        XCTAssertTrue(app.tabBars.buttons["Kicks"].exists)
    }

    /// "Skip" jumps to the last step (pregnant by default); the medical note is on step 1.
    @MainActor
    func testSkipJumpsToTheDueDateStep() {
        let app = XCUIApplication.launchPinned(language: "en", skipOnboarding: false)
        XCTAssertTrue(app.staticTexts["onboardingMedicalNote"].waitForExistence(timeout: 10))
        let progress = app.descendants(matching: .any)["onboardingProgress"]
        XCTAssertEqual(progress.label, "Step 1 of 3")
        app.buttons["onboardingSkip"].tap()

        XCTAssertTrue(app.buttons["onboardingSaveDate"].waitForExistence(timeout: 5))
        waitForLabel(progress, containing: "Step 3 of 3")
        XCTAssertFalse(app.buttons["onboardingSkip"].exists)
        app.buttons["onboardingSkipDate"].tap()
        XCTAssertTrue(app.buttons["pregnancyAddDateButton"].waitForExistence(timeout: 10))
    }

    /// Spec §2.2: the language chosen on the first step applies at once.
    @MainActor
    func testChoosingALanguageOnTheFirstStepAppliesAtOnce() {
        let app = XCUIApplication.launchPinned(language: "vi", skipOnboarding: false)
        let title = app.staticTexts["onboardingWelcomeTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Chào mừng đến với Luna Mom")
        app.buttons["onboardingLanguageEn"].tap()
        waitForLabel(title, containing: "Welcome to Luna Mom")
        XCTAssertTrue(app.buttons["onboardingLanguageEn"].isSelected)
        app.buttons["onboardingNext"].tap()
        XCTAssertTrue(app.staticTexts["What would you like to track?"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, skipOnboarding: false)
            let next = app.buttons["onboardingNext"]
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            attachScreenshot(app, "onboarding-welcome-\(suffix)")
            next.tap()
            let tryingToConceive = app.buttons["onboardingModeTTC"]
            XCTAssertTrue(tryingToConceive.waitForExistence(timeout: 5))
            tryingToConceive.tap()
            attachScreenshot(app, "onboarding-goal-\(suffix)")
            next.tap()
            XCTAssertTrue(app.buttons["onboardingSaveCycle"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-cycle-\(suffix)")
            app.terminate()

            let pregnant = XCUIApplication.launchPinned(language: language, dark: dark, skipOnboarding: false)
            let skip = pregnant.buttons["onboardingSkip"]
            XCTAssertTrue(skip.waitForExistence(timeout: 10))
            skip.tap()
            XCTAssertTrue(pregnant.buttons["onboardingSaveDate"].waitForExistence(timeout: 5))
            attachScreenshot(pregnant, "onboarding-due-\(suffix)")
            pregnant.terminate()
        }
    }
}
