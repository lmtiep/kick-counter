import XCTest

/// 1.1 item 4 (spec §4.1–§4.3): "My pregnancy has ended", both branches, the
/// memory and cancelling at each step.
final class PregnancyEndingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openEnding(_ app: XCUIApplication) {
        app.openTab(.profile)
        let row = app.buttons["profilePregnancyEnded"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["pregnancyEnd-birth"].waitForExistence(timeout: 5))
    }

    /// The cycle tabs, and nothing of the pregnancy left.
    @MainActor
    private func assertCycleModeWithoutPregnancyUI(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Kicks"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["weekProgressCard"].exists)
        XCTAssertFalse(app.buttons["profilePregnancyEnded"].exists)
    }

    @MainActor
    func testLossEndingWithMemory() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek12)
        openEnding(app)
        app.buttons["pregnancyEnd-loss"].tap()
        let opener = app.staticTexts["pregnancyEndOpener"]
        XCTAssertTrue(opener.waitForExistence(timeout: 5))
        XCTAssertTrue(opener.label.hasPrefix("I'm so sorry."), opener.label)
        XCTAssertFalse(app.staticTexts["Congratulations to you and your baby. Wishing you both lots of peace."].exists)
        app.buttons["pregnancyEndContinue"].tap()
        app.buttons["pregnancyEndKeepYes"].tap()
        let field = app.textFields["memoryTitleField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Little star\n")
        app.buttons["pregnancyEndConfirm"].tap()

        // Back on the cycle Today.
        assertCycleModeWithoutPregnancyUI(app)
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)

        app.openCycleTab(.profile)
        let memories = app.buttons["profileMemories"]
        XCTAssertTrue(memories.waitForExistence(timeout: 5))
        memories.tap()
        let row = app.buttons["memoryRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Little star"), row.label)
        row.tap()
        let title = app.staticTexts["memoryDetailTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Little star")
    }

    @MainActor
    func testBirthEndingWithoutMemoryKeepsData() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38)
        openEnding(app)
        app.buttons["pregnancyEnd-birth"].tap()
        let opener = app.staticTexts["pregnancyEndOpener"]
        XCTAssertTrue(opener.waitForExistence(timeout: 5))
        XCTAssertTrue(opener.label.hasPrefix("Congratulations"), opener.label)
        app.buttons["pregnancyEndContinue"].tap()
        app.buttons["pregnancyEndKeepNo"].tap()
        let delete = app.switches["pregnancyEndDeleteData"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertEqual(delete.value as? String, "0", "keeping the data is the default")
        app.buttons["pregnancyEndConfirm"].tap()

        assertCycleModeWithoutPregnancyUI(app)
        app.openCycleTab(.profile)
        XCTAssertTrue(app.buttons["profileSwitchToPregnant"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profileMemories"].exists, "no memory was made")
    }

    @MainActor
    func testCancelAtEachStepChangesNothing() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let cancel = app.buttons["pregnancyEndCancel"]

        // Step 1: the two choices.
        openEnding(app)
        cancel.tap()
        XCTAssertTrue(app.buttons["profilePregnancyEnded"].waitForExistence(timeout: 5))

        // Step 2: the opener and the date.
        openEnding(app)
        app.buttons["pregnancyEnd-loss"].tap()
        XCTAssertTrue(app.buttons["pregnancyEndContinue"].waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["profilePregnancyEnded"].waitForExistence(timeout: 5))

        // Step 3: the keep question, with an answer chosen.
        openEnding(app)
        app.buttons["pregnancyEnd-birth"].tap()
        app.buttons["pregnancyEndContinue"].tap()
        app.buttons["pregnancyEndKeepYes"].tap()
        XCTAssertTrue(app.textFields["memoryTitleField"].waitForExistence(timeout: 5))
        cancel.tap()

        XCTAssertTrue(app.buttons["profilePregnancyEnded"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Kicks"].exists)
        XCTAssertFalse(app.buttons["profileMemories"].exists)
        app.openTab(.today)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("24 weeks, 3 days"), progress.label)
    }

    @MainActor
    func testConfirmNeedsAnAnswer() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        openEnding(app)
        app.buttons["pregnancyEnd-birth"].tap()
        app.buttons["pregnancyEndContinue"].tap()
        let confirm = app.buttons["pregnancyEndConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(confirm.isEnabled)
        app.buttons["pregnancyEndKeepNo"].tap()
        XCTAssertTrue(confirm.isEnabled)
    }

    @MainActor
    func testDeleteMemory() {
        let app = XCUIApplication.launchPinned(language: "en", extraArguments: ["-seedPregnancyEnded", "birth:30"])
        app.openCycleTab(.profile)
        let memories = app.buttons["profileMemories"]
        XCTAssertTrue(memories.waitForExistence(timeout: 10))
        memories.tap()
        let row = app.buttons["memoryRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.staticTexts["memoryDetailTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["memoryNotes"].exists)

        app.buttons["memoryActions"].tap()
        let delete = app.buttons["memoryDelete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        app.confirmDialog("Delete memory")

        // Back on Profile: the row goes with the last memory.
        XCTAssertTrue(app.buttons["profileSwitchToPregnant"].waitForExistence(timeout: 5)
            || app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        if !app.buttons["profileSwitchToPregnant"].exists {
            app.navigationBars.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.buttons["profileSwitchToPregnant"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profileMemories"].exists)
    }

    /// Spec §4.6: someone who onboarded straight into pregnancy has no cycle goal;
    /// ending lands on "Track cycle", never on trying to conceive.
    @MainActor
    func testOnboardedPregnantEndsOnTrackingGoal() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        openEnding(app)
        app.buttons["pregnancyEnd-loss"].tap()
        app.buttons["pregnancyEndContinue"].tap()
        app.buttons["pregnancyEndKeepNo"].tap()
        app.buttons["pregnancyEndConfirm"].tap()
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 10))
        app.openCycleTab(.profile)
        let picker = app.segmentedControls["settingsModePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.buttons["Track cycle"].isSelected)
        XCTAssertFalse(picker.buttons["Trying to conceive"].isSelected)
    }
}
