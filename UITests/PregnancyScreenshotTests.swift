import XCTest

/// Screenshots of the Pregnancy tab at fixed gestational ages (see `UITestDates`).
final class PregnancyScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let homeWeeks = [
        ("12", UITestDates.dueAtWeek12),
        ("24", UITestDates.dueAtWeek24),
        ("38", UITestDates.dueAtWeek38),
    ]

    @MainActor
    func testPregnancyHomeScreens() {
        for (week, dueDate) in Self.homeWeeks {
            for language in ["vi", "en"] {
                for dark in [false, true] {
                    let name = "pregnancy-home-\(week)-\(language)-\(dark ? "dark" : "light")"
                    let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: dueDate)
                    XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 10), name)
                    attachScreenshot(app, name)
                    if !dark {
                        let appointment = app.buttons["nextAppointmentCard"]
                        app.scrollUntilHittable(appointment)
                        if week == "38" { XCTAssertTrue(app.buttons["kickCountCard"].exists) }
                        attachScreenshot(app, "\(name)-bottom")
                    }
                    app.terminate()
                }
            }
        }
    }

    /// Phase 5: Today's four shortcuts and the weight card with sample weights.
    @MainActor
    func testPregnancyHomeWeightCard() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(
                language: language, dark: dark, dueDate: UITestDates.dueAtWeek38, extraArguments: ["-seedWeights"]
            )
            let card = app.buttons["weightCard"]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            app.scrollUntilHittable(card)
            attachScreenshot(app, "pregnancy-home-weight-\(suffix)")
            app.terminate()
        }
    }

    /// Phase 5: the weight card at AX5 — the pill under the figures, nothing cut off.
    @MainActor
    func testPregnancyHomeWeightCardLargestText() {
        let app = XCUIApplication.launchPinned(
            language: "vi", dueDate: UITestDates.dueAtWeek38, largestText: true, extraArguments: ["-seedWeights"]
        )
        let card = app.buttons["weightCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        app.scrollUntilHittable(card, maxSwipes: 12)
        app.swipeUp() // the pill sits under the figures, below the tab bar otherwise
        attachScreenshot(app, "pregnancy-home-weight-vi-ax5")
    }

    /// Spec §5: Dynamic Type AX5 — nothing cut off.
    @MainActor
    func testPregnancyTodayLargestText() {
        let app = XCUIApplication.launchPinned(language: "vi", dueDate: UITestDates.dueAtWeek38, largestText: true)
        XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 10))
        attachScreenshot(app, "pregnancy-home-38-vi-ax5")
        app.swipeUp()
        attachScreenshot(app, "pregnancy-home-38-vi-ax5-scrolled")
        app.swipeUp()
        attachScreenshot(app, "pregnancy-home-38-vi-ax5-bottom")
    }

    @MainActor
    func testPastDueScreen() {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueSevenDaysAgo)
        let progress = app.descendants(matching: .any)["weekProgressCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertTrue(progress.label.contains("Days past your due date: 7"), progress.label)
        // Week 41 reuses week 40's Hadlock weight and says the standard ends at 40.
        let babyCard = app.buttons["babySizeCard"]
        XCTAssertTrue(babyCard.waitForExistence(timeout: 5))
        XCTAssertTrue(babyCard.label.contains("Hadlock's standard ends at week 40"), babyCard.label)
        attachScreenshot(app, "pregnancy-home-pastdue-en")
    }

    /// Weeks 7–13 show the Hadlock crown–rump length in mm next to the weight range.
    @MainActor
    func testWeek12DetailScreens() {
        for language in ["vi", "en"] {
            let app = XCUIApplication.launchPinned(language: language, dueDate: UITestDates.dueAtWeek12)
            let babyCard = app.buttons["babySizeCard"]
            XCTAssertTrue(babyCard.waitForExistence(timeout: 10))
            if language == "en" {
                XCTAssertTrue(babyCard.label.contains("Crown–rump length"), babyCard.label)
                XCTAssertTrue(babyCard.label.contains("About 53.5"), babyCard.label)
                XCTAssertTrue(babyCard.label.contains("typically 48 to 68"), babyCard.label)
            }
            app.scrollUntilHittable(babyCard)
            babyCard.tap()
            XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "week-12-\(language)-light")
            app.terminate()
        }
    }

    @MainActor
    func testWeekDetailScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = UITestVariants.suffix(language, dark)
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            let babyCard = app.buttons["babySizeCard"]
            XCTAssertTrue(babyCard.waitForExistence(timeout: 10))
            app.scrollUntilHittable(babyCard)
            babyCard.tap()
            XCTAssertTrue(app.descendants(matching: .any)["weekWarnings"].firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(app, "week-24-\(suffix)")
            app.swipeUp()
            attachScreenshot(app, "week-24-warnings-\(suffix)")
            if language == "vi", !dark {
                app.swipeDown()
                app.swipeDown()
                app.buttons["weekChip-25"].tap()
                waitForLabel(app.staticTexts["weekDetailTitle"], containing: "Tuần 25")
                attachScreenshot(app, "week-25-vi-light")
            }
            app.terminate()
        }
    }

    @MainActor
    func testEmptyStateScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark)
            let addDates = app.buttons["pregnancyAddDateButton"]
            XCTAssertTrue(addDates.waitForExistence(timeout: 10))
            attachScreenshot(app, "pregnancy-empty-\(suffix)")
            if language == "vi", !dark {
                addDates.tap()
                XCTAssertTrue(app.buttons["pregnancyDateSave"].waitForExistence(timeout: 5))
                attachScreenshot(app, "pregnancy-date-sheet-from-home-vi")
            }
            app.terminate()
        }
    }

    @MainActor
    func testAppointmentsScreens() {
        for (language, dark) in UITestVariants.all {
            let suffix = "\(language)-\(dark ? "dark" : "light")"
            let app = XCUIApplication.launchPinned(language: language, dark: dark, dueDate: UITestDates.dueAtWeek24)
            let card = app.buttons["nextAppointmentCard"]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            app.scrollUntilHittable(card)
            card.tap()
            let add = app.buttons["addAppointmentButton"]
            XCTAssertTrue(add.waitForExistence(timeout: 5))
            attachScreenshot(app, "appointments-empty-\(suffix)")

            if language == "vi", !dark {
                // Add the first two suggested milestones (week 24–28, then 27–36).
                for index in 0..<2 {
                    app.buttons.matching(identifier: "addMilestoneButton").firstMatch.tap()
                    let save = app.buttons["appointmentSaveButton"]
                    XCTAssertTrue(save.waitForExistence(timeout: 5))
                    if index == 0 { attachScreenshot(app, "appointment-editor-milestone-vi") }
                    save.tap()
                    XCTAssertTrue(add.waitForExistence(timeout: 5))
                }
                let firstRow = app.buttons.matching(identifier: "appointmentRow").firstMatch
                XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
                attachScreenshot(app, "appointments-upcoming-vi-light")

                firstRow.tap()
                let markDone = app.buttons["appointmentMarkDoneButton"]
                XCTAssertTrue(markDone.waitForExistence(timeout: 5))
                attachScreenshot(app, "appointment-editor-edit-vi")
                markDone.tap()
                // Wait for the sheet to fully dismiss before scrolling, so the
                // early drags land on the list, not on the dismissing sheet.
                XCTAssertTrue(add.waitForExistence(timeout: 5))
                // The milestones still ahead push "Past" below the fold; List only
                // renders cells near the viewport, so scroll before it can exist.
                // Nudge up a little at a time (rather than a full swipeUp, which
                // would scroll "Upcoming" out of frame too) and stop as soon as
                // "Past" is realized, so both sections stay visible for the shot.
                let pastHeader = app.staticTexts["pastHeader"]
                var remainingNudges = 10
                while !pastHeader.exists, remainingNudges > 0 {
                    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
                    start.press(forDuration: 0.02, thenDragTo: end)
                    remainingNudges -= 1
                }
                XCTAssertTrue(pastHeader.waitForExistence(timeout: 5))
                attachScreenshot(app, "appointments-with-past-vi-light")

                // At that minimal scroll, "Đã qua" and the done row are only just
                // realized and still partly behind the tab bar. Keep scrolling,
                // bounded, until the done row clears it, so the green "Đã khám"
                // label is legible in its own screenshot.
                let doneRow = app.buttons.matching(
                    NSPredicate(format: "identifier == 'appointmentRow' AND label CONTAINS 'Đã khám'")
                ).firstMatch
                XCTAssertTrue(doneRow.waitForExistence(timeout: 5))
                let tabBarTop = app.tabBars.firstMatch.frame.minY
                var remainingClearingSwipes = 10
                while doneRow.frame.maxY > tabBarTop, remainingClearingSwipes > 0 {
                    app.swipeUp()
                    remainingClearingSwipes -= 1
                }
                XCTAssertLessThan(doneRow.frame.maxY, tabBarTop)
                attachScreenshot(app, "appointments-past-vi-light")

                app.navigationBars.buttons.element(boundBy: 0).tap()
                XCTAssertTrue(card.waitForExistence(timeout: 5))
                attachScreenshot(app, "pregnancy-home-with-appointment-vi-light")
            }
            app.terminate()
        }
    }
}
