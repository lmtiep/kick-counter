import Testing
@testable import KickCore

/// Phase 7 spec §3.3: three stable, rotating, topic-spread suggestions.
struct KnowledgeSuggesterTests {
    /// Trimester 2: a1, a2, b1, c1. Trimester 3: a1, b1, c1, c2. Trimester 1: a1, b2.
    let articles = [
        knowledgeArticle("c2", topic: "c", trimesters: [3]),
        knowledgeArticle("b1", topic: "b", trimesters: [2, 3]),
        knowledgeArticle("a2", topic: "a", trimesters: [2]),
        knowledgeArticle("c1", topic: "c", trimesters: [2, 3]),
        knowledgeArticle("b2", topic: "b", trimesters: [1]),
        knowledgeArticle("a1", topic: "a", trimesters: [1, 2, 3]),
    ]
    let order = ["a", "b", "c"]

    private func ids(_ week: Int, order: [String]? = nil, from list: [KnowledgeArticle]? = nil) -> [String] {
        KnowledgeSuggester.suggestions(for: week, from: list ?? articles, topicOrder: order ?? self.order).map(\.id)
    }

    @Test func onlyTheWeeksTrimester() {
        #expect(ids(10) == ["a1", "b2"]) // trimester 1: fewer than three, all of them
        #expect(!ids(30).contains("a2")) // a2 is trimester 2 only
        #expect(!ids(20).contains("c2")) // c2 is trimester 3 only
    }

    @Test func theSameWeekGivesTheSameArticles() {
        #expect(ids(24) == ids(24))
        #expect(ids(24) == ["a1", "b1", "c1"]) // 24 % 4 = 0
    }

    @Test func eachWeekStartsOneArticleLater() {
        #expect(ids(25) == ["a2", "b1", "c1"]) // a2, b1, c1, a1
        #expect(ids(26) == ["b1", "c1", "a1"]) // b1, c1, a1, a2
        #expect(ids(27) == ["c1", "a1", "b1"]) // c1, a1, a2, b1
        #expect(ids(24).first != ids(25).first)
    }

    @Test func oneArticlePerTopicFirst() {
        #expect(ids(30) == ["c1", "a1", "b1"]) // 30 % 4 = 2: c1, c2, a1, b1; c2 skipped
    }

    @Test func freeSlotsAreFilledInRotatedOrder() {
        let twoTopics = [
            knowledgeArticle("a1", topic: "a", trimesters: [2]),
            knowledgeArticle("a2", topic: "a", trimesters: [2]),
            knowledgeArticle("a3", topic: "a", trimesters: [2]),
            knowledgeArticle("b1", topic: "b", trimesters: [2]),
        ]
        #expect(ids(14, from: twoTopics) == ["a3", "b1", "a1"]) // 14 % 4 = 2: a3, b1, a1, a2
    }

    @Test func sortsByTopicDisplayOrderThenID() {
        #expect(ids(24, order: ["c", "a", "b"]) == ["c1", "a1", "b1"]) // c1, a1, a2, b1
    }

    @Test func noEligibleArticlesGivesNothing() {
        let thirdOnly = [knowledgeArticle("c2", topic: "c", trimesters: [3])]
        #expect(ids(10, from: thirdOnly).isEmpty)
        #expect(ids(10, from: []).isEmpty)
    }

    @Test func weeksAreClampedTo4Through42() {
        #expect(ids(45) == ids(42)) // 42 % 4 = 2: c1, a1, b1 (45 would start at c2)
        #expect(ids(45) == ["c1", "a1", "b1"])
        #expect(ids(1) == ids(4)) // 4 % 2 = 0: a1, b2 (1 would start at b2)
        #expect(ids(1) == ["a1", "b2"])
    }
}
