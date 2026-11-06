import XCTest

/// Edit spec 2026-11-06 §Tests: edit a row, add a missed contraction, mark the
/// water broke and see the safety card, delete a marker. Run in CI only.
final class ContractionEditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingARowEditsItAndInvalidInputDisablesSave() {
        let app = XCUIApplication.launchPinned(
            dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedContractions", "511"]
        )
        app.openContractionTimer()
        let row = rows(app).firstMatch
        app.scrollUntilHittable(row)
        row.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForExistence(timeout: 5))

        // Invalid first: a length of 0 s puts the end at the start.
        XCTAssertTrue(app.buttons["contractionEditDuration-Decrement"].waitForExistence(timeout: 5))
        for _ in 0..<12 { app.buttons["contractionEditDuration-Decrement"].tap() }
        XCTAssertTrue(app.descendants(matching: .any)["contractionEditError"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["contractionEditSave"].isEnabled)

        // Then a valid 1:10: the row shows it.
        for _ in 0..<14 { app.buttons["contractionEditDuration-Increment"].tap() }
        XCTAssertFalse(app.descendants(matching: .any)["contractionEditError"].exists)
        let save = app.buttons["contractionEditSave"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForNonExistence(timeout: 5))
        waitForLabel(rows(app).firstMatch, containing: "lasted 1:10", timeout: 15)
    }

    @MainActor
    func testAddsAMissedContraction() {
        let app = XCUIApplication.launchPinned(dueDate: UITestDates.dueAtWeek38)
        app.openContractionTimer()
        let add = app.buttons["contractionAddMissed"]
        app.scrollUntilHittable(add)
        add.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["contractionEditEnd"].exists, "adding takes a start and a length")
        let save = app.buttons["contractionEditSave"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 5))
        waitForLabel(app.descendants(matching: .any)["contractionStatsCount"], containing: "1")
        waitForLabel(rows(app).firstMatch, containing: "lasted 1:00", timeout: 15)
    }

    /// Edit round 2: moving the start of a missed contraction keeps its length (1:00),
    /// so it stays valid and saves as a one-minute contraction.
    @MainActor
    func testAddMissedKeepsItsLengthWhenTheStartMoves() throws {
        let calendar = Calendar.current
        // Contractions run on the real clock. An hour back keeps the added contraction inside the
        // current episode (2 h gap), so its row is on the timer screen; 3 h put it in History.
        let target = Date().addingTimeInterval(-3600)
        try XCTSkipUnless(
            calendar.isDate(target, inSameDayAs: Date()), "an hour ago is yesterday: the day picker would have to change"
        )
        let app = XCUIApplication.launchPinned(dueDate: UITestDates.dueAtWeek38)
        app.openContractionTimer()
        let add = app.buttons["contractionAddMissed"]
        app.scrollUntilHittable(add)
        add.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForExistence(timeout: 5))

        // The time pill opens hour, minute and AM/PM wheels (en_US).
        let timePill = app.datePickers.buttons.matching(NSPredicate(format: "label MATCHES %@", ".*[0-9]:[0-9]{2}.*")).firstMatch
        XCTAssertTrue(timePill.waitForExistence(timeout: 5))
        timePill.tap()
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertEqual(wheels.count, 3, "hour, minute, AM/PM")
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US")
        format.dateFormat = "h"
        let hour = format.string(from: target)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: hour)
        format.dateFormat = "a"
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: format.string(from: target))
        // The popover covers the title: tap the empty part of the sheet below Save and Cancel to close it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
        XCTAssertTrue(app.buttons["contractionEditSave"].waitForExistence(timeout: 5))

        // The length is still 1:00: no error, Save is on.
        XCTAssertFalse(app.descendants(matching: .any)["contractionEditError"].exists)
        XCTAssertTrue(app.buttons["contractionEditDuration-Increment"].label.contains("1:00"), app.buttons["contractionEditDuration-Increment"].label)
        let save = app.buttons["contractionEditSave"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForNonExistence(timeout: 5))
        waitForLabel(rows(app).firstMatch, containing: "lasted 1:00", timeout: 15)
        waitForLabel(rows(app).firstMatch, containing: "Started \(hour):", timeout: 15)
    }

    @MainActor
    func testWaterBrokeShowsTheSafetyCardAndTheMarkerCanBeDeleted() {
        let app = XCUIApplication.launchPinned(dueDate: UITestDates.dueAtWeek38)
        app.openContractionTimer()
        XCTAssertTrue(app.descendants(matching: .any)["contractionSafety"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["contractionWaterBrokeCard"].exists)

        let button = app.buttons["contractionWaterBroke"]
        app.scrollUntilHittable(button)
        button.tap()
        XCTAssertTrue(app.staticTexts["contractionWaterBrokeTitle"].waitForExistence(timeout: 5))
        let save = app.buttons["contractionWaterBrokeSave"]
        XCTAssertTrue(save.isEnabled, "pre-filled with now")
        save.tap()

        let card = app.descendants(matching: .any)["contractionWaterBrokeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("go to the hospital now"), card.label)
        XCTAssertFalse(app.descendants(matching: .any)["contractionSafety"].exists, "the card replaces the plain line")
        XCTAssertFalse(app.buttons["contractionWaterBroke"].exists, "recorded: the button goes")
        let marker = app.descendants(matching: .any)["contractionMarkerRow"]
        app.scrollUntilHittable(app.buttons["contractionMarkerDelete"])
        XCTAssertTrue(marker.exists)

        app.buttons["contractionMarkerDelete"].tap()
        app.confirmDialog("Delete")
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["contractionSafety"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["contractionMarkerRow"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testAMarkerRowOpensItsTimeForEditing() {
        let app = XCUIApplication.launchPinned(dueDate: UITestDates.dueAtWeek38)
        app.openContractionTimer()
        let button = app.buttons["contractionWaterBroke"]
        app.scrollUntilHittable(button)
        button.tap()
        app.buttons["contractionWaterBrokeSave"].tap()
        let marker = app.buttons["contractionMarkerRow"]
        app.scrollUntilHittable(marker)
        marker.tap()
        XCTAssertTrue(app.staticTexts["contractionWaterBrokeTitle"].waitForExistence(timeout: 5))
        app.buttons["contractionWaterBrokeSave"].tap()
        XCTAssertTrue(app.staticTexts["contractionWaterBrokeTitle"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testHistoryEpisodeOpensItsContractionsForEditing() {
        let app = XCUIApplication.launchPinned(
            dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedContractions", "511"]
        )
        app.openContractionTimer()
        let history = app.buttons["contractionHistory"]
        app.scrollUntilHittable(history, maxSwipes: 10)
        history.tap()
        let episode = app.descendants(matching: .any)["contractionEpisodeRow"].firstMatch
        XCTAssertTrue(episode.waitForExistence(timeout: 5))
        episode.tap()
        XCTAssertTrue(app.descendants(matching: .any)["contractionEpisodeDetail"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows(app).count, 3)

        let row = rows(app).firstMatch
        row.tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForExistence(timeout: 5))
        app.buttons["contractionEditDuration-Increment"].tap()
        app.buttons["contractionEditSave"].tap()
        XCTAssertTrue(app.staticTexts["contractionEditTitle"].waitForNonExistence(timeout: 5))
        waitForLabel(rows(app).firstMatch, containing: "lasted 0:45", timeout: 15)
    }

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "contractionRow")
    }
}
