import XCTest

/// Raw App Store screenshots (iPhone 6.9", light mode), vi and en. Each screen is
/// attached as `appstore-<n>-<slug>-<lang>`; run on the 6.9" simulator with a
/// clean status bar (`xcrun simctl status_bar … override --time 9:41 …`).
final class AppStoreScreenshotTests: XCTestCase {
    /// 26w0d at `UITestDates.fixedNow`: the fetus, the fruit and the Hadlock weight all show.
    private static let dueAtWeek26 = "2027-01-08T12:00:00Z"
    private static let languages = ["vi", "en"]

    override func setUp() {
        continueAfterFailure = false
    }

    /// Lets springs and fades finish before the shot.
    private func settle(_ seconds: TimeInterval = 1.0) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Nudges Today up in short, slow drags (no momentum) until the baby size card
    /// clears the floating tab bar, keeping the fetus hero and the week on screen.
    @MainActor
    private func revealBabySizeCard(_ app: XCUIApplication) {
        let card = app.buttons["babySizeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let tabBarTop = app.tabBars.firstMatch.frame.minY
        var remaining = 8
        while card.frame.maxY > tabBarTop - 12, remaining > 0 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            let end = start.withOffset(CGVector(dx: 0, dy: -20))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
            remaining -= 1
        }
    }

    @MainActor
    private func launchCycle(_ language: String) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: language, seedCycles: "fertile", cycleGoal: "conceiving")
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testCycleScreens() {
        for language in Self.languages {
            let app = launchCycle(language)
            settle()
            attachScreenshot(app, "appstore-1-cycle-today-\(language)")

            app.openCycleTab(.calendar)
            XCTAssertTrue(app.staticTexts["calendarMonthTitle"].waitForExistence(timeout: 10))
            settle()
            attachScreenshot(app, "appstore-2-cycle-calendar-\(language)")
            app.terminate()

            let history = launchCycle(language)
            let link = history.buttons["cycleHistoryLink"]
            history.scrollUntilHittable(link, maxSwipes: 12)
            link.tap()
            XCTAssertTrue(history.descendants(matching: .any)["cycleHistorySummary"].waitForExistence(timeout: 5))
            settle()
            attachScreenshot(history, "appstore-3-cycle-history-\(language)")
            history.terminate()
        }
    }

    @MainActor
    func testPregnancyScreens() {
        for language in Self.languages {
            let app = XCUIApplication.launchPinned(language: language, dueDate: Self.dueAtWeek26)
            let fetus = app.buttons["fetusHeroButton"]
            XCTAssertTrue(fetus.waitForExistence(timeout: 10))
            XCTAssertTrue(app.descendants(matching: .any)["weekProgressCard"].waitForExistence(timeout: 5))
            revealBabySizeCard(app)
            settle()
            attachScreenshot(app, "appstore-4-pregnancy-today-\(language)")

            fetus.tap()
            let handle = app.buttons["weekSheetHandle"]
            XCTAssertTrue(handle.waitForExistence(timeout: 5))
            handle.tap()
            waitForLabel(handle, containing: language == "vi" ? "Thu gọn bài viết" : "Collapse article")
            XCTAssertTrue(app.staticTexts["weekSizeLine"].waitForExistence(timeout: 5))
            settle()
            attachScreenshot(app, "appstore-5-week-article-\(language)")
            app.terminate()

            let library = XCUIApplication.launchPinned(language: language, dueDate: Self.dueAtWeek26)
            XCTAssertTrue(library.buttons["fetusHeroButton"].waitForExistence(timeout: 10))
            let seeMore = library.buttons["knowledgeSeeMore"]
            library.scrollUntilHittable(seeMore, maxSwipes: 8)
            seeMore.tap()
            XCTAssertTrue(library.buttons["knowledgeTrimester-2"].waitForExistence(timeout: 5))
            settle()
            attachScreenshot(library, "appstore-7-knowledge-\(language)")
            library.terminate()
        }
    }

    @MainActor
    func testKickCounterScreens() {
        for language in Self.languages {
            let app = XCUIApplication.launchPinned(
                language: language, dueDate: Self.dueAtWeek26, extraArguments: ["-seedSessions", "-seedActiveSession"]
            )
            app.openTab(.kicks)
            let kick = app.buttons["kickButton"]
            XCTAssertTrue(kick.waitForExistence(timeout: 10))
            XCTAssertTrue(app.descendants(matching: .any)["kickTimes"].waitForExistence(timeout: 5))
            settle()
            attachScreenshot(app, "appstore-6-kick-counter-\(language)")
            app.terminate()
        }
    }
}
