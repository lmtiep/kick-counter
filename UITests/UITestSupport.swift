import XCTest

/// Fixed dates for deterministic pregnancy UI tests. `fixedNow` is noon UTC so
/// it falls on the same calendar day in any simulator time zone from UTC−11 to UTC+11.
enum UITestDates {
    static let fixedNow = "2026-10-02T12:00:00Z"
    /// 12w0d at `fixedNow`.
    static let dueAtWeek12 = "2027-04-16T12:00:00Z"
    /// 24w3d at `fixedNow`, 109 days to go (the spec's example).
    static let dueAtWeek24 = "2027-01-19T12:00:00Z"
    /// 38w0d at `fixedNow`.
    static let dueAtWeek38 = "2026-10-16T12:00:00Z"
    /// 41w0d at `fixedNow`: 7 days past the due date.
    static let dueSevenDaysAgo = "2026-09-25T12:00:00Z"
}

/// Screenshot variants of the redesign (spec §6): vi/en × light/dark.
enum UITestVariants {
    static let all = [("vi", false), ("vi", true), ("en", false), ("en", true)]

    static func suffix(_ language: String, _ dark: Bool) -> String {
        "\(language)-\(dark ? "dark" : "light")"
    }
}

extension XCUIApplication {
    /// Launches with onboarding skipped and the clock pinned to `UITestDates.fixedNow`,
    /// optionally with a stored due date, or — with `seedCycles` (a `CycleSeedScenario`
    /// name: empty, period, fertile, late, irregular) — in trying-to-conceive mode with
    /// sample cycles. `largestText` uses Dynamic Type AX5; `extraArguments` adds
    /// more test-only flags (`-seedSessions`, `-seedOverdueSession`). Only the
    /// pregnancy, appointment, cycle and history screens use the pinned clock;
    /// counting kicks uses real time.
    @MainActor
    static func launchPinned(
        language: String = "en",
        dark: Bool = false,
        dueDate: String? = nil,
        seedCycles: String? = nil,
        skipOnboarding: Bool = true,
        largestText: Bool = false,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + (skipOnboarding ? ["-skipOnboarding"] : []) + [
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "vi" ? "vi_VN" : "en_US",
            "-fixedNow", UITestDates.fixedNow,
        ]
        if let dueDate { app.launchArguments += ["-seedDueDate", dueDate] }
        if let seedCycles { app.launchArguments += ["-seedCycles", seedCycles] }
        if dark { app.launchArguments.append("-forceDarkMode") }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    /// Swipes up, at most `maxSwipes` times, until `element` exists and is
    /// hittable — lazy containers (List, Form) only create cells near the viewport.
    func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 6) {
        var remaining = maxSwipes
        while !(element.exists && element.isHittable), remaining > 0 {
            swipeUp()
            remaining -= 1
        }
    }
}

extension XCTestCase {
    /// Attaches a screenshot; CI exports it to build/screenshots/<name>_….png.
    @MainActor
    func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits until `element`'s accessibility label contains `text`.
    @MainActor
    func waitForLabel(
        _ element: XCUIElement,
        containing text: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element.label) does not contain \(text)", file: file, line: line)
    }
}

/// Tab order in RootView in pregnancy mode (spec §2.3).
enum AppTab: Int {
    case today = 0
    case kicks
    case profile
}

/// Tab order in RootView in trying-to-conceive mode.
enum CycleModeTab: Int {
    case today = 0
    case calendar
    case profile
}

extension XCUIApplication {
    func openTab(_ tab: AppTab) {
        openTab(at: tab.rawValue)
    }

    /// Named differently from `openTab(_:)`: both enums have `.today` and `.profile`.
    func openCycleTab(_ tab: CycleModeTab) {
        openTab(at: tab.rawValue)
    }

    /// Taps `label` in a confirmation dialog: an action sheet, or on newer iOS a
    /// popover whose button comes after the one that opened it.
    func confirmDialog(_ label: String) {
        let sheetButton = sheets.buttons[label]
        if sheetButton.waitForExistence(timeout: 3) {
            sheetButton.tap()
            return
        }
        let named = buttons.matching(NSPredicate(format: "label == %@", label))
        named.element(boundBy: max(named.count - 1, 0)).tap()
    }

    /// Phase 5: pregnancy Today → "Symptoms".
    func openPregnancySymptoms() {
        let shortcut = buttons["shortcutSymptoms"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 10))
        scrollUntilHittable(shortcut)
        shortcut.tap()
        XCTAssertTrue(descendants(matching: .any)["symptomsTodayCard"].waitForExistence(timeout: 5))
    }

    /// History lives inside the Kicks tab (spec §2.3).
    func openHistory() {
        openTab(.kicks)
        let history = buttons["kicksHistoryButton"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        scrollUntilHittable(history)
        history.tap()
    }

    private func openTab(at index: Int) {
        let button = tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()
    }
}
