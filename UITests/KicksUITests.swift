import XCTest

/// Spec §4.6: the Kicks screen.
final class KicksUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func tapKick(_ app: XCUIApplication, times: Int) {
        let kick = app.buttons["kickButton"]
        XCTAssertTrue(kick.waitForExistence(timeout: 10))
        for _ in 0..<times {
            kick.tap()
            Thread.sleep(forTimeInterval: 0.6) // stay above the 0.5 s debounce
        }
    }

    @MainActor
    func testHeaderShowsTheWeekAndTheGoal() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.kicks)
        let subtitle = app.staticTexts["counterSubtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 10))
        XCTAssertEqual(subtitle.label, "Week 24 · count to 10 movements")
        XCTAssertEqual(app.buttons["kickButton"].value as? String, "0 of 10 movements")
        XCTAssertEqual(app.buttons["kickReminderPill"].label, "Reminder: off")
    }

    /// The first tap starts the session and counts 1; undo and the kick times appear.
    @MainActor
    func testCountingShowsUndoEndAndKickTimes() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.kicks)
        tapKick(app, times: 2)
        let kick = app.buttons["kickButton"]
        let two = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "2 of 10 movements"), object: kick)
        XCTAssertEqual(XCTWaiter().wait(for: [two], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["undoButton"].isEnabled)
        XCTAssertTrue(app.buttons["cancelSessionButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["kickTimes"].exists)
    }

    @MainActor
    func testSettingsSheetHasRemindersHapticsAndTheFixedGoal() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openTab(.kicks)
        let settings = app.buttons["kickSettingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        let haptics = app.switches["kickSettingsHapticsToggle"]
        XCTAssertTrue(haptics.waitForExistence(timeout: 5))
        XCTAssertEqual(haptics.value as? String, "1") // on by default
        haptics.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: haptics)
        XCTAssertEqual(XCTWaiter().wait(for: [off], timeout: 5), .completed)
        XCTAssertTrue(app.switches["kickSettingsReminderToggle"].exists)
        let goal = app.descendants(matching: .any)["kickSettingsGoal"]
        XCTAssertTrue(goal.label.contains("10"), goal.label)
        XCTAssertTrue(goal.label.contains("The Cardiff method"), goal.label)

        // The sheet opens at the medium detent; the Done button may sit below it.
        let done = app.buttons["kickSettingsDone"]
        app.scrollUntilHittable(done)
        done.tap()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertFalse(haptics.exists)
    }

    /// Spec §4.6: over 2 hours without 10 — the warning card; "Call 115" only in Vietnamese.
    @MainActor
    func testOverdueCardOffersTheEmergencyNumberOnlyInVietnamese() {
        let vietnamese = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedOverdueSession"]
        )
        vietnamese.openTab(.kicks)
        XCTAssertTrue(vietnamese.descendants(matching: .any)["overdueCard"].waitForExistence(timeout: 10))
        let call = vietnamese.buttons["overdueCallButton"]
        vietnamese.scrollUntilHittable(call)
        XCTAssertEqual(call.label, "Gọi cấp cứu 115")
        vietnamese.terminate()

        let english = XCUIApplication.launchPinned(
            language: "en", dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedOverdueSession"]
        )
        english.openTab(.kicks)
        XCTAssertTrue(english.descendants(matching: .any)["overdueCard"].waitForExistence(timeout: 10))
        XCTAssertFalse(english.buttons["overdueCallButton"].exists)
        XCTAssertEqual(english.buttons["kickButton"].value as? String, "4 of 10 movements")
    }

    @MainActor
    func testKicksScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek38)
            app.openTab(.kicks)
            XCTAssertTrue(app.buttons["kickButton"].waitForExistence(timeout: 10))
            attachScreenshot(app, "kicks-idle-\(suffix)")
            tapKick(app, times: 3)
            attachScreenshot(app, "kicks-running-\(suffix)")
            if !dark {
                let cardiff = app.descendants(matching: .any)["kicksCardiffCard"]
                app.scrollUntilHittable(cardiff)
                // The card can count as hittable under the floating tab bar.
                app.swipeUp()
                attachScreenshot(app, "kicks-bottom-\(suffix)")
            }
            app.terminate()

            let overdue = XCUIApplication.launchPinned(
                language: language, dark: dark, dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedOverdueSession"]
            )
            overdue.openTab(.kicks)
            let card = overdue.descendants(matching: .any)["overdueCard"]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            overdue.scrollUntilHittable(card)
            attachScreenshot(overdue, "kicks-overdue-\(suffix)")
            if !dark {
                overdue.swipeDown()
                overdue.buttons["kickSettingsButton"].tap()
                XCTAssertTrue(overdue.switches["kickSettingsHapticsToggle"].waitForExistence(timeout: 5))
                attachScreenshot(overdue, "kick-settings-\(suffix)")
            }
            overdue.terminate()
        }
    }
}
