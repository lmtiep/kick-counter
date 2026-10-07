import XCTest

/// Phase 8 spec §5.2 and §6: partner mode with `FakePartnerSharing`
/// (`-uiTestingPartner`): the seeded week-24 snapshot, the stopped and error
/// states, leaving, and tabs without a kick counter.
final class PartnerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchPartner(_ state: String, language: String = "en") -> XCUIApplication {
        XCUIApplication.launchPinned(language: language, extraArguments: ["-uiTestingPartner", state])
    }

    @MainActor
    func testTodayShowsTheSharedWeekAppointmentsAndKicks() {
        let app = launchPartner("snapshot")
        let title = app.staticTexts["partnerTodayTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Mom's journey")
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.exists)
        XCTAssertTrue(progress.label.contains("24 weeks, 3 days"), progress.label)
        XCTAssertTrue(progress.label.contains("109 days to go"), progress.label)
        XCTAssertTrue(app.buttons["partnerBabySize"].exists)

        let appointments = app.descendants(matching: .any)["partnerAppointments"]
        app.scrollUntilHittable(appointments)
        XCTAssertTrue(appointments.label.contains("Anomaly scan"), appointments.label)
        XCTAssertTrue(appointments.label.contains("Glucose test"), appointments.label)

        let kicks = app.descendants(matching: .any)["partnerKicks"]
        app.scrollUntilHittable(kicks)
        XCTAssertTrue(kicks.label.contains("10 movements in 18 min, 3 hours ago"), kicks.label)
        XCTAssertTrue(kicks.label.contains("4 sessions in 7 days · average 21 min"), kicks.label)
        let updated = app.staticTexts["partnerUpdated"]
        app.scrollUntilHittable(updated)
        XCTAssertEqual(updated.label, "Updated 10 minutes ago")
    }

    @MainActor
    func testTheBabySizeCardOpensTheWeekDetail() {
        let app = launchPartner("snapshot")
        let size = app.buttons["partnerBabySize"]
        XCTAssertTrue(size.waitForExistence(timeout: 10))
        size.tap()
        let close = app.buttons["weekDetailClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(size.waitForExistence(timeout: 5))
    }

    /// Spec §5.2: Today · Knowledge · Profile, never the kick counter.
    @MainActor
    func testTheTabsHaveNoKickCounter() {
        let app = launchPartner("snapshot")
        XCTAssertTrue(app.staticTexts["partnerTodayTitle"].waitForExistence(timeout: 10))
        let tabs = app.tabBars.buttons
        XCTAssertEqual(tabs.count, 3)
        XCTAssertTrue(tabs["Today"].exists)
        XCTAssertTrue(tabs["Knowledge"].exists)
        XCTAssertTrue(tabs["Profile"].exists)
        XCTAssertFalse(tabs["Kicks"].exists)

        app.openPartnerTab(.knowledge)
        let second = app.buttons["knowledgeTrimester-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertTrue(second.isSelected)

        app.openPartnerTab(.profile)
        XCTAssertTrue(app.buttons["partnerLeave"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["partnerAbout"].exists)
        XCTAssertFalse(app.buttons["profileKickReminder"].exists)
        XCTAssertFalse(app.buttons["partnerShareRow"].exists)
    }

    @MainActor
    func testStoppedSharingOffersToLeavePartnerMode() {
        let app = launchPartner("stopped")
        let stopped = app.descendants(matching: .any)["partnerStopped"]
        XCTAssertTrue(stopped.waitForExistence(timeout: 10))
        XCTAssertTrue(stopped.label.contains("Mom stopped sharing"), stopped.label)
        app.buttons["partnerStoppedLeave"].tap()
        // Back to the mode before partner mode: pregnancy, here without a due date.
        XCTAssertTrue(app.tabBars.buttons["Kicks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pregnancyAddDateButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLeavingFromProfileAsksFirst() {
        let app = launchPartner("snapshot")
        app.openPartnerTab(.profile)
        let leave = app.buttons["partnerLeave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 10))
        app.scrollUntilHittable(leave)
        leave.tap()
        app.confirmDialog("Leave partner mode")
        XCTAssertTrue(app.tabBars.buttons["Kicks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    @MainActor
    func testAnErrorOffersRetry() {
        let app = launchPartner("error")
        let error = app.descendants(matching: .any)["partnerError"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.label.contains("Couldn't load the journey"), error.label)
        let retry = app.buttons["partnerRetry"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(error.waitForExistence(timeout: 5))
    }

    /// Accepted, but the mother has not published yet: loading, not "stopped" or an error.
    @MainActor
    func testNothingPublishedYetKeepsLoading() {
        let app = launchPartner("notReadyYet")
        let loading = app.descendants(matching: .any)["partnerLoading"]
        XCTAssertTrue(loading.waitForExistence(timeout: 10))
        XCTAssertTrue(loading.label.contains("Loading the journey"), loading.label)
        XCTAssertFalse(app.descendants(matching: .any)["partnerStopped"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["partnerError"].exists)
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }

    @MainActor
    func testWithoutICloudAsksToSignIn() {
        let app = launchPartner("icloudUnavailable")
        let state = app.descendants(matching: .any)["partnerICloudUnavailable"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        XCTAssertTrue(state.label.contains("Sign in to iCloud"), state.label)
    }
}
