import XCTest

/// 1.1 spec: questions for the doctor, per appointment, with quick add from Today.
final class QuestionsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func toastText(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any)["toast"].label
    }

    /// No appointment yet: the question stays unassigned, is shown on the list, and the
    /// next appointment created adopts it; it can then be ticked in the editor.
    @MainActor
    func testQuickAddWithoutAppointmentIsAdoptedByTheNextOne() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.quickAddQuestion("Ask about my weight")
        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 5))
        XCTAssertTrue(toastText(app).contains("next appointment"), toastText(app))

        app.openAppointmentsFromToday()
        XCTAssertTrue(app.staticTexts["Saved questions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["questionRow"].exists)

        app.buttons["addAppointmentButton"].tap()
        // The new appointment shows the question it is about to adopt.
        XCTAssertTrue(app.buttons["questionRow"].waitForExistence(timeout: 5))
        app.textFields["appointmentTitleField"].tap()
        app.textFields["appointmentTitleField"].typeText("Check-up")
        app.buttons["appointmentSaveButton"].tap()

        let row = app.appointmentRow(containing: "Check-up")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("0/1 questions asked"), row.label)
        XCTAssertFalse(app.staticTexts["Saved questions"].exists)

        row.tap()
        let question = app.buttons["questionRow"]
        XCTAssertTrue(question.waitForExistence(timeout: 5))
        XCTAssertTrue(question.label.contains("Ask about my weight"), question.label)
        question.tap()
        XCTAssertEqual(question.value as? String, "Done")
        app.buttons["Cancel"].tap()
        let updated = app.appointmentRow(containing: "Check-up")
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        waitForLabel(updated, containing: "1/1 questions asked")
    }

    /// With an upcoming appointment the question goes straight to it.
    @MainActor
    func testQuickAddAttachesToTheNextAppointment() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openAppointmentsFromToday()
        app.addAppointment(titled: "Glucose test")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.quickAddQuestion("Fasting needed?")
        XCTAssertTrue(app.descendants(matching: .any)["toast"].waitForExistence(timeout: 5))
        XCTAssertTrue(toastText(app).contains("Added to your appointment on"), toastText(app))

        app.openAppointmentsFromToday()
        XCTAssertFalse(app.staticTexts["Saved questions"].exists)
        let row = app.appointmentRow(containing: "Glucose test")
        XCTAssertTrue(row.label.contains("0/1 questions asked"), row.label)
    }

    /// Questions are written and removed inside the appointment; deleting the appointment
    /// asks first, says its questions go too, and deletes them.
    @MainActor
    func testDeletingAnAppointmentMentionsAndDeletesItsQuestions() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        app.openAppointmentsFromToday()
        app.addAppointment(titled: "Glucose test")
        app.appointmentRow(containing: "Glucose test").tap()
        app.addQuestionInEditor("First question")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'First question'")).firstMatch.waitForExistence(timeout: 5))
        app.addQuestionInEditor("Second question")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Second question'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        let row = app.appointmentRow(containing: "Glucose test")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        waitForLabel(row, containing: "0/2 questions asked")
        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Its 2 saved questions will be deleted too."].waitForExistence(timeout: 5))
        app.confirmDialog("Delete")
        XCTAssertFalse(app.appointmentRow(containing: "Glucose test").waitForExistence(timeout: 2))

        // Nothing is left behind as an unassigned question.
        XCTAssertFalse(app.staticTexts["Saved questions"].exists)
    }
}
