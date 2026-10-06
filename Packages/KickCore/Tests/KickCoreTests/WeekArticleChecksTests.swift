import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.4–4.5 on a fixture (weeks 7–11, two sources).
struct WeekArticleChecksTests {
    /// `count` words: words(3, "chữ") == "chữ chữ chữ."
    private func words(_ count: Int, _ word: String) -> String {
        Array(repeating: word, count: count).joined(separator: " ") + "."
    }

    /// Bé tab: en 20 + 40 + 2×60 = 180, vi 30 + 50 + 2×70 = 220.
    /// Mẹ tab: en 3×60 = 180, vi 3×70 = 210.
    private func validArticle() -> WeekArticle {
        WeekArticle(
            lead: LocalizedText(en: words(20, "word"), vi: words(30, "chữ")),
            sizeNote: LocalizedParagraphs(en: [words(40, "word")], vi: [words(50, "chữ")]),
            development: LocalizedParagraphs(
                en: [words(60, "word"), words(60, "word")],
                vi: [words(70, "chữ"), words(70, "chữ")]
            ),
            body: LocalizedParagraphs(
                en: [words(60, "word"), words(60, "word")],
                vi: [words(70, "chữ"), words(70, "chữ")]
            ),
            todo: LocalizedParagraphs(en: [words(60, "word")], vi: [words(70, "chữ")]),
            sources: [0]
        )
    }

    /// The fixture with `article` on week 7.
    private func content(_ article: WeekArticle?) throws -> PregnancyContent {
        var content = try fixtureContent()
        content.weeks[0].article = article
        return content
    }

    @Test func validArticlePasses() throws {
        #expect(WeekArticleChecks.validate(try content(validArticle())).isEmpty)
    }

    @Test func missingArticlesAreReportedOnlyInsideRequiredWeeks() throws {
        let content = try content(validArticle())
        #expect(WeekArticleChecks.validate(content).isEmpty)
        #expect(WeekArticleChecks.validate(content, requiredWeeks: 7...8) == [.missingArticle(week: 8)])
    }

    @Test func emptyAndBlankParagraphsAreReported() throws {
        var article = validArticle()
        article.todo.vi = []
        article.body.en[1] = "  "
        article.lead.vi = " "
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.emptyParagraphs(week: 7, field: "todo", language: .vi)))
        #expect(found.contains(.blankText(week: 7, field: "body", language: .en)))
        #expect(found.contains(.blankText(week: 7, field: "lead", language: .vi)))
    }

    @Test func leadsOverTheLimitAreReported() throws {
        var article = validArticle()
        article.lead = LocalizedText(en: words(31, "word"), vi: words(41, "chữ"))
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.leadTooLong(week: 7, language: .en, words: 31)))
        #expect(found.contains(.leadTooLong(week: 7, language: .vi, words: 41)))
        article.lead = LocalizedText(en: words(30, "word"), vi: words(40, "chữ"))
        #expect(WeekArticleChecks.validate(try content(article)).isEmpty)
    }

    @Test func tabsOutsideTheWordRangeAreReported() throws {
        var article = validArticle()
        article.body.en = [words(40, "word")] // Mẹ en: 40 + 60 = 100
        article.development.vi = [words(120, "chữ"), words(120, "chữ")] // Bé vi: 30 + 50 + 240 = 320
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.tabLength(week: 7, tab: .mom, language: .en, words: 100)))
        #expect(found.contains(.tabLength(week: 7, tab: .baby, language: .vi, words: 320)))
        #expect(found.count == 2)
    }

    @Test func tabWordCountsFollowTheTabs() {
        let article = validArticle()
        #expect(WeekArticleChecks.tabWordCount(article, tab: .baby, language: .en) == 180)
        #expect(WeekArticleChecks.tabWordCount(article, tab: .baby, language: .vi) == 220)
        #expect(WeekArticleChecks.tabWordCount(article, tab: .mom, language: .en) == 180)
        #expect(WeekArticleChecks.tabWordCount(article, tab: .mom, language: .vi) == 210)
    }

    @Test func sourcesMustBeValidIndices() throws {
        var article = validArticle()
        article.sources = []
        #expect(WeekArticleChecks.validate(try content(article)) == [.noSources(week: 7)])
        article.sources = [1, 2, -1]
        #expect(
            WeekArticleChecks.validate(try content(article))
                == [.invalidSource(week: 7, index: 2), .invalidSource(week: 7, index: -1)]
        )
    }

    @Test func imperialUnitsAreReported() throws {
        var article = validArticle()
        article.sizeNote.en = ["Your baby weighs about 1 pound. " + words(34, "word")] // still 40 words
        article.todo.en = ["Drink 8 oz of water. " + words(55, "word")] // still 60 words
        article.development.vi[0] = "Bé dài 12″. " + words(67, "chữ") // still 70 words
        let found = WeekArticleChecks.validate(try content(article))
        #expect(found.contains(.imperialUnit(week: 7, field: "sizeNote", language: .en)))
        #expect(found.contains(.imperialUnit(week: 7, field: "todo", language: .en)))
        #expect(found.contains(.imperialUnit(week: 7, field: "development", language: .vi)))
        #expect(found.count == 3)
    }

    @Test func metricTextAndLookalikeWordsAreNotFlagged() {
        #expect(!WeekArticleChecks.containsImperialUnit("Your baby weighs about 670 g and is 30 cm long."))
        #expect(!WeekArticleChecks.containsImperialUnit("We announce a pounding heartbeat in Ozone Park."))
        #expect(WeekArticleChecks.containsImperialUnit("About 2 LBS"))
        #expect(WeekArticleChecks.containsImperialUnit("12 inches"))
        #expect(WeekArticleChecks.containsImperialUnit("5″"))
    }

    @Test func wordsAreSplitOnWhitespace() {
        #expect(WeekArticleChecks.wordCount("  Bé  nặng\nkhoảng 670 g. ") == 5)
        #expect(WeekArticleChecks.wordCount("") == 0)
    }
}
