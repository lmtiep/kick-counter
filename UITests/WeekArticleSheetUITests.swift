import XCTest

/// Phase 6 spec §3 and §6: the week detail's article sheet.
final class WeekArticleSheetUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Today (week 24) → fetus → week detail.
    @MainActor
    private func openWeek24(language: String = "en", largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: language, dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        let fetus = app.buttons["fetusHeroButton"]
        XCTAssertTrue(fetus.waitForExistence(timeout: 10))
        fetus.tap()
        XCTAssertTrue(app.buttons["weekSheetHandle"].waitForExistence(timeout: 5))
        return app
    }

    /// §3.4: opens at peek on the Bé tab; the chips stay reachable above the sheet.
    @MainActor
    func testOpensAtPeekOnTheBabyTab() {
        let app = openWeek24()
        XCTAssertEqual(app.buttons["weekSheetHandle"].label, "Expand article")
        XCTAssertEqual(app.staticTexts["weekDetailTitle"].label, "Week 24")
        XCTAssertTrue(app.buttons["weekTab-baby"].isSelected)
        XCTAssertFalse(app.buttons["weekTab-mom"].isSelected)
        XCTAssertTrue(app.buttons["weekChip-24"].isHittable)
        XCTAssertTrue(app.staticTexts["weekArticleLead"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["weekWarnings"].exists)
    }

    /// §3.3: tapping the handle expands the sheet and changes its label; tapping again collapses it.
    @MainActor
    func testHandleTogglesTheDetent() {
        let app = openWeek24()
        let handle = app.buttons["weekSheetHandle"]
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        XCTAssertFalse(app.buttons["weekChip-24"].exists) // hidden under the expanded sheet
        handle.tap()
        waitForLabel(handle, containing: "Expand article")
        XCTAssertTrue(app.buttons["weekChip-24"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["weekChip-24"].isHittable)
    }

    /// §4.3: the Mẹ tab holds the warnings.
    @MainActor
    func testMomTabShowsTheWarnings() {
        let app = openWeek24()
        app.buttons["weekTab-mom"].tap()
        XCTAssertTrue(app.buttons["weekTab-mom"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your body this week"].exists)
        XCTAssertFalse(app.staticTexts["weekArticleLead"].exists)
    }

    /// §3.5: a chip changes the week; the tab and the detent are kept.
    @MainActor
    func testChangingWeekKeepsTheTabAndDetent() {
        let app = openWeek24()
        app.buttons["weekTab-mom"].tap()
        app.buttons["weekChip-25"].tap()
        waitForLabel(app.staticTexts["weekDetailTitle"], containing: "Week 25")
        XCTAssertTrue(app.buttons["weekTab-mom"].isSelected)
        XCTAssertEqual(app.buttons["weekSheetHandle"].label, "Expand article")
        XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
    }

    /// §3.5: pulling down on the expanded article at its top hands the drag to the sheet.
    @MainActor
    func testPullingDownAtTheTopOfTheArticleCollapses() {
        let app = openWeek24()
        let handle = app.buttons["weekSheetHandle"]
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        app.scrollViews["weekArticleScroll"].swipeDown()
        waitForLabel(handle, containing: "Expand article")
    }

    /// §3.6: from the symptoms safety card the sheet is expanded, on Mẹ, at the warnings.
    @MainActor
    func testSafetyCardOpensTheWarningsExpanded() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        app.scrollUntilHittable(contractions)
        contractions.tap()
        let action = app.buttons["symptomSafetyAction"]
        app.scrollUntilHittable(action)
        action.tap()

        let handle = app.buttons["weekSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.label, "Collapse article")
        XCTAssertTrue(app.buttons["weekTab-mom"].isSelected)
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        let inView = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: warnings)
        XCTAssertEqual(XCTWaiter().wait(for: [inView], timeout: 5), .completed)
    }

    /// §3.4: accessibility text sizes open the sheet expanded.
    @MainActor
    func testLargestTextOpensExpanded() {
        let app = openWeek24(largestText: true)
        waitForLabel(app.buttons["weekSheetHandle"], containing: "Collapse article")
    }
}
