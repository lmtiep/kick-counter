import XCTest

/// "Gửi góp ý" in Profile. The mail composer is never opened here.
final class ProfileFeedbackUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFeedbackRowExistsAndIsHittable() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let row = app.buttons["profileFeedback"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(row.label.contains("Send feedback"), row.label)
    }
}
