import XCTest

/// Phase 8 spec §5.1 and §6: the mother's "Share with baby's dad" row in each
/// state, with `FakePartnerSharing` (`-uiTestingSharing`).
final class PartnerShareUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Profile with a due date at week 24, the fake in `state`; returns the row.
    @MainActor
    private func openRow(_ state: String?, dueDate: String? = UITestDates.dueAtWeek24) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication.launchPinned(
            language: "en",
            dueDate: dueDate,
            extraArguments: state.map { ["-uiTestingSharing", $0] } ?? []
        )
        app.openTab(.profile)
        let row = app.buttons["partnerShareRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        return (app, row)
    }

    @MainActor
    func testNotSharedInvitesAndThenShowsShared() {
        let (app, row) = openRow("notShared")
        waitForLabel(row, containing: "Invite baby's dad to follow the journey")
        XCTAssertTrue(row.isEnabled)
        XCTAssertFalse(app.buttons["partnerStopSharing"].exists)
        XCTAssertTrue(app.staticTexts["partnerSharePrivacy"].exists)
        // The fake creates the share and presents nothing.
        row.tap()
        waitForLabel(row, containing: "Shared")
        XCTAssertTrue(app.buttons["partnerStopSharing"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testInvitedCanStopSharingAfterConfirming() {
        let (app, row) = openRow("invited")
        waitForLabel(row, containing: "Shared")
        let stop = app.buttons["partnerStopSharing"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        app.scrollUntilHittable(stop)
        stop.tap()
        app.confirmDialog("Stop sharing")
        waitForLabel(row, containing: "Invite baby's dad to follow the journey")
        XCTAssertFalse(app.buttons["partnerStopSharing"].exists)
    }

    @MainActor
    func testJoinedSaysBabysDadIsFollowing() {
        let (app, row) = openRow("joined")
        waitForLabel(row, containing: "Baby's dad is following")
        XCTAssertTrue(row.isEnabled)
        XCTAssertTrue(app.buttons["partnerStopSharing"].exists)
    }

    @MainActor
    func testWithoutADueDateTheRowIsDisabled() {
        let (_, row) = openRow("notShared", dueDate: nil)
        waitForLabel(row, containing: "Set the due date first")
        XCTAssertFalse(row.isEnabled)
    }

    @MainActor
    func testWithoutICloudTheRowIsDisabled() {
        let (app, row) = openRow("icloudUnavailable")
        waitForLabel(row, containing: "Sign in to iCloud to share")
        XCTAssertFalse(row.isEnabled)
        XCTAssertFalse(app.buttons["partnerStopSharing"].exists)
    }

    /// Spec §2: no sharing while trying to conceive.
    @MainActor
    func testTryingToConceiveHasNoShareRow() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "period", extraArguments: ["-uiTestingSharing", "joined"])
        app.openCycleTab(.profile)
        XCTAssertTrue(app.buttons["settingsMedicalInfo"].waitForExistence(timeout: 10))
        for _ in 0..<3 { app.swipeUp() }
        XCTAssertFalse(app.buttons["partnerShareRow"].exists)
    }
}
