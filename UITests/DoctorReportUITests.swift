import XCTest

/// 1.1: Profile → "Report for your doctor".
final class DoctorReportUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let pregnancyData = ["-seedSessions", "-seedWeights", "-seedContractions", "511"]

    @MainActor
    private func openReport(_ app: XCUIApplication, cycle: Bool = false) {
        if cycle { app.openCycleTab(.profile) } else { app.openTab(.profile) }
        let row = app.descendants(matching: .any)["profileDoctorReport"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        app.scrollUntilHittable(row, maxSwipes: 12)
        row.tap()
        XCTAssertTrue(app.staticTexts["reportIntro"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testTheScreenOpensWithEveryRangeAndSectionOn() {
        let app = XCUIApplication.launchPinned(
            language: "en", dueDate: UITestDates.dueAtWeek24, extraArguments: Self.pregnancyData
        )
        openReport(app)
        for kind in ["kicks", "contractions", "weights", "symptoms", "appointments"] {
            let toggle = app.switches["reportSection-\(kind)"]
            XCTAssertTrue(toggle.exists, kind)
            XCTAssertEqual(toggle.value as? String, "1", kind)
        }
        XCTAssertTrue(app.buttons["reportRange-0"].exists)
        XCTAssertTrue(app.buttons["reportRange-1"].exists)
        XCTAssertTrue(app.buttons["reportRange-2"].exists)
        XCTAssertFalse(app.buttons["reportRange-3"].exists)
        XCTAssertTrue(app.buttons["reportRange-0"].isSelected)
        XCTAssertTrue(app.buttons["reportExport"].isEnabled)
        XCTAssertFalse(app.staticTexts["reportEmptyHint"].exists)
    }

    @MainActor
    func testTogglesAndRangeChange() {
        let app = XCUIApplication.launchPinned(
            language: "en", dueDate: UITestDates.dueAtWeek24, extraArguments: Self.pregnancyData
        )
        openReport(app)
        let kicks = app.switches["reportSection-kicks"]
        kicks.switches.firstMatch.tap()
        XCTAssertEqual(kicks.value as? String, "0")
        kicks.switches.firstMatch.tap()
        XCTAssertEqual(kicks.value as? String, "1")
        app.buttons["reportRange-2"].tap()
        XCTAssertTrue(app.buttons["reportRange-2"].isSelected)
        XCTAssertFalse(app.buttons["reportRange-0"].isSelected)
    }

    /// With nothing recorded there is nothing to print: the button is off and says why.
    @MainActor
    func testWithoutRecordsExportIsOffAndTheHintShows() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24)
        openReport(app)
        XCTAssertTrue(app.staticTexts["reportEmptyHint"].exists)
        XCTAssertFalse(app.buttons["reportExport"].isEnabled)
    }

    @MainActor
    func testExportShowsTheShareSheet() {
        let app = XCUIApplication.launchPinned(
            language: "en", dueDate: UITestDates.dueAtWeek24, extraArguments: Self.pregnancyData
        )
        openReport(app)
        let name = app.textFields["reportName"]
        name.tap()
        name.typeText("Lan\n")
        let export = app.buttons["reportExport"]
        app.scrollUntilHittable(export)
        export.tap()
        let sheet = app.descendants(matching: .any)["backupShareSheet"]
        let activityList = app.otherElements["ActivityListView"]
        let appeared = XCTWaiter().wait(for: [
            XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in sheet.exists || activityList.exists }, object: nil),
        ], timeout: 20)
        XCTAssertEqual(appeared, .completed, "the share sheet did not appear")
    }

    /// The preview flag writes the PDF and reports its page count.
    @MainActor
    func testThePregnancyPDFHasAtLeastOnePage() {
        let app = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek24,
            extraArguments: Self.pregnancyData + ["-uiTestingReportPreview"]
        )
        openReport(app)
        let export = app.buttons["reportExport"]
        app.scrollUntilHittable(export)
        export.tap()
        XCTAssertTrue(pageCount(app) >= 1)
    }

    /// A note longer than the room left on a page continues on the next page (nothing is lost).
    @MainActor
    func testALongAppointmentNoteRunsOverToASecondPage() {
        let app = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek24,
            extraArguments: Self.pregnancyData + ["-uiTestingReportPreview", "-uiTestingReportLongNote"]
        )
        openReport(app)
        let export = app.buttons["reportExport"]
        app.scrollUntilHittable(export)
        export.tap()
        XCTAssertTrue(pageCount(app) >= 2)
    }

    @MainActor
    func testTheCycleReportHasTwoRangesAndAPDF() {
        let app = XCUIApplication.launchPinned(
            language: "en", seedCycles: "irregular", extraArguments: ["-uiTestingReportPreview"]
        )
        openReport(app, cycle: true)
        for kind in ["periods", "cycleLengths", "moodsAndSymptoms", "bbtAndLH"] {
            XCTAssertTrue(app.switches["reportSection-\(kind)"].exists, kind)
        }
        XCTAssertTrue(app.buttons["reportRange-1"].exists)
        XCTAssertFalse(app.buttons["reportRange-2"].exists)
        let export = app.buttons["reportExport"]
        app.scrollUntilHittable(export)
        export.tap()
        XCTAssertTrue(pageCount(app) >= 1)
    }

    @MainActor
    private func pageCount(_ app: XCUIApplication) -> Int {
        let label = app.staticTexts["reportPageCount"]
        XCTAssertTrue(label.waitForExistence(timeout: 20))
        return Int(label.label.replacingOccurrences(of: "pages: ", with: "")) ?? 0
    }
}
