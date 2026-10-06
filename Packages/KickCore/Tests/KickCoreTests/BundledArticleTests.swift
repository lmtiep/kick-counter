import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.5: the week articles in the shipped `pregnancy-content.json`.
struct BundledArticleTests {
    /// Every week 4–42 must have an article (phase 6 spec §4.5).
    static let requiredArticleWeeks: ClosedRange<Int>? = WeeklyContentLibrary.weekRange

    let library: WeeklyContentLibrary

    init() throws {
        library = try WeeklyContentLibrary.bundled()
    }

    private var articles: [(week: WeekContent, article: WeekArticle)] {
        library.document.weeks.compactMap { week in week.article.map { (week, $0) } }
    }

    @Test func contentIsVersion3() {
        #expect(library.document.version == 3)
    }

    @Test func everyWrittenArticlePassesTheChecks() {
        let issues = WeekArticleChecks.validate(library.document, requiredWeeks: Self.requiredArticleWeeks)
        #expect(issues.isEmpty, "\(issues)")
    }

    /// Writing guide §4.4: no medicine doses.
    @Test func articlesStateNoDoses() {
        for (week, article) in articles {
            for language in ContentLanguage.allCases {
                for (field, text) in article.texts(language) {
                    #expect(text.firstMatch(of: /\b(?:mg|mcg|µg|IU)\b/) == nil, "week \(week.week) \(field).\(language.rawValue): \(text)")
                }
            }
        }
    }

    @Test func vietnameseArticleTextHasDiacritics() {
        for (week, article) in articles {
            for (field, text) in article.texts(.vi) {
                #expect(text.unicodeScalars.contains { $0.value > 127 }, "week \(week.week) \(field): \(text)")
            }
        }
    }

    /// The size line quotes Hadlock 1992 (crown–rump length, index 5) and Hadlock 1991
    /// (weight, index 4); every article also cites a guideline body (WHO, ACOG, NHS, Bộ Y tế: 0–3).
    @Test func sourcesMatchTheWeeksFigures() {
        #expect(library.sources[4].contains("Hadlock FP, Harrist RB"))
        #expect(library.sources[5].contains("Hadlock FP, Shah YP"))
        for (week, article) in articles {
            if week.crlMm != nil { #expect(article.sources.contains(5), "week \(week.week): Hadlock 1992") }
            if week.weightG != nil { #expect(article.sources.contains(4), "week \(week.week): Hadlock 1991") }
            #expect(article.sources.contains { (0...3).contains($0) }, "week \(week.week): guideline body")
        }
    }

    /// Task 3: week 24 carries the first article; the UI tests and screenshots use it.
    @Test func week24HasAnArticle() throws {
        let week = try #require(library.content(forWeek: 24))
        #expect(week.article != nil)
    }
}
