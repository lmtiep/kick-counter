import XCTest

// The partner UI is compiled only with the CLOUD_SYNC flag (not set for 1.0, App Review
// 2.5.19): see `AppFeatures.cloudSync`.
#if CLOUD_SYNC
/// Phase 8 spec §6: screenshots of partner sharing (pinned clock, week 24).
final class PartnerScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The mother's Profile scrolled to the share card.
    @MainActor
    private func openShareRow(_ state: String, language: String, dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(
            language: language,
            dark: dark,
            dueDate: UITestDates.dueAtWeek24,
            extraArguments: ["-uiTestingSharing", state, "-uiTestingPartnerUI"]
        )
        app.openTab(.profile)
        let row = app.buttons["partnerShareRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(app.staticTexts["partnerSharePrivacy"])
        return app
    }

    @MainActor
    func testMotherRowNotSharedVietnameseLight() {
        let app = openShareRow("notShared", language: "vi")
        waitForLabel(app.buttons["partnerShareRow"], containing: "Mời bố bé xem hành trình")
        attachScreenshot(app, "partner-share-row-notShared-vi-light")
    }

    @MainActor
    func testMotherRowJoinedEnglishDark() {
        let app = openShareRow("joined", language: "en", dark: true)
        waitForLabel(app.buttons["partnerShareRow"], containing: "Baby's dad is following")
        attachScreenshot(app, "partner-share-row-joined-en-dark")
    }

    @MainActor
    private func launchPartner(_ state: String, language: String, dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        XCUIApplication.launchPinned(
            language: language,
            dark: dark,
            largestText: largestText,
            extraArguments: ["-uiTestingPartner", state, "-uiTestingPartnerUI"]
        )
    }

    @MainActor
    func testPartnerTodayVietnameseLight() {
        let app = launchPartner("snapshot", language: "vi")
        XCTAssertTrue(app.staticTexts["partnerTodayTitle"].waitForExistence(timeout: 10))
        attachScreenshot(app, "partner-today-vi-light")
        app.scrollUntilHittable(app.staticTexts["partnerUpdated"])
        attachScreenshot(app, "partner-today-vi-light-scrolled")
        app.openPartnerTab(.profile)
        XCTAssertTrue(app.buttons["partnerLeave"].waitForExistence(timeout: 5))
        attachScreenshot(app, "partner-profile-vi-light")
    }

    @MainActor
    func testPartnerTodayEnglishDark() {
        let app = launchPartner("snapshot", language: "en", dark: true)
        XCTAssertTrue(app.staticTexts["partnerTodayTitle"].waitForExistence(timeout: 10))
        attachScreenshot(app, "partner-today-en-dark")
        app.scrollUntilHittable(app.staticTexts["partnerUpdated"])
        attachScreenshot(app, "partner-today-en-dark-scrolled")
    }

    @MainActor
    func testPartnerTodayLargestText() {
        let app = launchPartner("snapshot", language: "vi", largestText: true)
        XCTAssertTrue(app.staticTexts["partnerTodayTitle"].waitForExistence(timeout: 10))
        attachScreenshot(app, "partner-today-vi-ax5")
        app.scrollUntilHittable(app.descendants(matching: .any)["partnerKicks"], maxSwipes: 12)
        attachScreenshot(app, "partner-today-vi-ax5-kicks")
    }

    @MainActor
    func testPartnerStoppedVietnameseLight() {
        let app = launchPartner("stopped", language: "vi")
        XCTAssertTrue(app.descendants(matching: .any)["partnerStopped"].waitForExistence(timeout: 10))
        attachScreenshot(app, "partner-stopped-vi-light")
    }
}
#else
/// Stands in for the partner tests while CLOUD_SYNC is off, so a CI shard or a
/// `-only-testing` filter that names this class still finds a test.
final class PartnerScreenshotTests: XCTestCase {
    func testPartnerUIIsCompiledOut() throws {
        throw XCTSkip("Partner sharing is compiled out of this build (no CLOUD_SYNC)")
    }
}
#endif
