import XCTest

/// 1.1: the export screen in vi light/dark and at AX5, and the first page of the PDF.
final class DoctorReportScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let data = ["-seedSessions", "-seedWeights", "-seedContractions", "511"]

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
    func testExportScreen() {
        for dark in [false, true] {
            let app = XCUIApplication.launchPinned(
                language: "vi", dark: dark, dueDate: UITestDates.dueAtWeek24, extraArguments: Self.data
            )
            openReport(app)
            attachScreenshot(app, "report-screen-\(UITestVariants.suffix("vi", dark))")
            app.terminate()
        }
        let large = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek24, largestText: true, extraArguments: Self.data
        )
        openReport(large)
        attachScreenshot(large, "report-screen-vi-ax5")
        large.swipeUp()
        attachScreenshot(large, "report-screen-vi-ax5-scrolled")
        large.terminate()

        let cycle = XCUIApplication.launchPinned(language: "vi", dark: true, seedCycles: "irregular")
        openReport(cycle, cycle: true)
        attachScreenshot(cycle, "report-screen-cycle-vi-dark")
    }

    /// The first page of each PDF, full screen from the preview flag.
    @MainActor
    func testFirstPageOfThePDF() {
        // The last one: the whole pregnancy, which can run to a second page.
        let cases: [(String, Bool, [String], Int)] = [
            ("vi", false, Self.data, 0), ("en", false, Self.data, 0), ("vi", true, [], 0), ("vi", false, Self.data, 2),
        ]
        for (language, cycle, extra, range) in cases {
            let app = XCUIApplication.launchPinned(
                language: language, dueDate: cycle ? nil : UITestDates.dueAtWeek24,
                seedCycles: cycle ? "irregular" : nil, extraArguments: extra + ["-uiTestingReportPreview"]
            )
            openReport(app, cycle: cycle)
            if range > 0 { app.buttons["reportRange-\(range)"].tap() }
            if !cycle {
                let name = app.textFields["reportName"]
                name.tap()
                name.typeText("Nguyen Lan\n")
            }
            let export = app.buttons["reportExport"]
            app.scrollUntilHittable(export)
            export.tap()
            XCTAssertTrue(app.staticTexts["reportPageCount"].waitForExistence(timeout: 20))
            attachScreenshot(app, "report-pdf-\(cycle ? "cycle" : "pregnancy")-\(language)\(range > 0 ? "-whole" : "")")
            app.terminate()
        }
    }
}
