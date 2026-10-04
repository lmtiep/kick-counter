import XCTest

/// Captures screenshots for visual review. CI exports them to build/screenshots,
/// and `scripts/ci-wait.sh` downloads them to ci-artifacts/screenshots.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func launch(language: String = "vi", dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
        ]
        if dark { app.launchArguments.append("-forceDarkMode") }
        app.launch()
        app.openTab(.kicks)
        return app
    }

    @MainActor
    func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func tapKick(_ app: XCUIApplication, times: Int) {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 10))
        for _ in 0..<times {
            kick.tap()
            Thread.sleep(forTimeInterval: 0.6) // stay above the 0.5 s debounce
        }
    }

    /// Confirms the cancel-session dialog (its destructive button comes first).
    @MainActor
    func confirmCancel(_ app: XCUIApplication) {
        let sheetButton = app.sheets.buttons.element(boundBy: 0)
        if sheetButton.waitForExistence(timeout: 2) {
            sheetButton.tap()
            return
        }
        // Newer iOS versions may show a popover: its button has the same label.
        let label = app.buttons["cancelSessionButton"].label
        app.buttons.matching(NSPredicate(format: "label == %@", label)).element(boundBy: 1).tap()
    }

    @MainActor
    func testHistoryScreens() {
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let app = launch(dark: dark)
            tapKick(app, times: 10)
            XCTAssertTrue(app.buttons["completionDone"].waitForExistence(timeout: 5))
            app.buttons["completionDone"].tap()
            tapKick(app, times: 2)
            app.buttons["cancelSessionButton"].tap()
            confirmCancel(app)
            app.openHistory()
            XCTAssertTrue(app.descendants(matching: .any)["sessionRow"].firstMatch.waitForExistence(timeout: 5))
            snap(app, "history-\(suffix)")
            app.terminate()
        }
    }

    @MainActor
    func testCounterScreens() {
        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            let app = launch(dark: dark)
            tapKick(app, times: 0)
            snap(app, "counter-empty-\(suffix)")
            tapKick(app, times: 3)
            snap(app, "counter-3-\(suffix)")
            tapKick(app, times: 7)
            XCTAssertTrue(app.staticTexts["completionTitle"].waitForExistence(timeout: 5))
            snap(app, "completion-\(suffix)")
            app.terminate()
        }
        let app = launch(language: "en")
        tapKick(app, times: 2)
        snap(app, "counter-2-en")
    }

    /// The largest accessibility text size: tab labels stay 11 pt and the
    /// navigation title is capped (LunaAppearance), so neither is clipped.
    @MainActor
    func testCounterAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-skipOnboarding",
            "-AppleLanguages", "(vi)",
            "-AppleLocale", "vi_VN",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
        app.openTab(.kicks)
        XCTAssertTrue(app.buttons["kickButton"].waitForExistence(timeout: 10))
        snap(app, "ax5-counter-vi-light")
    }

    @MainActor
    func testOnboardingAndSettingsScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()

        // Onboarding screenshots: OnboardingUITests.testOnboardingScreens.
        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let pregnant = app.buttons["onboardingModePregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        next.tap()
        let later = app.buttons["onboardingSkipDate"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()

        app.openTab(.profile)
        // The new "Mode" section sits on top; Form only creates rows near the viewport.
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        let datesRow = app.buttons["settingsPregnancyDates"]
        app.scrollUntilHittable(datesRow)
        XCTAssertTrue(datesRow.waitForExistence(timeout: 5))
        snap(app, "settings")

        datesRow.tap()
        let save = app.buttons["pregnancyDateSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        snap(app, "pregnancy-date-sheet")
        app.segmentedControls["pregnancyDateSourcePicker"].buttons.element(boundBy: 1).tap() // "Kỳ kinh cuối"
        XCTAssertTrue(app.staticTexts["pregnancyEstimatedDue"].waitForExistence(timeout: 5))
        snap(app, "pregnancy-date-sheet-lmp")
        save.tap()
        XCTAssertTrue(app.buttons["settingsPregnancyClear"].waitForExistence(timeout: 5))
        snap(app, "settings-pregnancy-set")

        // Below the viewport now that "Mode" sits on top; Form creates it only once scrolled to.
        let medical = app.buttons["settingsMedicalInfo"]
        app.scrollUntilHittable(medical)
        medical.tap()
        let sources = app.descendants(matching: .any)["medicalSources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
        app.swipeUp()
        snap(app, "medical-sources")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.openTab(.kicks)
        snap(app, "counter-with-week")
    }
}
