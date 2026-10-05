import XCTest

/// Spec §2.2–2.3: three tabs per mode, History inside Kicks, language switch in Profile.
final class NavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEachModeHasThreeTabs() {
        let pregnant = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        XCTAssertTrue(pregnant.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertEqual(pregnant.tabBars.buttons.count, 3)
        XCTAssertTrue(pregnant.tabBars.buttons["Kicks"].exists)
        XCTAssertTrue(pregnant.tabBars.buttons["Profile"].exists)
        pregnant.terminate()

        let cycle = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        XCTAssertTrue(cycle.tabBars.buttons["Today"].waitForExistence(timeout: 10))
        XCTAssertEqual(cycle.tabBars.buttons.count, 3)
        XCTAssertTrue(cycle.tabBars.buttons["Calendar"].exists)
        XCTAssertTrue(cycle.tabBars.buttons["Profile"].exists)
    }

    @MainActor
    func testHistoryOpensFromKicksAndGoesBack() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openHistory()
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons["kickButton"].waitForExistence(timeout: 5))
    }

    /// Spec §6: changing the language in Profile relabels the tabs at once and stays on Profile.
    @MainActor
    func testChangingLanguageInProfileRelabelsTheTabsAtOnce() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let vietnamese = app.segmentedControls.buttons["Tiếng Việt"]
        XCTAssertTrue(vietnamese.waitForExistence(timeout: 10))
        vietnamese.tap()

        let profile = app.tabBars.buttons["Cá nhân"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Hôm nay"].exists)
        XCTAssertTrue(app.tabBars.buttons["Cử động"].exists)
        XCTAssertTrue(profile.isSelected)

        // "System" follows the device again (English here).
        app.segmentedControls.buttons["Theo máy"].tap()
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Kicks"].exists)
    }

    @MainActor
    func testTabBarScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let pregnant = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            pregnant.openTab(.profile)
            XCTAssertTrue(pregnant.segmentedControls.firstMatch.waitForExistence(timeout: 10))
            attachScreenshot(pregnant, "tabs-pregnancy-\(suffix)")
            pregnant.terminate()

            let cycle = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            cycle.openCycleTab(.calendar)
            XCTAssertTrue(cycle.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
            attachScreenshot(cycle, "tabs-cycle-\(suffix)")
            cycle.terminate()
        }
    }
}
