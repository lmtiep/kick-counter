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
}
