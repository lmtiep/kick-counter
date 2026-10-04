import XCTest

/// Functional checks of trying-to-conceive mode with a pinned clock (2026-10-02)
/// and seeded cycles (see `CycleSeedScenario`).
final class CycleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Spec §8: logging a positive LH test moves the estimated ovulation day.
    @MainActor
    func testPositiveLHTestMovesOvulation() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let fertileCard = app.descendants(matching: .any)["cycleFertileCard"]
        XCTAssertTrue(fertileCard.waitForExistence(timeout: 10))
        // Regular 28-day cycles, cycle day 13: calendar ovulation on 10-04,
        // window 09-29 … 10-05, next period on 10-18. VoiceOver hears spoken dates.
        XCTAssertTrue(fertileCard.label.contains("Estimated ovulation: October 4"), fertileCard.label)
        XCTAssertTrue(fertileCard.label.contains("September 29 – October 5"), fertileCard.label)
        let nextPeriod = app.descendants(matching: .any)["cycleNextPeriodCard"]
        XCTAssertTrue(nextPeriod.label.contains("October 18"), nextPeriod.label)

        let logToday = app.buttons["cycleLogTodayButton"]
        app.scrollUntilHittable(logToday)
        logToday.tap()
        let positive = app.segmentedControls.buttons["Positive"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        positive.tap()
        app.buttons["dayLogSave"].tap()

        // A positive test today (10-02) puts ovulation on the next day.
        waitForLabel(fertileCard, containing: "Estimated ovulation: October 3")
        XCTAssertTrue(fertileCard.label.contains("Based on your positive LH test"), fertileCard.label)
    }

    @MainActor
    func testEmptyCycleTabAddsTheLastPeriod() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "empty")
        let add = app.buttons["cycleAddPeriodButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 2).waitForExistence(timeout: 5))
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: "September") // en_US order: month, day, year
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: "20")
        app.buttons["lastPeriodSave"].tap()

        // 2026-09-20 → 2026-10-02 is cycle day 13.
        let status = app.descendants(matching: .any)["cycleStatusCard"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Day 13 of your cycle"), status.label)
    }

    /// Spec §6: a temperature outside 35.0–38.5 °C is not saved.
    @MainActor
    func testImplausibleTemperatureIsNotSaved() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        let logToday = app.buttons["cycleLogTodayButton"]
        XCTAssertTrue(logToday.waitForExistence(timeout: 10))
        app.scrollUntilHittable(logToday)
        logToday.tap()

        let field = app.textFields["dayLogBBTField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // Clear the seeded "36.3", then type an implausible value.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "40")
        app.buttons["dayLogSave"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["dayLogBBTError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["dayLogSave"].exists) // the sheet stays open
    }

    /// Spec §5/§7: the Calendar tab colours days, reads them out for VoiceOver,
    /// changes month and opens the day log.
    @MainActor
    func testCalendarDaysChangeMonthAndOpenTheDayLog() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        app.openCycleTab(.calendar)
        let title = app.staticTexts["calendarMonthTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "October 2026")

        func day(_ prefix: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier == 'calendarDay' AND label BEGINSWITH %@", prefix)).firstMatch
        }
        // Fertile window 09-29…10-05, ovulation 10-04; a negative LH test was logged on 10-01.
        XCTAssertTrue(day("October 1,").label.contains("fertile window, negative LH test logged"), day("October 1,").label)
        XCTAssertTrue(day("October 2,").label.contains("today, fertile window"), day("October 2,").label)
        XCTAssertTrue(day("October 4,").label.contains("most fertile day"), day("October 4,").label)
        XCTAssertTrue(day("October 18,").label.contains("predicted period"), day("October 18,").label)
        // Future days can be selected to look at, but not logged (spec §4.3).
        day("October 20,").tap()
        let selectedDay = app.descendants(matching: .any)["calendarSelectedDay"]
        waitForLabel(selectedDay, containing: "Oct 20")
        XCTAssertTrue(selectedDay.label.contains("Day 3 · Predicted period"), selectedDay.label)
        XCTAssertTrue(day("October 20,").isSelected)
        XCTAssertFalse(app.buttons["calendarLogButton"].isEnabled)

        app.buttons["calendarNext"].tap()
        waitForLabel(title, containing: "November 2026")
        app.buttons["calendarPrevious"].tap()
        waitForLabel(title, containing: "October 2026")

        day("October 2,").tap()
        let logButton = app.buttons["calendarLogButton"]
        app.scrollUntilHittable(logButton)
        XCTAssertTrue(logButton.isEnabled)
        logButton.tap()
        let positive = app.segmentedControls.buttons["Positive"]
        XCTAssertTrue(positive.waitForExistence(timeout: 5))
        positive.tap()
        app.buttons["dayLogSave"].tap()
        // Ovulation moves from 10-04 to 10-03: today (the day before) becomes a most
        // fertile day and 10-04 drops back to the end of the fertile window.
        waitForLabel(day("October 2,"), containing: "today, most fertile day, positive LH test logged")
        XCTAssertTrue(day("October 4,").label.contains("fertile window"), day("October 4,").label)
    }

    /// Spec §4.3: weeks start on Monday in Vietnamese, Sunday in US English.
    @MainActor
    func testCalendarWeekStartsFollowTheLanguage() {
        for (language, mondayFirst) in [("vi", true), ("en", false)] {
            let app = XCUIApplication.launchPinned(language: language, seedCycles: "fertile")
            app.openCycleTab(.calendar)
            let title = app.staticTexts["calendarMonthTitle"]
            XCTAssertTrue(title.waitForExistence(timeout: 10))
            XCTAssertEqual(title.label, mondayFirst ? "Tháng 10 năm 2026" : "October 2026")
            // October 2026: the 4th is a Sunday, the 5th a Monday.
            let days = app.buttons.matching(identifier: "calendarDay")
            let sunday = days.element(boundBy: 3)
            let monday = days.element(boundBy: 4)
            if mondayFirst {
                XCTAssertGreaterThan(sunday.frame.midX, monday.frame.midX, "Sunday ends the week")
            } else {
                XCTAssertLessThan(sunday.frame.midX, monday.frame.midX, "Sunday starts the week")
            }
            app.terminate()
        }
    }

    /// Spec §2.2: the grid follows the language chosen in the app, not the
    /// device's — Vietnamese chosen in Profile on a US English device starts
    /// the week on Monday and titles the month in Vietnamese.
    @MainActor
    func testCalendarFollowsTheAppLanguageNotTheDevice() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        app.openCycleTab(.profile)
        let vietnamese = app.segmentedControls.buttons["Tiếng Việt"]
        XCTAssertTrue(vietnamese.waitForExistence(timeout: 10))
        vietnamese.tap()
        XCTAssertTrue(app.tabBars.buttons["Lịch"].waitForExistence(timeout: 5))

        app.openCycleTab(.calendar)
        let title = app.staticTexts["calendarMonthTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Tháng 10 năm 2026")
        let days = app.buttons.matching(identifier: "calendarDay")
        XCTAssertGreaterThan(days.element(boundBy: 3).frame.midX, days.element(boundBy: 4).frame.midX, "Sunday ends the week")
        XCTAssertTrue(days.element(boundBy: 0).label.hasPrefix("1 tháng 10"), days.element(boundBy: 0).label)
    }

    /// Spec §8: "I'm pregnant" switches to the Pregnancy tab at the right week.
    @MainActor
    func testImPregnantOpensThePregnancyTabAtTheRightWeek() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "late")
        let button = app.buttons["imPregnantButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        app.scrollUntilHittable(button)
        button.tap()

        // Prefilled with the latest period, 2026-08-31 → due 2027-06-07.
        let estimate = app.staticTexts["pregnancyEstimatedDue"]
        XCTAssertTrue(estimate.waitForExistence(timeout: 5))
        XCTAssertTrue(estimate.label.contains("June 7, 2027"), estimate.label)
        app.buttons["imPregnantSave"].tap()

        // 32 days since the last period: 4 weeks 4 days, on the pregnancy tabs.
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("Week 4 + 4 days"), progress.label)
        XCTAssertTrue(app.tabBars.buttons["Kicks"].waitForExistence(timeout: 5))
    }

    /// Spec §4.3: switching mode in Settings keeps the pregnancy dates.
    @MainActor
    func testSwitchingModeInSettingsKeepsThePregnancyDates() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.profile)
        let tryingToConceive = app.segmentedControls.buttons["Trying to conceive"]
        XCTAssertTrue(tryingToConceive.waitForExistence(timeout: 10))
        tryingToConceive.tap()

        // Settings stays open, now with the cycle section and three tabs.
        XCTAssertTrue(app.descendants(matching: .any)["settingsCycleLength"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settingsPregnancyDates"].exists)
        app.openCycleTab(.today)
        XCTAssertTrue(app.buttons["cycleAddPeriodButton"].waitForExistence(timeout: 5))

        // Back to pregnant: no period logged, so the sheet starts from the stored due date.
        app.openCycleTab(.profile)
        let pregnant = app.segmentedControls.buttons["Pregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 5))
        pregnant.tap()
        let save = app.buttons["imPregnantSave"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        XCTAssertTrue(app.buttons["settingsPregnancyDates"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Kicks"].waitForExistence(timeout: 5))
        app.openTab(.today)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("Week 24 + 3 days"), progress.label)
    }

    /// Cancelling "I'm pregnant" from Settings keeps trying-to-conceive mode.
    @MainActor
    func testCancellingImPregnantFromSettingsKeepsTheMode() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "fertile")
        app.openCycleTab(.profile)
        let pregnant = app.segmentedControls.buttons["Pregnant"]
        XCTAssertTrue(pregnant.waitForExistence(timeout: 10))
        pregnant.tap()
        let cancel = app.navigationBars.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()

        let tryingToConceive = app.segmentedControls.buttons["Trying to conceive"]
        XCTAssertTrue(tryingToConceive.waitForExistence(timeout: 5))
        waitForSelected(tryingToConceive)
        XCTAssertFalse(pregnant.isSelected)
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settingsCycleLength"].exists)
    }

    private func waitForSelected(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let selected = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: element)
        wait(for: [selected], timeout: timeout)
    }
}
