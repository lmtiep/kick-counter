import XCTest

/// Phase 12 (App Store readiness): partner mode hidden while iCloud is off,
/// "Delete all data", and the privacy policy and support links.
final class AppStoreReadinessUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Spec §3.2: no "Share with baby's dad" card, even with a share state the fake would show.
    @MainActor
    func testPregnancyProfileHasNoPartnerSharing() {
        let app = XCUIApplication.launchPinned(
            language: "en",
            dueDate: UITestDates.dueAtWeek24,
            extraArguments: ["-uiTestingSharing", "joined"]
        )
        app.openTab(.profile)
        XCTAssertTrue(app.buttons["profileAppointments"].waitForExistence(timeout: 10))
        let medical = app.buttons["settingsMedicalInfo"]
        app.scrollUntilHittable(medical)
        XCTAssertTrue(medical.isHittable)
        XCTAssertFalse(app.buttons["partnerShareRow"].exists)
        XCTAssertFalse(app.staticTexts["partnerSharePrivacy"].exists)
    }

    /// Spec §3.2: the goal picker offers only the three goals, and so does onboarding.
    @MainActor
    func testModePickerHasNoPartnerEntry() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let picker = app.segmentedControls["settingsModePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        XCTAssertEqual(picker.buttons.count, 3)
        for label in ["Track cycle", "Trying to conceive", "Pregnant"] {
            XCTAssertTrue(picker.buttons[label].exists, label)
        }

        let onboarding = XCUIApplication.launchPinned(language: "en", skipOnboarding: false)
        let next = onboarding.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        XCTAssertTrue(onboarding.buttons["onboardingGoal-pregnant"].waitForExistence(timeout: 5))
        let goals = onboarding.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'onboardingGoal-'"))
        XCTAssertEqual(goals.count, 3)
    }

    /// Spec §3.2: a stored partner mode (a TestFlight partner) lands in onboarding, not partner Today.
    @MainActor
    func testStoredPartnerModeShowsOnboarding() {
        let app = XCUIApplication.launchPinned(language: "en", extraArguments: ["-seedAppMode", "partner"])
        XCTAssertTrue(app.staticTexts["onboardingWelcomeTitle"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["partnerTodayTitle"].exists)
    }

    /// Spec §3.4: cancel keeps everything; "Delete" → onboarding, and afterwards no period is left.
    @MainActor
    func testDeleteAllDataReturnsToOnboarding() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        app.openCycleTab(.profile)
        let delete = app.buttons["profileDeleteAllData"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        app.scrollUntilHittable(delete)
        XCTAssertEqual(delete.label, "Delete all data")

        // Cancel: nothing happens.
        delete.tap()
        let alert = app.alerts["Delete all data?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS 'permanently deleted'")).firstMatch.exists)
        alert.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts["onboardingWelcomeTitle"].waitForExistence(timeout: 2))
        app.openCycleTab(.today)
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 5))

        // Delete.
        app.openCycleTab(.profile)
        app.scrollUntilHittable(delete)
        delete.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["onboardingWelcomeTitle"].waitForExistence(timeout: 10))

        // Trying to conceive without a last period: the empty state, no seeded period left.
        let next = app.buttons["onboardingNext"]
        next.tap()
        let conceiving = app.buttons["onboardingGoal-conceiving"]
        XCTAssertTrue(conceiving.waitForExistence(timeout: 5))
        conceiving.tap()
        next.tap()
        let dontRemember = app.buttons["onboardingDontRemember"]
        XCTAssertTrue(dontRemember.waitForExistence(timeout: 5))
        dontRemember.tap()
        let skip = app.buttons["onboardingSkip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap() // period length
        skip.tap() // cycle length
        XCTAssertTrue(app.buttons["onboardingRegularity-unknown"].waitForExistence(timeout: 5))
        skip.tap() // regularity
        let later = app.buttons["onboardingFinishLater"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        XCTAssertTrue(app.buttons["cycleAddPeriodButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["cycleStatusCard"].exists)
    }

    /// Spec §3.5: both rows exist in "About", open in Safari (a link with a hint).
    @MainActor
    func testPrivacyAndSupportLinks() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        XCTAssertTrue(app.buttons["profileAppointments"].waitForExistence(timeout: 10))
        for (identifier, label) in [("profilePrivacyPolicy", "Privacy policy"), ("profileSupport", "Support")] {
            let row = app.descendants(matching: .any)[identifier]
            app.scrollUntilHittable(row)
            XCTAssertTrue(row.exists, identifier)
            XCTAssertTrue(row.isHittable, identifier)
            XCTAssertTrue([.link, .button].contains(row.elementType), "\(identifier): \(row.elementType.rawValue)")
            XCTAssertEqual(row.label, label)
        }
    }
}
