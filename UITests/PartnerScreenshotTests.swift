import XCTest

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
            extraArguments: ["-uiTestingSharing", state]
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
            extraArguments: ["-uiTestingPartner", state]
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
