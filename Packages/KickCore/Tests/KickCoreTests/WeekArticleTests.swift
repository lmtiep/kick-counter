import Foundation
import Testing
@testable import KickCore

/// Phase 6 spec §4.1: version-3 articles next to every existing field.
struct WeekArticleTests {
    @Test func version2FileDecodesWithoutArticles() throws {
        let json = """
        {"version": 2, "sources": ["S"], "milestones": [], "weeks": [{
          "week": 7, "reviewed": false,
          "size": {"emoji": "🫐", "en": "a blueberry", "vi": "một quả việt quất"},
          "crlMm": 9.6,
          "baby": {"en": ["a", "b"], "vi": ["a", "b"]}, "mom": {"en": ["a", "b"], "vi": ["a", "b"]},
          "tips": {"en": ["a", "b"], "vi": ["a", "b"]}, "warnings": {"en": ["a"], "vi": ["a"]}
        }]}
        """
        let content = try JSONDecoder().decode(PregnancyContent.self, from: Data(json.utf8))
        #expect(content.weeks[0].article == nil)
        #expect(content.weeks[0].crlMm == 9.6)
        #expect(content.weeks[0].baby.items(.vi) == ["a", "b"])
    }

    @Test func articleDecodesAndPicksTheLanguage() throws {
        let json = """
        {"lead": {"en": "Lead.", "vi": "Mở đầu."},
         "sizeNote": {"en": ["Size."], "vi": ["Kích thước."]},
         "development": {"en": ["One.", "Two."], "vi": ["Một.", "Hai."]},
         "body": {"en": ["Body."], "vi": ["Cơ thể."]},
         "todo": {"en": ["Do."], "vi": ["Làm."]},
         "sources": [0, 2]}
        """
        let article = try JSONDecoder().decode(WeekArticle.self, from: Data(json.utf8))
        #expect(article.lead.text(.vi) == "Mở đầu.")
        #expect(article.development.paragraphs(.en) == ["One.", "Two."])
        #expect(article.development.paragraphs(.vi) == ["Một.", "Hai."])
        #expect(article.sources == [0, 2])
        #expect(article.paragraphFields.map { $0.name } == ["sizeNote", "development", "body", "todo"])
        #expect(article.texts(.en).map { $0.field } == ["lead", "sizeNote", "development", "development", "body", "todo"])
    }

    @Test func weekWithoutArticleEncodesNoArticleKey() throws {
        let week = try #require(try fixtureContent().weeks.first)
        let text = String(decoding: try JSONEncoder().encode(week), as: UTF8.self)
        #expect(!text.contains("\"article\""))
    }

    @Test func artworkNamesUseTwoDigitWeeks() {
        #expect(WeekArtworkName.fetus(week: 4) == "Fetus-W04")
        #expect(WeekArtworkName.fetus(week: 31) == "Fetus-W31")
        #expect(WeekArtworkName.fruit(week: 9) == "Fruit-W09")
        #expect(WeekArtworkName.fruit(week: 42) == "Fruit-W42")
    }
}
