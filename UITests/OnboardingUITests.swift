import XCTest

/// Phase 9 spec §4.1 and §5: the three onboarding branches, skipping, going
/// back, the language on the first step, the result screen, and screenshots of
/// every step. The clock is pinned to 2026-10-02.
final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(language: String = "en", dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        XCUIApplication.launchPinned(language: language, dark: dark, skipOnboarding: false, largestText: largestText)
    }

    /// Welcome → goal → that goal's first question.
    @MainActor
    private func choose(_ goal: String, in app: XCUIApplication) {
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let card = app.buttons["onboardingGoal-\(goal)"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        next.tap()
    }

    /// Tracking: every question answered → the predicted date on the result →
    /// "Turn on reminders" → Today at the right cycle day.
    @MainActor
    func testTrackingBranchShowsThePredictedDate() {
        let app = launch()
        choose("tracking", in: app)
        let progress = app.descendants(matching: .any)["onboardingProgress"]
        waitForLabel(progress, containing: "Step 3 of 8")

        let day = app.buttons.matching(
            NSPredicate(format: "identifier == 'onboardingDay' AND label BEGINSWITH 'September 20'")
        ).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap()
        XCTAssertTrue(day.isSelected)
        let next = app.buttons["onboardingNext"]
        next.tap()

        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5)) // period length, keep 5
        next.tap()
        XCTAssertTrue(app.staticTexts["onboardingCycleLengthHint"].waitForExistence(timeout: 5))
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "30 days")
        next.tap()

        let irregular = app.buttons["onboardingRegularity-irregular"]
        XCTAssertTrue(irregular.waitForExistence(timeout: 5))
        irregular.tap()
        XCTAssertTrue(app.staticTexts["onboardingIrregularNote"].waitForExistence(timeout: 5))
        app.buttons["onboardingRegularity-regular"].tap()
        XCTAssertFalse(app.staticTexts["onboardingIrregularNote"].exists)
        next.tap()

        XCTAssertTrue(app.staticTexts["onboardingContraceptionWhy"].waitForExistence(timeout: 5))
        let condom = app.buttons["onboardingContraception-condom"]
        app.scrollDownUntilHittable(condom)
        condom.tap()
        XCTAssertTrue(condom.isSelected)
        next.tap()

        // 2026-09-20 + 30 days.
        let result = app.staticTexts["onboardingResultText"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("October 20"), result.label)
        waitForLabel(progress, containing: "Step 8 of 8")
        XCTAssertFalse(app.buttons["onboardingSkip"].exists)
        app.buttons["onboardingEnableReminders"].tap()

        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
    }

    /// Trying to conceive: 7 steps, no contraception question; "I don't
    /// remember" leaves no period, so the result asks to log the next one.
    @MainActor
    func testConceivingBranchWithoutALastPeriod() {
        let app = launch()
        choose("conceiving", in: app)
        let progress = app.descendants(matching: .any)["onboardingProgress"]
        waitForLabel(progress, containing: "Step 3 of 7")
        let dontRemember = app.buttons["onboardingDontRemember"]
        XCTAssertTrue(dontRemember.waitForExistence(timeout: 5))
        dontRemember.tap()
        waitForLabel(progress, containing: "Step 4 of 7")

        let skip = app.buttons["onboardingSkip"]
        XCTAssertEqual(skip.label, "Not sure")
        skip.tap() // period length
        skip.tap() // cycle length
        XCTAssertTrue(app.buttons["onboardingRegularity-unknown"].waitForExistence(timeout: 5))
        skip.tap() // regularity

        let result = app.staticTexts["onboardingResultText"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("Log the first day of your next period"), result.label)
        XCTAssertFalse(app.buttons["onboardingContraception-pill"].exists)
        app.buttons["onboardingFinishLater"].tap()

        XCTAssertTrue(app.buttons["cycleAddPeriodButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
    }

    /// Pregnant: −/+ move the due date a week at a time → the week on the
    /// result and on Today.
    @MainActor
    func testPregnancyBranchMovesTheDueDateAWeekAtATime() {
        let app = launch()
        choose("pregnant", in: app)

        // The default due date is 140 days ahead: 20 weeks today.
        let weeks = app.staticTexts["onboardingDueWeeks"]
        XCTAssertTrue(weeks.waitForExistence(timeout: 5))
        XCTAssertEqual(weeks.label, "20 weeks, 0 days")
        app.buttons["onboardingDueLater"].tap()
        waitForLabel(weeks, containing: "19 weeks, 0 days")
        app.buttons["onboardingDueEarlier"].tap()
        app.buttons["onboardingDueEarlier"].tap()
        waitForLabel(weeks, containing: "21 weeks, 0 days")
        app.buttons["onboardingNext"].tap()

        let result = app.staticTexts["onboardingResultText"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("21 weeks, 0 days"), result.label)
        waitForLabel(app.descendants(matching: .any)["onboardingProgress"], containing: "Step 4 of 4")
        app.buttons["onboardingFinishLater"].tap()

        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("21 weeks, 0 days"), progress.label)
        XCTAssertTrue(app.tabBars.buttons["Kicks"].exists)
    }

    /// Pregnant + "Turn on reminders": saves the due date and lands on Today
    /// (notifications are stubbed under UI tests, so no system alert).
    @MainActor
    func testPregnancyBranchTurnsOnReminders() {
        let app = launch()
        choose("pregnant", in: app)
        XCTAssertTrue(app.staticTexts["onboardingDueWeeks"].waitForExistence(timeout: 5))
        app.buttons["onboardingNext"].tap()
        let enable = app.buttons["onboardingEnableReminders"]
        XCTAssertTrue(enable.waitForExistence(timeout: 5))
        enable.tap()

        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("20 weeks, 0 days"), progress.label)
        XCTAssertTrue(app.tabBars.buttons["Kicks"].exists)
    }

    /// Welcome has no "Skip"; skipping the goal means pregnancy, and skipping
    /// the due date saves none. The medical and privacy notes are on step 1.
    @MainActor
    func testSkippingTheGoalMeansPregnancy() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["onboardingMedicalNote"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["onboardingPrivacyNote"].exists)
        let progress = app.descendants(matching: .any)["onboardingProgress"]
        XCTAssertEqual(progress.label, "Step 1 of 8")
        XCTAssertFalse(app.buttons["onboardingSkip"].exists)
        XCTAssertFalse(app.buttons["onboardingBack"].exists)
        app.buttons["onboardingNext"].tap()

        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboardingNext"].isEnabled) // nothing chosen yet
        skip.tap()
        XCTAssertTrue(app.buttons["onboardingDueDate"].waitForExistence(timeout: 5))
        waitForLabel(progress, containing: "Step 3 of 4")
        skip.tap()
        let later = app.buttons["onboardingFinishLater"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["onboardingResultText"].label.contains("add your due date later"))
        later.tap()
        XCTAssertTrue(app.buttons["pregnancyAddDateButton"].waitForExistence(timeout: 10))
    }

    /// "Back" returns to the previous step with the answer kept.
    @MainActor
    func testBackKeepsTheAnswer() {
        let app = launch()
        choose("tracking", in: app)
        let back = app.buttons["onboardingBack"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        let tracking = app.buttons["onboardingGoal-tracking"]
        XCTAssertTrue(tracking.waitForExistence(timeout: 5))
        XCTAssertTrue(tracking.isSelected)
        back.tap()
        XCTAssertTrue(app.staticTexts["onboardingWelcomeTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(back.exists)
    }

    /// Spec §2.2 (phase 4): the language chosen on the first step applies at once.
    @MainActor
    func testChoosingALanguageOnTheFirstStepAppliesAtOnce() {
        let app = launch(language: "vi")
        let title = app.staticTexts["onboardingWelcomeTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Chào mừng đến với Luna Mom")
        app.buttons["onboardingLanguageEn"].tap()
        waitForLabel(title, containing: "Welcome to Luna Mom")
        XCTAssertTrue(app.buttons["onboardingLanguageEn"].isSelected)
        app.buttons["onboardingNext"].tap()
        XCTAssertTrue(app.staticTexts["What would you like to track?"].waitForExistence(timeout: 5))
    }

    /// The welcome text stays on the plain background at the largest text size.
    @MainActor
    func testWelcomeScreenAtLargestText() {
        for dark in [false, true] {
            let app = launch(language: "vi", dark: dark, largestText: true)
            XCTAssertTrue(app.buttons["onboardingNext"].waitForExistence(timeout: 10))
            attachScreenshot(app, "ax5-onboarding-welcome-vi-\(dark ? "dark" : "light")")
            app.terminate()
        }
    }

    /// The new steps at AX5: "Không chắc" on one line, contraception (8 choices)
    /// and the result.
    @MainActor
    func testNewStepsAtLargestText() {
        let app = launch(language: "vi", largestText: true)
        choose("tracking", in: app)
        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap() // last period
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(skip.label, "Không chắc")
        attachScreenshot(app, "ax5-onboarding-period-length-vi-light")
        for _ in 0..<3 { skip.tap() } // period length, cycle length, regularity
        XCTAssertTrue(app.buttons["onboardingContraception-otherOrPrivate"].waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-onboarding-contraception-vi-light")
        skip.tap()
        XCTAssertTrue(app.buttons["onboardingFinishLater"].waitForExistence(timeout: 5))
        attachScreenshot(app, "ax5-onboarding-result-vi-light")
    }

    @MainActor
    func testOnboardingScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = launch(language: language, dark: dark)
            let next = app.buttons["onboardingNext"]
            XCTAssertTrue(next.waitForExistence(timeout: 10))
            attachScreenshot(app, "onboarding-welcome-\(suffix)")
            next.tap()
            let tracking = app.buttons["onboardingGoal-tracking"]
            XCTAssertTrue(tracking.waitForExistence(timeout: 5))
            tracking.tap()
            attachScreenshot(app, "onboarding-goal-\(suffix)")
            next.tap()
            XCTAssertTrue(app.buttons["onboardingDontRemember"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-last-period-\(suffix)")
            next.tap()
            XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-period-length-\(suffix)")
            next.tap()
            XCTAssertTrue(app.staticTexts["onboardingCycleLengthHint"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-cycle-length-\(suffix)")
            next.tap()
            let irregular = app.buttons["onboardingRegularity-irregular"]
            XCTAssertTrue(irregular.waitForExistence(timeout: 5))
            irregular.tap()
            XCTAssertTrue(app.staticTexts["onboardingIrregularNote"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-regularity-\(suffix)")
            next.tap()
            XCTAssertTrue(app.staticTexts["onboardingContraceptionWhy"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-contraception-\(suffix)")
            next.tap()
            XCTAssertTrue(app.staticTexts["onboardingResultText"].waitForExistence(timeout: 5))
            attachScreenshot(app, "onboarding-result-\(suffix)")
            app.terminate()

            let pregnant = launch(language: language, dark: dark)
            choose("pregnant", in: pregnant)
            XCTAssertTrue(pregnant.staticTexts["onboardingDueWeeks"].waitForExistence(timeout: 5))
            attachScreenshot(pregnant, "onboarding-due-\(suffix)")
            pregnant.buttons["onboardingNext"].tap()
            XCTAssertTrue(pregnant.staticTexts["onboardingResultText"].waitForExistence(timeout: 5))
            attachScreenshot(pregnant, "onboarding-result-pregnant-\(suffix)")
            pregnant.terminate()
        }
    }
}
