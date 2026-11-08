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
        app.skipBirthDetails()
        app.buttons["pregnancyEndKeepNo"].tap()
        let delete = app.switches["pregnancyEndDeleteData"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertEqual(delete.value as? String, "0", "keeping the data is the default")
        app.buttons["pregnancyEndConfirm"].tap()
        app.closeBirthCelebration()

        assertCycleModeWithoutPregnancyUI(app)
        app.openCycleTab(.profile)
        XCTAssertTrue(app.buttons["profileSwitchToPregnant"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profileMemories"].exists, "no memory was made")
    }

    /// Birth celebration spec §1, §5 and celebration art spec §2, §3: the Today card
    /// from week 37 starts on the birth date step; the baby's details show on the
    /// first page and the summary; "Next" walks every page (no auto-advance in UI
    /// tests), "Done" closes; replaying the memory shows them again.
    @MainActor
    func testBirthFromTodayCardCelebratesAndKeepsAMemory() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38)
        let card = app.descendants(matching: .any)["birthPromptCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.buttons["birthPromptButton"].tap()
        // Straight on the birth branch's date step, not the two choices.
        XCTAssertTrue(app.buttons["pregnancyEndContinue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pregnancyEnd-loss"].exists)
        app.buttons["pregnancyEndContinue"].tap()

        let name = app.textFields["birthDetailsName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Minh An\n")
        let weight = app.textFields["birthDetailsWeight"]
        weight.tap()
        weight.typeText("3.2")
        app.buttons["birthDetailsContinue"].tap()
        app.buttons["pregnancyEndKeepYes"].tap()
        app.buttons["pregnancyEndConfirm"].tap()

        let next = app.buttons["birthCelebrationNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["birthCelebrationClose"].exists)
        XCTAssertTrue(app.staticTexts["Minh An"].exists, "the baby card on the first page")
        var pages = 1
        var sawThanks = false
        while next.exists, pages < 12 {
            let thanks = app.descendants(matching: .any)["birthCelebrationThanks"]
            if thanks.exists {
                sawThanks = true
                XCTAssertTrue(thanks.label.contains("saved in Profile"), thanks.label)
            }
            next.tap()
            pages += 1
        }
        XCTAssertTrue(sawThanks)
        XCTAssertGreaterThanOrEqual(pages, 4, "celebration, journey, thanks and summary at least")
        let done = app.buttons["birthCelebrationDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You and Minh An"].exists, "the summary names the baby")
        XCTAssertTrue(app.buttons["birthCelebrationSave"].exists)
        done.tap()

        assertCycleModeWithoutPregnancyUI(app)
        XCTAssertFalse(app.buttons["birthCelebrationClose"].exists)
        app.openCycleTab(.profile)
        let memories = app.buttons["profileMemories"]
        XCTAssertTrue(memories.waitForExistence(timeout: 5))
        memories.tap()
        let row = app.buttons["memoryRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let replay = app.buttons["memoryReplay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        app.scrollUntilHittable(replay)
        replay.tap()
        XCTAssertTrue(app.buttons["birthCelebrationClose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minh An"].exists, "the details are kept in the memory")
        app.closeBirthCelebration()
    }

    /// The close button works from the first page too.
    @MainActor
    func testCelebrationClosesFromTheFirstPage() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38)
        openEnding(app)
        app.buttons["pregnancyEnd-birth"].tap()
        app.buttons["pregnancyEndContinue"].tap()
        app.skipBirthDetails()
        app.buttons["pregnancyEndKeepNo"].tap()
        app.buttons["pregnancyEndConfirm"].tap()
        XCTAssertTrue(app.buttons["birthCelebrationNext"].waitForExistence(timeout: 10))
        app.closeBirthCelebration()
        assertCycleModeWithoutPregnancyUI(app)
    }

    /// Anti-goal: before week 37 no "it's over" prompt on Today.
    @MainActor
    func testNoBirthCardBeforeWeek37() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek30)
        XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["birthPromptCard"].exists)
    }

    /// Anti-goal: nothing celebratory after "Thai kỳ đã dừng lại".
    @MainActor
    func testLossFromProfileHasNoCelebration() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38)
        openEnding(app)
        app.buttons["pregnancyEnd-loss"].tap()
        app.buttons["pregnancyEndContinue"].tap()
        // A loss is never asked about the baby.
        XCTAssertTrue(app.buttons["pregnancyEndKeepNo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["birthDetailsSkip"].exists)
        app.buttons["pregnancyEndKeepNo"].tap()
        app.buttons["pregnancyEndConfirm"].tap()
        assertCycleModeWithoutPregnancyUI(app)
        XCTAssertFalse(app.buttons["birthCelebrationClose"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["birthCelebrationNext"].exists)
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
        app.skipBirthDetails()
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
        app.skipBirthDetails()
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
