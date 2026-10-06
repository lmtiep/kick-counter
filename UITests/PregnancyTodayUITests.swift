import XCTest

/// Spec §4.4: the pregnancy Today screen.
final class PregnancyTodayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testWeekProgressUsesTheDesignsWording() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("24 weeks, 3 days"), progress.label)
        XCTAssertTrue(progress.label.contains("Trimester 2 · 109 days to go"), progress.label)
        XCTAssertEqual(app.staticTexts["headerDate"].label, "Oct 2")
    }

    /// Spec §6: tapping the fetus opens the week detail at the current week.
    @MainActor
    func testFetusOpensTheCurrentWeek() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let fetus = app.buttons["fetusHeroButton"]
        XCTAssertTrue(fetus.waitForExistence(timeout: 10))
        XCTAssertEqual(fetus.label, "See week 24")
        fetus.tap()
        XCTAssertTrue(app.staticTexts["weekHeadline"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["weekDetailTitle"].label, "Week 24")
    }

    @MainActor
    func testShortcutsOpenKicksAndTheWeek() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let kicks = app.buttons["shortcutKicks"]
        XCTAssertTrue(kicks.waitForExistence(timeout: 10))
        app.scrollUntilHittable(kicks)
        kicks.tap()
        XCTAssertTrue(app.buttons["kickButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Kicks"].isSelected)

        app.openTab(.today)
        let week = app.buttons["shortcutWeek"]
        app.scrollUntilHittable(week)
        week.tap()
        XCTAssertTrue(app.staticTexts["weekHeadline"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["weekDetailTitle"].label, "Week 24")
    }

    /// Phase 5 spec §3.4: "Symptoms" opens the pregnancy Symptoms screen.
    @MainActor
    func testSymptomsShortcutOpensTheSymptomsScreen() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let shortcut = app.buttons["shortcutSymptoms"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        XCTAssertEqual(shortcut.label, "Symptoms")
        app.scrollUntilHittable(shortcut)
        shortcut.tap()
        XCTAssertTrue(app.descendants(matching: .any)["symptomsTodayCard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    /// Phase 5 spec §3.4: "Weight" and the weight card open the Weight screen.
    @MainActor
    func testWeightShortcutAndCardOpenTheWeightScreen() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let shortcut = app.buttons["shortcutWeight"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        XCTAssertEqual(shortcut.label, "Weight")
        app.scrollUntilHittable(shortcut)
        shortcut.tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Log weight"), card.label) // nothing logged yet
        app.scrollUntilHittable(card)
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["weightSetupCard"].waitForExistence(timeout: 5))
    }

    /// Spec §4.5: chips change the week (scrolled into view), ✕ goes back to Today.
    @MainActor
    func testWeekChipsChangeTheWeekAndCloseReturns() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let fetus = app.buttons["fetusHeroButton"]
        XCTAssertTrue(fetus.waitForExistence(timeout: 10))
        fetus.tap()
        let title = app.staticTexts["weekDetailTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["weekChip-24"].isSelected)
        XCTAssertTrue(app.buttons["weekChip-24"].isHittable) // scrolled to the current week
        let reviewer = app.descendants(matching: .any)["weekReviewer"]
        XCTAssertTrue(reviewer.label.contains("Content pending doctor review"), reviewer.label)

        app.buttons["weekChip-25"].tap()
        waitForLabel(title, containing: "Week 25")
        XCTAssertEqual(app.staticTexts["weekHeadline"].label, "What happens at 25 weeks")

        app.buttons["weekDetailClose"].tap()
        XCTAssertTrue(fetus.waitForExistence(timeout: 5))
        XCTAssertFalse(title.exists)
    }

    @MainActor
    func testAvatarOpensProfile() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        let avatar = app.buttons["headerAvatar"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        avatar.tap()
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected)
    }

    /// From week 28: "Movements today" with nothing counted yet → "Count now" opens Kicks.
    @MainActor
    func testMovementsTodayCardFromWeek28() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek38)
        let card = app.buttons["kickCountCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(card.label.contains("Not counted yet today"), card.label)
        XCTAssertTrue(card.label.contains("Count now"), card.label)
        app.scrollUntilHittable(card)
        card.tap()
        XCTAssertTrue(app.buttons["kickButton"].waitForExistence(timeout: 5))
    }
}
