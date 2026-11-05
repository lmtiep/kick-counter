import XCTest

/// 1.1 spec: the hospital bag. The built-in list has 31 items (`BagCatalog`).
final class BagChecklistUITests: XCTestCase {
    private let total = 31

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openBagFromToday(_ app: XCUIApplication) {
        let card = app.buttons["bagTodayCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollUntilHittable(card, maxSwipes: 10)
        XCTAssertTrue(card.label.contains("Hospital bag · 0/\(total)"), card.label)
        card.tap()
        XCTAssertTrue(app.staticTexts["bagProgress"].waitForExistence(timeout: 5))
    }

    private func progress(_ app: XCUIApplication) -> String {
        app.staticTexts["bagProgress"].label
    }

    /// Tick, add her own item, hide a built-in, show it again, reset.
    @MainActor
    func testTickAddHideAndReset() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek33)
        openBagFromToday(app)
        XCTAssertEqual(progress(app), "0 of \(total) packed")

        let cccd = app.buttons["bagItem-cccd"]
        XCTAssertTrue(cccd.waitForExistence(timeout: 5))
        XCTAssertEqual(cccd.value as? String, "Not done")
        cccd.tap()
        waitForLabel(app.staticTexts["bagProgress"], containing: "1 of \(total) packed")
        XCTAssertEqual(cccd.value as? String, "Done")

        // Her own item goes to the end of its group and counts.
        let add = app.buttons["bagAdd-mother"]
        app.scrollUntilHittable(add)
        add.tap()
        let field = app.textFields["bagAddField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Pillow")
        app.buttons["bagAddSave"].tap()
        let pillow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pillow'")).firstMatch
        app.scrollUntilHittable(pillow)
        XCTAssertTrue(pillow.exists)
        waitForLabel(app.staticTexts["bagProgress"], containing: "1 of \(total + 1) packed")
        pillow.tap()
        waitForLabel(app.staticTexts["bagProgress"], containing: "2 of \(total + 1) packed")

        // Hide a built-in: it leaves the list and the count; the menu brings it back.
        let cash = app.buttons["bagItem-cash"]
        app.scrollDownUntilHittable(cash, maxSwipes: 10)
        cash.swipeLeft()
        app.buttons["Hide"].firstMatch.tap()
        XCTAssertTrue(waitForDisappearance(cash))
        waitForLabel(app.staticTexts["bagProgress"], containing: "2 of \(total) packed")
        app.buttons["bagMenu"].tap()
        app.buttons["bagUnhide"].tap()
        XCTAssertTrue(app.buttons["bagItem-cash"].waitForExistence(timeout: 5))
        waitForLabel(app.staticTexts["bagProgress"], containing: "2 of \(total + 1) packed")

        // Reset unticks everything but keeps her own item.
        app.buttons["bagMenu"].tap()
        app.buttons["bagReset"].tap()
        app.confirmDialog("Untick all")
        waitForLabel(app.staticTexts["bagProgress"], containing: "0 of \(total + 1) packed")
        XCTAssertTrue(app.buttons["bagItem-cccd"].exists)

        // The Today card shows the same count.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.buttons["bagTodayCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("0/\(total + 1)"), card.label)
    }

    /// The Today card appears from week 32; the Profile row works in any week.
    @MainActor
    func testProfileRowOpensTheBagBeforeWeek32() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        XCTAssertTrue(app.buttons["shortcutKicks"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["bagTodayCard"].exists)
        app.openTab(.profile)
        let row = app.buttons["profileBag"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row)
        row.tap()
        XCTAssertTrue(app.staticTexts["bagProgress"].waitForExistence(timeout: 5))
        XCTAssertEqual(progress(app), "0 of \(total) packed")
    }

    @MainActor
    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }
}
