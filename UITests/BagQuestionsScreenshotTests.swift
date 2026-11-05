import XCTest

/// 1.1 spec: the bag list, the Today card at week 33 and an appointment with questions,
/// in vi light/dark and at AX5.
final class BagQuestionsScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(dark: Bool = false, largestText: Bool = false) -> XCUIApplication {
        XCUIApplication.launchPinned(language: "vi", dark: dark, dueDate: UITestDates.dueAtWeek33, largestText: largestText)
    }

    @MainActor
    private func bagScreens(_ app: XCUIApplication, suffix: String) {
        let card = app.buttons["bagTodayCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollUntilHittable(card, maxSwipes: 10)
        attachScreenshot(app, "bag-today-w33-\(suffix)")
        card.tap()
        XCTAssertTrue(app.staticTexts["bagProgress"].waitForExistence(timeout: 5))
        for id in ["bagItem-cccd", "bagItem-prenatalBook", "bagItem-bhyt"] {
            let item = app.buttons[id]
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            item.tap()
        }
        attachScreenshot(app, "bag-list-\(suffix)")
        let add = app.buttons["bagAdd-baby"]
        app.scrollUntilHittable(add, maxSwipes: 12)
        attachScreenshot(app, "bag-list-lower-\(suffix)")
    }

    @MainActor
    private func questionScreens(_ app: XCUIApplication, suffix: String) {
        app.quickAddQuestion("Khi nào cần đi khám lại?")
        app.openAppointmentsFromToday()
        attachScreenshot(app, "questions-unassigned-\(suffix)")
        app.addAppointment(titled: "Khám thai tuần 33")
        app.appointmentRow(containing: "Khám thai tuần 33").tap()
        XCTAssertTrue(app.buttons["questionRow"].waitForExistence(timeout: 5))
        app.addQuestionInEditor("Em nên ăn gì để kiểm soát đường huyết?")
        app.buttons["questionRow"].firstMatch.tap()
        attachScreenshot(app, "questions-editor-\(suffix)")
        app.buttons["Hủy"].tap()
        attachScreenshot(app, "questions-list-\(suffix)")
    }

    @MainActor
    func testBagAndQuestionScreens() {
        for dark in [false, true] {
            let suffix = UITestVariants.suffix("vi", dark)
            let bag = launch(dark: dark)
            bagScreens(bag, suffix: suffix)
            bag.terminate()
            let questions = launch(dark: dark)
            questionScreens(questions, suffix: suffix)
            questions.terminate()
        }
    }

    @MainActor
    func testBagAndQuestionScreensAtLargestText() {
        let bag = launch(largestText: true)
        bagScreens(bag, suffix: "vi-ax5")
        bag.terminate()
        let questions = launch(largestText: true)
        questionScreens(questions, suffix: "vi-ax5")
    }
}
