import XCTest

/// Phase 5 spec §3.3–3.5 and §6: the mother's weight.
final class WeightUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openWeight(_ app: XCUIApplication) {
        let shortcut = app.buttons["shortcutWeight"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        app.scrollUntilHittable(shortcut, maxSwipes: 12)
        shortcut.tap()
    }

    /// Replaces a field's text: taps near its right edge so the cursor lands after
    /// centred text, deletes it, types, then "Done" (decimal pads have no return key).
    @MainActor
    private func type(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        app.scrollUntilHittable(field)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + text)
        app.buttons["keyboardDone"].tap()
    }

    @MainActor
    private func tapSetupSave(_ app: XCUIApplication) {
        let save = app.buttons["weightSetupSave"]
        app.scrollUntilHittable(save)
        save.tap()
    }

    /// Spec §6: set up 52 kg / 160 cm → log 58.0 at week 24 → "In range".
    @MainActor
    func testSetupThenWeek24WeightIsInRange() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
        type("52", into: app.textFields["weightSetupPreWeight"], in: app)
        type("160", into: app.textFields["weightSetupHeight"], in: app)
        tapSetupSave(app)

        let bmi = app.staticTexts["weightBMI"]
        XCTAssertTrue(bmi.waitForExistence(timeout: 5))
        XCTAssertEqual(bmi.label, "BMI 20.3 · Normal")
        XCTAssertFalse(app.descendants(matching: .any)["weightSetupCard"].exists)

        let field = app.textFields["weightKgField"]
        XCTAssertEqual(field.value as? String, "52.0") // starts from the pre-pregnancy weight
        type("58.0", into: field, in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()

        let pill = app.staticTexts["weightStatusPill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertEqual(pill.label, "In range")
        let summary = app.descendants(matching: .any)["weightSummary"]
        XCTAssertTrue(summary.label.contains("+6.0 kg"), summary.label)
        XCTAssertTrue(summary.label.contains("Week 24"), summary.label)
        let row = app.descendants(matching: .any)["weightRow"].firstMatch
        app.scrollUntilHittable(row)
        XCTAssertTrue(row.label.contains("58.0 kg"), row.label)

        app.navigationBars.buttons.firstMatch.tap()
        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.scrollUntilHittable(card)
        XCTAssertTrue(card.label.contains("58.0 kg · +6.0 kg"), card.label)
        XCTAssertTrue(card.label.contains("In range"), card.label)
        XCTAssertFalse(card.label.contains("Talk to your doctor"), card.label)
    }

    /// Spec §6: without a height there is no BMI group, range or status.
    @MainActor
    func testSkippingTheHeightShowsNoRange() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
        type("52", into: app.textFields["weightSetupPreWeight"], in: app)
        tapSetupSave(app)
        XCTAssertTrue(app.staticTexts["weightNoHeightHint"].waitForExistence(timeout: 5))

        type("58.0", into: app.textFields["weightKgField"], in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightRow"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["weightStatusPill"].exists)
        XCTAssertFalse(app.staticTexts["weightBMI"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["weightSummary"].label.contains("+6.0 kg"))

        app.navigationBars.buttons.firstMatch.tap()
        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("58.0 kg · +6.0 kg"), card.label)
        XCTAssertFalse(card.label.contains("range"), card.label)
    }

    /// Spec §5: out-of-range input is not saved and says why under the field.
    @MainActor
    func testImplausibleWeightIsNotSaved() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24, extraArguments: ["-seedWeights"])
        openWeight(app)
        let field = app.textFields["weightKgField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "58.0") // the latest weight (week 24)
        type("250", into: field, in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()
        let error = app.descendants(matching: .any)["weightKgError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("30 to 200 kg"), error.label)
        let newest = app.descendants(matching: .any)["weightRow"].firstMatch
        app.scrollUntilHittable(newest)
        XCTAssertTrue(newest.label.contains("58.0 kg"), newest.label) // nothing new was saved
    }

    /// Above the range at week 38: neutral pill and "Talk to your doctor" on Today.
    @MainActor
    func testAboveRangeAsksToTalkToTheDoctor() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"])
        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollUntilHittable(card)
        // Week 30: 60.9 kg, +8.9 kg, in range.
        XCTAssertTrue(card.label.contains("60.9 kg · +8.9 kg"), card.label)
        XCTAssertTrue(card.label.contains("In range"), card.label)
        card.tap()

        let field = app.textFields["weightKgField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        type("70", into: field, in: app)
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save)
        save.tap()
        let pill = app.staticTexts["weightStatusPill"]
        waitForLabel(pill, containing: "Above range")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        waitForLabel(card, containing: "70.0 kg · +18.0 kg")
        XCTAssertTrue(card.label.contains("Above range"), card.label)
        XCTAssertTrue(card.label.contains("Talk to your doctor at your next visit"), card.label)
    }

    /// The chart and history of the seeded weeks; a swipe deletes after a confirmation.
    @MainActor
    func testSeededHistoryAndDelete() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"])
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightChart"].waitForExistence(timeout: 5))
        let rows = app.descendants(matching: .any).matching(identifier: "weightRow")
        let first = rows.firstMatch
        app.scrollUntilHittable(first)
        XCTAssertTrue(first.label.contains("60.9 kg"), first.label) // newest first
        XCTAssertTrue(app.staticTexts["Week 30"].exists)
        first.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.confirmDialog("Delete")
        waitForLabel(rows.firstMatch, containing: "59.4 kg")
    }

    /// Spec §6: the screen in vi/en × light/dark, the setup card, AX5.
    @MainActor
    func testWeightScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(
                language: language, dark: dark, dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"]
            )
            openWeight(app)
            XCTAssertTrue(app.descendants(matching: .any)["weightChart"].waitForExistence(timeout: 5))
            attachScreenshot(app, "weight-\(suffix)")
            let row = app.descendants(matching: .any)["weightRow"].firstMatch
            app.scrollUntilHittable(row)
            attachScreenshot(app, "weight-history-\(suffix)")
            app.terminate()

            let fresh = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            openWeight(fresh)
            XCTAssertTrue(fresh.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
            attachScreenshot(fresh, "weight-setup-\(suffix)")
            fresh.terminate()
        }
    }

    @MainActor
    func testWeightLargestText() {
        let app = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek38, largestText: true, extraArguments: ["-seedWeights"]
        )
        openWeight(app)
        XCTAssertTrue(app.descendants(matching: .any)["weightSummaryCard"].waitForExistence(timeout: 5))
        attachScreenshot(app, "weight-vi-ax5")
        app.swipeUp()
        attachScreenshot(app, "weight-vi-ax5-chart")
        let save = app.buttons["weightSave"]
        app.scrollUntilHittable(save, maxSwipes: 12)
        attachScreenshot(app, "weight-vi-ax5-entry")
    }
}
