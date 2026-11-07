import XCTest

/// 1.1 item 4 (spec §6): the paused cycle Today (both branches), the first-period
/// question, the check-in card and its reply, and Profile's check-in settings, in
/// vi light, vi dark and vi at AX5.
final class CareAfterPregnancyScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testCareScreens() {
        for (dark, largest) in [(false, false), (true, false), (false, true)] {
            let suffix = UITestVariants.suffix("vi", dark) + (largest ? "-ax5" : "")

            let loss = XCUIApplication.launchPinned(
                language: "vi", dark: dark, largestText: largest, extraArguments: ["-seedPregnancyEnded", "loss:21"]
            )
            XCTAssertTrue(loss.descendants(matching: .any)["careCheckInCard"].waitForExistence(timeout: 10))
            attachScreenshot(loss, "care-checkin-loss-\(suffix)")
            let sad = loss.buttons["careFeeling-sad"]
            loss.scrollUntilHittable(sad)
            sad.tap()
            XCTAssertTrue(loss.staticTexts["careReply"].waitForExistence(timeout: 5))
            attachScreenshot(loss, "care-reply-loss-\(suffix)")
            let close = loss.buttons["careClose"]
            loss.scrollUntilHittable(close)
            close.tap()
            let paused = loss.staticTexts["cyclePausedText"]
            XCTAssertTrue(paused.waitForExistence(timeout: 5))
            attachScreenshot(loss, "cycle-paused-loss-\(suffix)")
            let start = loss.buttons["cyclePausedStart"]
            loss.scrollUntilHittable(start)
            start.tap()
            XCTAssertTrue(loss.alerts.firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(loss, "first-period-question-loss-\(suffix)")
            loss.terminate()

            let birth = XCUIApplication.launchPinned(
                language: "vi", dark: dark, largestText: largest, extraArguments: ["-seedPregnancyEnded", "birth:30"]
            )
            XCTAssertTrue(birth.staticTexts["cyclePausedText"].waitForExistence(timeout: 10))
            attachScreenshot(birth, "cycle-paused-birth-\(suffix)")
            birth.openCycleTab(.profile)
            let toggle = birth.switches["careEnabledToggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 10))
            birth.scrollUntilHittable(toggle)
            attachScreenshot(birth, "care-profile-\(suffix)")
            birth.terminate()
        }
    }
}
