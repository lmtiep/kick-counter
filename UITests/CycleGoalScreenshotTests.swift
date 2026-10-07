import XCTest

/// Phase 9 spec §5: Today and the calendar while tracking, with and without
/// hormonal contraception (pinned clock, "fertile": cycle day 13).
final class CycleGoalScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchTracking(_ language: String, dark: Bool, contraception: String? = nil, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(
            language: language,
            dark: dark,
            seedCycles: "fertile",
            cycleGoal: "tracking",
            contraception: contraception,
            largestText: largestText
        )
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testTrackingTodayScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = launchTracking(language, dark: dark)
            attachScreenshot(app, "cycle-tracking-today-\(suffix)")
            let note = app.staticTexts["cycleNotContraceptionNote"]
            app.scrollUntilHittable(note)
            attachScreenshot(app, "cycle-tracking-coming-up-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testTrackingOnThePillScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = launchTracking(language, dark: dark, contraception: "pill")
            attachScreenshot(app, "cycle-pill-today-\(suffix)")
            let note = app.staticTexts["cycleHormonalNote"]
            app.scrollUntilHittable(note)
            attachScreenshot(app, "cycle-pill-coming-up-\(suffix)")
            app.openCycleTab(.calendar)
            XCTAssertTrue(app.descendants(matching: .any)["calendarLegend"].waitForExistence(timeout: 5))
            attachScreenshot(app, "cycle-pill-calendar-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testTrackingAtLargestText() {
        let app = launchTracking("vi", dark: false, largestText: true)
        attachScreenshot(app, "ax5-cycle-tracking-today-vi-light")
        let note = app.staticTexts["cycleNotContraceptionNote"]
        app.scrollUntilHittable(note, maxSwipes: 10)
        attachScreenshot(app, "ax5-cycle-tracking-note-vi-light")
        app.terminate()

        let pill = launchTracking("vi", dark: false, contraception: "pill", largestText: true)
        let hormonal = pill.staticTexts["cycleHormonalNote"]
        pill.scrollUntilHittable(hormonal, maxSwipes: 10)
        attachScreenshot(pill, "ax5-cycle-pill-note-vi-light")
    }
}
