import XCTest

/// Screenshots of trying-to-conceive mode (spec §8), pinned to 2026-10-02.
final class CycleScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let variants = [("vi", false), ("vi", true), ("en", false)]

    /// The Cycle tab during a period, in the fertile window, when late, and with irregular cycles.
    @MainActor
    func testCycleHomeScreens() {
        for scenario in ["period", "fertile", "late", "irregular"] {
            for (language, dark) in Self.variants {
                let name = "cycle-home-\(scenario)-\(language)-\(dark ? "dark" : "light")"
                let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: scenario)
                XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10), name)
                attachScreenshot(app, name)
                if language == "vi", !dark {
                    let logToday = app.buttons["cycleLogTodayButton"]
                    app.scrollUntilHittable(logToday)
                    attachScreenshot(app, "\(name)-bottom")
                }
                app.terminate()
            }
        }
    }

    @MainActor
    func testEmptyCycleScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "empty")
            let add = app.buttons["cycleAddPeriodButton"]
            XCTAssertTrue(add.waitForExistence(timeout: 10))
            attachScreenshot(app, "cycle-empty-\(suffix)")
            if language == "vi", !dark {
                add.tap()
                XCTAssertTrue(app.buttons["lastPeriodSave"].waitForExistence(timeout: 5))
                attachScreenshot(app, "last-period-sheet-vi")
            }
            app.terminate()
        }
    }

    /// The day log sheet for today in the fertile scenario (BBT, mucus already logged).
    @MainActor
    func testDayLogScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            let logToday = app.buttons["cycleLogTodayButton"]
            XCTAssertTrue(logToday.waitForExistence(timeout: 10))
            app.scrollUntilHittable(logToday)
            logToday.tap()
            XCTAssertTrue(app.buttons["dayLogSave"].waitForExistence(timeout: 5))
            attachScreenshot(app, "day-log-\(suffix)")
            if language == "vi", !dark {
                let field = app.textFields["dayLogBBTField"]
                field.tap()
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6) + "34")
                app.buttons["dayLogSave"].tap()
                XCTAssertTrue(app.descendants(matching: .any)["dayLogBBTError"].waitForExistence(timeout: 5))
                attachScreenshot(app, "day-log-bbt-error-vi")
            }
            app.terminate()
        }
    }

    @MainActor
    func testCalendarScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            app.openCycleTab(.calendar)
            XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
            attachScreenshot(app, "calendar-fertile-\(suffix)")
            if language == "vi", !dark {
                app.buttons["calendarNext"].tap()
                attachScreenshot(app, "calendar-next-month-vi-light")
                app.buttons["calendarPrevious"].tap()
                let legend = app.descendants(matching: .any)["calendarLegend"]
                app.scrollUntilHittable(legend)
                attachScreenshot(app, "calendar-legend-vi-light")
            }
            app.terminate()
        }
        for scenario in ["period", "irregular"] {
            let app = XCUIApplication.launchPinned(language: "vi", seedCycles: scenario)
            app.openCycleTab(.calendar)
            XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
            attachScreenshot(app, "calendar-\(scenario)-vi-light")
            app.terminate()
        }
    }

    @MainActor
    func testImPregnantScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "late")
            let button = app.buttons["imPregnantButton"]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            app.scrollUntilHittable(button)
            button.tap()
            XCTAssertTrue(app.buttons["imPregnantSave"].waitForExistence(timeout: 5))
            attachScreenshot(app, "im-pregnant-\(suffix)")
            if language == "vi", !dark {
                app.buttons["imPregnantSave"].tap()
                XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 10))
                attachScreenshot(app, "im-pregnant-after-vi-light")
            }
            app.terminate()
        }
    }

    @MainActor
    func testSettingsScreens() {
        for (language, dark) in Self.variants {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: "fertile")
            app.openCycleTab(.profile)
            XCTAssertTrue(app.descendants(matching: .any)["settingsCycleLength"].waitForExistence(timeout: 10))
            attachScreenshot(app, "settings-ttc-\(suffix)")
            if language == "vi", !dark {
                let medical = app.buttons["settingsMedicalInfo"]
                app.scrollUntilHittable(medical)
                medical.tap()
                let ttc = app.descendants(matching: .any)["medicalTTC"]
                XCTAssertTrue(ttc.waitForExistence(timeout: 5))
                app.scrollUntilHittable(ttc)
                attachScreenshot(app, "medical-ttc-vi")
            }
            app.terminate()
        }
    }
}
