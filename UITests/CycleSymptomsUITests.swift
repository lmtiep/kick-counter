import XCTest

/// Phase 5 spec §3.1 and §6: flow, mood and symptoms in the trying-to-conceive day log.
final class CycleSymptomsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Mood and symptoms logged today show on Today's card and the calendar's day card.
    @MainActor
    func testFlowMoodAndSymptomsShowInBothSummaries() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday)
        logToday.tap()

        let light = app.buttons["flowChip-light"]
        XCTAssertTrue(light.waitForExistence(timeout: 5))
        XCTAssertEqual(light.label, "Light")
        XCTAssertFalse(light.isSelected)
        light.tap()
        XCTAssertTrue(light.isSelected)
        light.tap() // the chosen flow, tapped again, is cleared
        XCTAssertFalse(light.isSelected)
        app.buttons["flowChip-medium"].tap()
        XCTAssertTrue(app.buttons["flowChip-medium"].isSelected)

        let happy = app.buttons["moodChip-happy"]
        app.scrollUntilHittable(happy)
        happy.tap()
        XCTAssertTrue(happy.isSelected)
        let headache = app.buttons["symptomChip-headache"]
        app.scrollUntilHittable(headache)
        headache.tap()
        XCTAssertTrue(headache.isSelected)
        // Only the trying-to-conceive list: no pregnancy symptoms here.
        XCTAssertFalse(app.buttons["symptomChip-nausea"].exists)
        app.buttons["dayLogSave"].tap()
        let closed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: app.buttons["dayLogSave"]
        )
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 5), .completed)

        // Flow · mood · symptom · temperature (the seed logged 36.3 °C and egg white today).
        waitForLabel(logToday, containing: "Flow: Medium · Happy · Headache · 36.3")
        XCTAssertTrue(logToday.label.contains("Egg white"), logToday.label) // cut on screen, read in full
        attachScreenshot(app, "cycle-home-summary-en")

        app.openCycleTab(.calendar)
        let selectedDay = app.descendants(matching: .any)["calendarSelectedDay"]
        XCTAssertTrue(selectedDay.waitForExistence(timeout: 5))
        app.scrollUntilHittable(selectedDay)
        XCTAssertTrue(selectedDay.label.contains("Flow: Medium · Happy · Headache"), selectedDay.label)
        attachScreenshot(app, "calendar-summary-en")
    }

    /// A logged mood and symptom are chosen again when the day is reopened.
    @MainActor
    func testSeededMoodAndSymptomAreSelectedWhenReopened() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let yesterday = app.buttons.matching(
            NSPredicate(format: "identifier == 'stripDay' AND label BEGINSWITH 'October 1,'")
        ).firstMatch
        XCTAssertTrue(yesterday.waitForExistence(timeout: 10))
        yesterday.tap()
        let calm = app.buttons["moodChip-calm"]
        XCTAssertTrue(calm.waitForExistence(timeout: 5))
        XCTAssertTrue(calm.isSelected)
        XCTAssertFalse(app.buttons["moodChip-happy"].isSelected)
        XCTAssertTrue(app.buttons["symptomChip-bloating"].isSelected)
        XCTAssertFalse(app.buttons["flowChip-none"].isSelected)
    }

    /// Clearing every chip of a day that only had flow removes the day's log.
    @MainActor
    func testClearingTheOnlyFlowRemovesTheLog() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "period")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        XCTAssertTrue(logToday.label.contains("Flow: Medium"), logToday.label)
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let medium = app.buttons["flowChip-medium"]
        XCTAssertTrue(medium.waitForExistence(timeout: 5))
        XCTAssertTrue(medium.isSelected)
        medium.tap()
        app.buttons["dayLogSave"].tap()
        waitForLabel(logToday, containing: "Log mood, symptoms and flow")
    }

    /// Spec §5: chips wrap at the largest text size instead of being cut.
    @MainActor
    func testDayLogChipsWrapAtTheLargestTextSize() {
        let app = XCUIApplication.launchPinned(language: "vi", seedCycles: "fertile", largestText: true)
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday, maxSwipes: 12)
        logToday.tap()
        let tender = app.buttons["symptomChip-tenderBreasts"]
        XCTAssertTrue(tender.waitForExistence(timeout: 5))
        app.scrollUntilHittable(tender, maxSwipes: 12)
        XCTAssertLessThanOrEqual(tender.frame.maxX, app.windows.firstMatch.frame.maxX)
        attachScreenshot(app, "day-log-symptoms-vi-ax5")
    }
}
