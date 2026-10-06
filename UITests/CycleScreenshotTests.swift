import XCTest

/// Screenshots of trying-to-conceive mode (spec §8), pinned to 2026-10-02.
final class CycleScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let variants = UITestVariants.all

    /// The Cycle tab during a period, in the fertile window, when late, and with irregular cycles.
    @MainActor
    func testCycleHomeScreens() {
        for scenario in ["period", "fertile", "late", "irregular"] {
            for (language, dark) in Self.variants {
                let name = "cycle-home-\(scenario)-\(language)-\(dark ? "dark" : "light")"
                let app = XCUIApplication.launchPinned(language: language, dark: dark, seedCycles: scenario)
                XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10), name)
                attachScreenshot(app, name)
                if !dark {
                    let maybePregnant = app.buttons["cycleMaybePregnantCard"]
                    app.scrollUntilHittable(maybePregnant)
                    attachScreenshot(app, "\(name)-bottom")
                }
                app.terminate()
            }
        }
    }

    /// Spec §5: Dynamic Type AX5 — no text cut off, the ring keeps its size.
    @MainActor
    func testCycleTodayLargestText() {
        for scenario in ["fertile", "late"] {
            let app = XCUIApplication.launchPinned(language: "vi", seedCycles: scenario, largestText: true)
            XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
            attachScreenshot(app, "cycle-home-\(scenario)-vi-ax5")
            app.swipeUp()
            attachScreenshot(app, "cycle-home-\(scenario)-vi-ax5-scrolled")
            app.terminate()
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
            if dark {
                // Shows a selected chip in dark mode (cycleStrong fill, onAccent text).
                let happy = app.buttons["moodChip-happy"]
                XCTAssertTrue(happy.waitForExistence(timeout: 5))
                happy.tap()
                XCTAssertTrue(happy.isSelected)
            }
            attachScreenshot(app, "day-log-\(suffix)")
            let field = app.textFields["dayLogBBTField"]
            // The BBT field is already "hittable" half under Save: scroll to the
            // note below the mucus chips so the whole signals block is shown.
            app.scrollUntilHittable(app.descendants(matching: .any)["dayLogNoteField"])
            attachScreenshot(app, "day-log-signals-\(suffix)")
            if language == "vi", !dark {
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
                let future = app.buttons.matching(
                    NSPredicate(format: "identifier == 'calendarDay' AND label BEGINSWITH '20 tháng 10'")
                ).firstMatch
                future.tap()
                attachScreenshot(app, "calendar-future-day-vi-light")
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
            if !dark {
                app.buttons["imPregnantSourceDue"].tap()
                attachScreenshot(app, "im-pregnant-due-\(suffix)")
                app.buttons["imPregnantDate"].tap()
                XCTAssertTrue(app.datePickers["imPregnantPicker"].waitForExistence(timeout: 5))
                attachScreenshot(app, "im-pregnant-picker-\(suffix)")
                app.buttons[language == "vi" ? "Xong" : "Done"].tap()
            }
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
