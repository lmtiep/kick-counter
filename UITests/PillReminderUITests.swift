import XCTest

/// Phase 17 spec §5: the daily pill reminder in Profile and on Today. Tracking
/// on the pill with the "fertile" cycles; `-seedPill <type>:<offsetDays>` starts
/// the pack that many days before the pinned today (2026-10-02).
final class PillReminderUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(language: String = "en", contraception: String = "pill", seedPill: String? = nil) -> XCUIApplication {
        XCUIApplication.launchPinned(
            language: language, seedCycles: "fertile", cycleGoal: "tracking", contraception: contraception,
            extraArguments: seedPill.map { ["-seedPill", $0] } ?? []
        )
    }

    @MainActor
    private func card(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["pillTodayCard"]
    }

    /// Profile → "Pill reminder": switch it on, pick a 28-pill pack, and Today
    /// shows pill 1 of 28 (the pack starts today when none was picked).
    @MainActor
    func testSetUpAPackInProfile() {
        let app = launch()
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        XCTAssertFalse(card(app).exists)

        app.openCycleTab(.profile)
        let row = app.buttons["profilePillReminder"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        app.scrollUntilHittable(row, maxSwipes: 8)
        XCTAssertTrue(row.label.contains("Off"), row.label)
        row.tap()

        let toggle = app.switches["pillReminderToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let footnote = app.descendants(matching: .any)["pillMissedFootnote"]
        XCTAssertTrue(footnote.label.contains("follow the leaflet in the pack or ask a doctor or pharmacist"), footnote.label)
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["pillPackType28"].tap()
        waitForLabel(app.staticTexts["pillPackTypeDetail"], containing: "A pill every day")
        XCTAssertTrue(app.descendants(matching: .any)["pillPackStart"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["pillReminderTime"].exists)
        let done = app.buttons["pillReminderDone"]
        app.scrollUntilHittable(done)
        done.tap()

        XCTAssertTrue(row.waitForExistence(timeout: 5))
        waitForLabel(row, containing: "9:00")
        app.openCycleTab(.today)
        let number = app.staticTexts["pillCardNumber"]
        app.scrollUntilHittable(number, maxSwipes: 8)
        XCTAssertEqual(number.label, "Pill 1 of 28")
    }

    /// Today shows "Pill 12/21"; marking it shows the time, and undo brings the button back.
    @MainActor
    func testMarkFromTodayAndUndo() {
        let app = launch(seedPill: "21+7:11")
        let take = app.buttons["pillTakeToday"]
        XCTAssertTrue(take.waitForExistence(timeout: 10))
        app.scrollUntilHittable(take, maxSwipes: 8)
        XCTAssertEqual(app.staticTexts["pillCardNumber"].label, "Pill 12 of 21")
        XCTAssertEqual(take.label, "Taken today")

        take.tap()
        let taken = app.descendants(matching: .any)["pillTakenLabel"]
        XCTAssertTrue(taken.waitForExistence(timeout: 5))
        XCTAssertTrue(taken.label.contains("Taken at"), taken.label)
        XCTAssertFalse(take.exists)

        let undo = app.buttons["pillUndo"]
        XCTAssertTrue(undo.exists)
        undo.tap()
        XCTAssertTrue(take.waitForExistence(timeout: 5))
        XCTAssertFalse(taken.exists)
    }

    /// Day 24 of a 21+7 pack: the break week, with no button.
    @MainActor
    func testBreakWeekShowsTheNewPackDay() {
        let app = launch(language: "vi", seedPill: "21+7:23")
        let breakWeek = app.staticTexts["pillBreakWeek"]
        XCTAssertTrue(breakWeek.waitForExistence(timeout: 10))
        app.scrollUntilHittable(breakWeek, maxSwipes: 8)
        XCTAssertEqual(breakWeek.label, "Tuần nghỉ · vỉ mới bắt đầu ngày 7 thg 10")
        XCTAssertFalse(app.buttons["pillTakeToday"].exists)
        XCTAssertFalse(app.staticTexts["pillCardNumber"].exists)
    }

    /// Another contraception: no Profile row and no Today card, even with a stored pack.
    @MainActor
    func testHiddenWhenTheContraceptionIsNotThePill() {
        let app = launch(contraception: "condom", seedPill: "21+7:11")
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        XCTAssertFalse(card(app).exists)
        app.openCycleTab(.profile)
        let contraception = app.buttons["profileContraception"]
        XCTAssertTrue(contraception.waitForExistence(timeout: 5))
        app.scrollUntilHittable(contraception, maxSwipes: 8)
        XCTAssertFalse(app.buttons["profilePillReminder"].exists)
    }
}
