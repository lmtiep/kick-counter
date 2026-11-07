import XCTest

extension XCUIApplication {
    /// Pregnancy Today → the appointments list, scrolling to the card first.
    @MainActor
    func openAppointmentsFromToday(file: StaticString = #filePath, line: UInt = #line) {
        let card = buttons["nextAppointmentCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), file: file, line: line)
        scrollUntilHittable(card, maxSwipes: 10)
        card.tap()
        XCTAssertTrue(buttons["addAppointmentButton"].waitForExistence(timeout: 5), file: file, line: line)
    }

    /// From the appointments list: adds an appointment titled `title` (tomorrow 9:00 by default).
    @MainActor
    func addAppointment(titled title: String, file: StaticString = #filePath, line: UInt = #line) {
        buttons["addAppointmentButton"].tap()
        let field = textFields["appointmentTitleField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), file: file, line: line)
        field.tap()
        field.typeText(title)
        buttons["appointmentSaveButton"].tap()
        XCTAssertTrue(appointmentRow(containing: title).waitForExistence(timeout: 5), file: file, line: line)
    }

    @MainActor
    func appointmentRow(containing text: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "identifier == 'appointmentRow' AND label CONTAINS %@", text)).firstMatch
    }

    /// In an open appointment editor: writes a question with the add field.
    @MainActor
    func addQuestionInEditor(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let field = textFields["questionField"]
        scrollUntilHittable(field)
        XCTAssertTrue(field.waitForExistence(timeout: 5), file: file, line: line)
        field.tap()
        field.typeText(text)
        buttons["questionAdd"].tap()
    }

    /// Quick-adds a question from pregnancy Today.
    @MainActor
    func quickAddQuestion(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let card = buttons["quickQuestionCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), file: file, line: line)
        scrollUntilHittable(card, maxSwipes: 12)
        card.tap()
        let field = textFields["quickQuestionField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), file: file, line: line)
        field.tap()
        field.typeText(text)
        buttons["quickQuestionSave"].tap()
    }
}
