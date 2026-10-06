import XCTest

/// Phase 5 spec §3.2 and §6: the pregnancy Symptoms screen, its sheet and the safety card.
final class PregnancySymptomsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Contractions → the safety card → the week detail opens at its warnings;
    /// the saved day shows the warning mark.
    @MainActor
    func testContractionsShowTheSafetyCardAndOpenTheWarnings() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        XCTAssertTrue(app.descendants(matching: .any)["symptomsListEmpty"].exists)
        let logToday = app.buttons["symptomsLogToday"]
        XCTAssertEqual(logToday.label, "Log today")
        logToday.tap()

        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["symptomChip-cramps"].exists) // cycle symptoms stay hidden
        let card = app.descendants(matching: .any)["symptomSafetyCard"]
        XCTAssertFalse(card.exists)
        app.scrollUntilHittable(contractions)
        contractions.tap()
        XCTAssertTrue(contractions.isSelected)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let advice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'before week 37'")).firstMatch
        XCTAssertTrue(advice.exists)
        attachScreenshot(app, "symptoms-safety-en")

        let action = app.buttons["symptomSafetyAction"]
        app.scrollUntilHittable(action)
        action.tap()
        let warnings = app.descendants(matching: .any)["weekWarnings"].firstMatch
        XCTAssertTrue(warnings.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["weekDetailTitle"].label, "Week 24")
        let scrolled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: warnings)
        XCTAssertEqual(XCTWaiter().wait(for: [scrolled], timeout: 5), .completed)
        attachScreenshot(app, "week-warnings-en")
        app.buttons["weekDetailClose"].tap()

        // Saved before the week detail opened.
        let summary = app.descendants(matching: .any)["symptomsTodaySummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        waitForLabel(summary, containing: "Contractions")
        XCTAssertEqual(app.buttons["symptomsLogToday"].label, "Edit")
        let row = app.descendants(matching: .any)["symptomDayRow"].firstMatch
        app.scrollUntilHittable(row)
        XCTAssertTrue(row.label.contains("Contractions"), row.label)
        XCTAssertTrue(row.label.contains("A symptom to watch"), row.label)
    }

    /// Swollen feet also shows the card; unselecting every such symptom hides it.
    @MainActor
    func testSwollenFeetShowsTheCardAndUnselectingHidesIt() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let swollen = app.buttons["symptomChip-swollenFeet"]
        XCTAssertTrue(swollen.waitForExistence(timeout: 5))
        app.scrollUntilHittable(swollen)
        swollen.tap()
        let card = app.descendants(matching: .any)["symptomSafetyCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'face or hands'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'before week 37'")).firstMatch.exists)
        swollen.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: card)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed)
    }

    /// Mood and symptoms are saved, listed under their week, and deleted after a confirmation.
    @MainActor
    func testLoggedDayIsListedByWeekAndDeletedAfterConfirming() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openPregnancySymptoms()
        app.buttons["symptomsLogToday"].tap()
        let tired = app.buttons["moodChip-tired"]
        XCTAssertTrue(tired.waitForExistence(timeout: 5))
        tired.tap()
        let nausea = app.buttons["symptomChip-nausea"]
        app.scrollUntilHittable(nausea)
        nausea.tap()
        app.buttons["symptomSave"].tap()

        let row = app.descendants(matching: .any)["symptomDayRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Tired · Nausea"), row.label)
        XCTAssertFalse(row.label.contains("A symptom to watch"), row.label)
        XCTAssertTrue(app.staticTexts["Week 24"].exists)

        app.scrollUntilHittable(row)
        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.confirmDialog("Delete")
        XCTAssertTrue(app.descendants(matching: .any)["symptomsListEmpty"].waitForExistence(timeout: 5))
        waitForLabel(app.descendants(matching: .any)["symptomsTodaySummary"], containing: "Nothing logged yet today")
    }

    /// Spec §6: the screen and the sheet in vi/en × light/dark.
    @MainActor
    func testSymptomsScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            app.openPregnancySymptoms()
            attachScreenshot(app, "symptoms-empty-\(suffix)")
            app.buttons["symptomsLogToday"].tap()
            let calm = app.buttons["moodChip-calm"]
            XCTAssertTrue(calm.waitForExistence(timeout: 5))
            calm.tap()
            for symptom in ["nausea", "backPain", "contractions"] {
                let chip = app.buttons["symptomChip-\(symptom)"]
                app.scrollUntilHittable(chip)
                chip.tap()
            }
            XCTAssertTrue(app.descendants(matching: .any)["symptomSafetyCard"].waitForExistence(timeout: 5))
            // Past the card and the note: a field half under the Save inset already counts as hittable.
            app.scrollUntilHittable(app.buttons["symptomCancel"])
            attachScreenshot(app, "symptoms-sheet-\(suffix)")
            app.buttons["symptomSave"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["symptomDayRow"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "symptoms-list-\(suffix)")
            app.terminate()
        }
    }

    /// Spec §5–6: Dynamic Type AX5 — chips wrap, nothing is cut.
    @MainActor
    func testSymptomsLargestText() {
        let app = XCUIApplication.launchPinned(language: "vi", dueDate: UITestDates.dueAtWeek24, largestText: true)
        let shortcut = app.buttons["shortcutSymptoms"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        app.scrollUntilHittable(shortcut, maxSwipes: 12)
        shortcut.tap()
        let logToday = app.buttons["symptomsLogToday"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 5))
        attachScreenshot(app, "symptoms-vi-ax5")
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let contractions = app.buttons["symptomChip-contractions"]
        XCTAssertTrue(contractions.waitForExistence(timeout: 5))
        app.scrollUntilHittable(contractions, maxSwipes: 12)
        XCTAssertLessThanOrEqual(contractions.frame.maxX, app.windows.firstMatch.frame.maxX)
        contractions.tap()
        let card = app.descendants(matching: .any)["symptomSafetyCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.swipeUp()
        attachScreenshot(app, "symptoms-sheet-vi-ax5")
    }
}
