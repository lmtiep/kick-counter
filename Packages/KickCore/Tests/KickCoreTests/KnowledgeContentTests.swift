import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.2: the knowledge data model.
struct KnowledgeContentTests {
    @Test func documentDecodes() throws {
        let json = """
        {"version": 1, "sources": ["S0", "S1"],
         "topics": [{"id": "movement", "name": {"en": "Movement", "vi": "Vận động"}, "symbol": "figure.walk"}],
         "articles": [{
           "id": "safe-exercise", "topic": "movement", "trimesters": [1, 2, 3], "reviewed": false,
           "title": {"en": "Title", "vi": "Tiêu đề"},
           "summary": {"en": "Summary.", "vi": "Tóm tắt."},
           "sections": [
             {"heading": {"en": "One", "vi": "Một"}, "paragraphs": {"en": ["A.", "B."], "vi": ["A.", "B."]}},
             {"heading": {"en": "Two", "vi": "Hai"}, "paragraphs": {"en": ["C."], "vi": ["C."]}}
           ],
           "sources": [1]
         }]}
        """
        let content = try JSONDecoder().decode(KnowledgeContent.self, from: Data(json.utf8))
        #expect(content.version == 1)
        #expect(content.topics[0].name.text(.vi) == "Vận động")
        #expect(content.topics[0].symbol == "figure.walk")
        let article = try #require(content.articles.first)
        #expect(article.id == "safe-exercise")
        #expect(article.trimesters == [1, 2, 3])
        #expect(article.sections[0].paragraphs.paragraphs(.en) == ["A.", "B."])
        #expect(article.sources == [1])
        #expect(
            article.texts(.en).map(\.field)
                == ["title", "summary", "section 1 heading", "section 1", "section 1", "section 2 heading", "section 2"]
        )
    }

    @Test func appliesToItsTrimesters() {
        let article = knowledgeArticle("sleep-positions", topic: "sleep", trimesters: [2, 3])
        #expect(!article.applies(to: .first))
        #expect(article.applies(to: .second))
        #expect(article.applies(to: .third))
    }

    @Test func artworkAssetName() {
        #expect(KnowledgeArtworkName.asset(articleID: "safe-exercise") == "Knowledge-safe-exercise")
    }
}
