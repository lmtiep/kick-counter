import XCTest

/// 1.2: the new day log kinds, the positive-test offer, and the insights on
/// Cycle history and Today (pinned clock).
final class CycleInsightsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Spotting, sex and a positive test are saved; the positive test offers pregnancy
    /// tracking once; "Later" keeps her in cycle mode and the chips stay chosen.
    @MainActor
    func testNewDayLogKindsAndThePositiveTestOffer() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday)
        logToday.tap()

        let spotting = app.buttons["dayLogSpotting"]
        XCTAssertTrue(spotting.waitForExistence(timeout: 5))
        spotting.tap()
        XCTAssertTrue(spotting.isSelected)
        let protected = app.buttons["dayLogSex-protected"]
        app.scrollUntilHittable(protected)
        protected.tap()
        XCTAssertTrue(protected.isSelected)
        let positive = app.buttons["dayLogPregnancyTest-positive"]
        app.scrollUntilHittable(positive)
        positive.tap()
        app.buttons["dayLogSave"].tap()

        // An alert's button shows up twice in the tree: take the first.
        let later = app.buttons["positiveTestLater"].firstMatch
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        waitForLabel(logToday, containing: "Spotting")

        app.scrollUntilHittable(logToday)
        logToday.tap()
        XCTAssertTrue(app.buttons["dayLogSpotting"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dayLogSpotting"].isSelected)
        app.scrollUntilHittable(app.buttons["dayLogSex-protected"])
        XCTAssertTrue(app.buttons["dayLogSex-protected"].isSelected)
        // Saving again without a change to the test does not offer again.
        app.buttons["dayLogSave"].tap()
        XCTAssertFalse(app.buttons["positiveTestLater"].firstMatch.waitForExistence(timeout: 2))
    }

    /// Four regular cycles with cramps on day 1 and a headache 3 days before each period.
    @MainActor
    func testHistoryAndTodayShowWhatSheOftenNotices() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "patterns")
        let today = app.descendants(matching: .any)["cycleTodayInsight"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertTrue(today.label.contains("have headaches"), today.label)

        let link = app.buttons["cycleHistoryLink"]
        app.scrollUntilHittable(link)
        link.tap()
        let chart = app.descendants(matching: .any)["cycleInsightsChart"]
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        let regularity = app.staticTexts["cycleInsightsRegularity"]
        app.scrollUntilHittable(regularity)
        XCTAssertTrue(regularity.label.contains("fairly regular"), regularity.label)
        let patterns = app.descendants(matching: .any).matching(identifier: "cycleInsightPattern")
        app.scrollUntilHittable(patterns.firstMatch)
        XCTAssertEqual(patterns.count, 2)
        XCTAssertTrue(patterns.element(boundBy: 0).label.contains("have cramps on day 1 of your period (4/4"), patterns.element(boundBy: 0).label)
        XCTAssertTrue(patterns.element(boundBy: 1).label.contains("have headaches about 3 days before your period"), patterns.element(boundBy: 1).label)
        XCTAssertTrue(app.staticTexts["cycleInsightsFootnote"].exists)
        attachScreenshot(app, "cycle-insights-en")
    }
}
