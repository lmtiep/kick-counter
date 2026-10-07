import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.2: loading, visibility and the library sections.
struct KnowledgeLibraryTests {
    private func temporaryFile(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("knowledge-\(UUID().uuidString).json")
        try Data(text.utf8).write(to: url)
        return url
    }

    private func encoded(_ content: KnowledgeContent) throws -> String {
        String(decoding: try JSONEncoder().encode(content), as: UTF8.self)
    }

    @Test func aMissingFileGivesNil() {
        #expect(KnowledgeLibrary.load(from: nil) == nil)
        let gone = FileManager.default.temporaryDirectory.appendingPathComponent("no-such-\(UUID().uuidString).json")
        #expect(KnowledgeLibrary.load(from: gone) == nil)
    }

    @Test func malformedJSONGivesNil() throws {
        #expect(KnowledgeLibrary.load(from: try temporaryFile("{\"version\": 1, \"topics\": ")) == nil)
    }

    @Test func anotherVersionGivesNil() throws {
        var content = knowledgeContent([])
        content.version = 2
        #expect(KnowledgeLibrary.load(from: try temporaryFile(try encoded(content))) == nil)
        #expect(throws: KnowledgeLoadError.unsupportedVersion(2)) {
            try KnowledgeLibrary(data: Data(try encoded(content).utf8))
        }
    }

    @Test func aValidFileLoads() throws {
        let content = knowledgeContent([knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3])])
        let library = try #require(KnowledgeLibrary.load(from: try temporaryFile(try encoded(content))))
        #expect(library.document == content)
        #expect(library.topics.map(\.id) == knowledgeTopicIDs)
        #expect(library.article(id: "safe-exercise")?.topic == "movement")
        #expect(library.article(id: "nope") == nil)
        #expect(library.topic(id: "sleep")?.name.text(.en) == "Topic sleep")
    }

    @Test func reviewedOnlyDropsUnreviewedArticles() {
        let library = KnowledgeLibrary(document: knowledgeContent([
            knowledgeArticle("food-safety", topic: "nutrition", trimesters: [1, 2, 3], reviewed: true),
            knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3]),
        ]))
        #expect(library.articles(visibility: .all).map(\.id) == ["food-safety", "safe-exercise"])
        #expect(library.articles(visibility: .reviewedOnly).map(\.id) == ["food-safety"])
        #expect(library.suggestions(forWeek: 24, visibility: .reviewedOnly).map(\.id) == ["food-safety"])
    }

    @Test func nothingReviewedMeansNoSuggestionsAndNoSections() {
        let library = KnowledgeLibrary(document: knowledgeContent([
            knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3]),
        ]))
        #expect(library.suggestions(forWeek: 24, visibility: .reviewedOnly).isEmpty)
        #expect(library.sections(trimester: .second, visibility: .reviewedOnly).isEmpty)
    }

    @Test func sectionsFollowTopicOrderAndSkipEmptyTopics() {
        let library = KnowledgeLibrary(document: knowledgeContent([
            knowledgeArticle("signs-of-labour", topic: "birth", trimesters: [3]),
            knowledgeArticle("food-safety", topic: "nutrition", trimesters: [1, 2, 3]),
            knowledgeArticle("sleep-positions", topic: "sleep", trimesters: [2, 3]),
            knowledgeArticle("iron-calcium-balanced-meals", topic: "nutrition", trimesters: [2, 3]),
        ]))
        let third = library.sections(trimester: .third, visibility: .all)
        #expect(third.map(\.topic.id) == ["nutrition", "sleep", "birth"])
        #expect(third[0].articles.map(\.id) == ["food-safety", "iron-calcium-balanced-meals"])
        #expect(library.sections(trimester: .first, visibility: .all).map(\.id) == ["nutrition"])
    }

    @Test func referencesSkipInvalidIndices() {
        var article = knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3])
        article.sources = [1, 7, 0]
        let library = KnowledgeLibrary(document: knowledgeContent([article]))
        #expect(library.references(for: article) == ["Source B", "Source A"])
    }
}
