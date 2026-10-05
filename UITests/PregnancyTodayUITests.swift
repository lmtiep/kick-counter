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
        XCTAssertTrue(app.navigationBars.staticTexts["Week 24"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.navigationBars.staticTexts["Week 24"].waitForExistence(timeout: 5))
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
