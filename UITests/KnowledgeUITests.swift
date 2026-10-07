import XCTest

/// Phase 7 spec §4 and §5: the Today card, the library and the reading screen,
/// seeded at week 24 (trimester 2) with every article visible (`-uiTesting`).
final class KnowledgeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Today at 24w3d, scrolled down to the knowledge card.
    @MainActor
    private func launchAtWeek24(largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication.launchPinned(language: "en", dueDate: UITestDates.dueAtWeek24, largestText: largestText)
        XCTAssertTrue(app.buttons["fetusHeroButton"].waitForExistence(timeout: 10))
        let seeMore = app.buttons["knowledgeSeeMore"]
        app.scrollUntilHittable(seeMore, maxSwipes: largestText ? 20 : 8)
        XCTAssertTrue(seeMore.isHittable)
        return app
    }

    @MainActor
    private func suggestions(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "knowledgeSuggestion-"))
    }

    /// §4.1: the card's title names the trimester; its rows are the suggestions.
    @MainActor
    func testTodayShowsTheCardWithSuggestions() {
        let app = launchAtWeek24()
        XCTAssertTrue(app.descendants(matching: .any)["knowledgeCard"].exists)
        XCTAssertTrue(app.staticTexts["Suggested for trimester 2"].exists)
        // Task 2: safe-exercise is the only article written so far (Task 3 makes it 3).
        XCTAssertEqual(suggestions(app).count, 1)
        XCTAssertTrue(app.buttons["knowledgeSuggestion-safe-exercise"].exists)
    }

    /// §4.3: a suggestion opens the reading screen at peek; the handle expands it; ✕ closes it.
    @MainActor
    func testSuggestionOpensTheReadingScreen() {
        let app = launchAtWeek24()
        suggestions(app).firstMatch.tap()
        let handle = app.buttons["knowledgeSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertEqual(handle.label, "Expand article")
        XCTAssertTrue(app.staticTexts["knowledgeTitle"].exists)
        XCTAssertTrue(app.staticTexts["knowledgeSummary"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["knowledgeReviewer"].exists)
        handle.tap()
        waitForLabel(handle, containing: "Collapse article")
        app.buttons["knowledgeClose"].tap()
        XCTAssertTrue(app.buttons["knowledgeSeeMore"].waitForExistence(timeout: 5))
        XCTAssertFalse(handle.exists)
    }

    /// §4.2: "See more" opens the library on the current trimester; chips switch it.
    @MainActor
    func testSeeMoreOpensTheLibraryOnTheCurrentTrimester() {
        let app = launchAtWeek24()
        app.buttons["knowledgeSeeMore"].tap()
        let second = app.buttons["knowledgeTrimester-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertTrue(second.isSelected)
        XCTAssertTrue(app.navigationBars.staticTexts["Knowledge"].exists)

        let third = app.buttons["knowledgeTrimester-3"]
        XCTAssertFalse(third.isSelected)
        third.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: third)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 5), .completed)
        XCTAssertFalse(second.isSelected)
        // Task 5 checks signs-of-labour here; until then safe-exercise is the trimester-3 article.
        let row = app.buttons["knowledgeArticle-safe-exercise"]
        app.scrollUntilHittable(row)
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.buttons["knowledgeSheetHandle"].waitForExistence(timeout: 5))
        app.buttons["knowledgeClose"].tap()
        XCTAssertTrue(third.waitForExistence(timeout: 5))
    }

    /// §4.3: accessibility text sizes open the sheet expanded.
    @MainActor
    func testLargestTextOpensExpanded() {
        let app = launchAtWeek24(largestText: true)
        let first = suggestions(app).firstMatch
        app.scrollUntilHittable(first)
        first.tap()
        let handle = app.buttons["knowledgeSheetHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        waitForLabel(handle, containing: "Collapse article")
    }

    /// §2: trying-to-conceive mode shows nothing new.
    @MainActor
    func testTryingToConceiveHasNoKnowledgeCard() {
        let app = XCUIApplication.launchPinned(language: "en", seedCycles: "period")
        XCTAssertTrue(app.descendants(matching: .any)["cycleStatusCard"].waitForExistence(timeout: 10))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.descendants(matching: .any)["knowledgeCard"].exists)
        XCTAssertFalse(app.buttons["knowledgeSeeMore"].exists)
    }
}
