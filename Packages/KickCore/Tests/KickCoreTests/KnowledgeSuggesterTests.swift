import Testing
@testable import KickCore

/// Phase 7 spec §3.3: three stable, rotating, topic-spread suggestions that give
/// every article of the trimester a fair share of its weeks.
struct KnowledgeSuggesterTests {
    /// Trimester 1: a [a1], b [b2] (2 topics).
    /// Trimester 2: a [a1, a2], b [b1], c [c1] (3 topics).
    /// Trimester 3: a [a1], b [b1], c [c1, c2] (3 topics).
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
        // 3 topics: start at topic 24 % 3 = 0 (a); article index 24 / 3 % n = 8 % n.
        #expect(ids(24) == ["a1", "b1", "c1"]) // a[8 % 2 = 0], b[0], c[0]
    }

    @Test func eachWeekStartsOneTopicLater() {
        #expect(ids(25) == ["b1", "c1", "a1"]) // start b; index 25 / 3 = 8: a[0]
        #expect(ids(26) == ["c1", "a1", "b1"]) // start c; index 8
        #expect(ids(27) == ["a2", "b1", "c1"]) // start a; index 27 / 3 = 9: a[9 % 2 = 1]
        #expect(ids(24).first != ids(25).first)
    }

    @Test func eachTopicCyclesThroughItsArticles() {
        // Trimester 3, topic c = [c1, c2]; index = week / 3 % 2.
        #expect(ids(30) == ["a1", "b1", "c1"]) // start a; 30 / 3 = 10: c[0]
        #expect(ids(33) == ["a1", "b1", "c2"]) // start a; 33 / 3 = 11: c[1]
        #expect(ids(32) == ["c1", "a1", "b1"]) // start c; 32 / 3 = 10: c[0]
        #expect(ids(35) == ["c2", "a1", "b1"]) // start c; 35 / 3 = 11: c[1]
    }

    @Test func freeSlotsAreFilledFromTheNextArticleOfEachTopic() {
        let twoTopics = [
            knowledgeArticle("a1", topic: "a", trimesters: [2]),
            knowledgeArticle("a2", topic: "a", trimesters: [2]),
            knowledgeArticle("a3", topic: "a", trimesters: [2]),
            knowledgeArticle("b1", topic: "b", trimesters: [2]),
        ]
        // 2 topics; index 14 / 2 = 7. Round 0: a[7 % 3 = 1], b[0]. Round 1: a[8 % 3 = 2]; b has no second.
        #expect(ids(14, from: twoTopics) == ["a2", "b1", "a3"])
        // Start b; index 15 / 2 = 7. Round 0: b[0], a[1]. Round 1: a[2].
        #expect(ids(15, from: twoTopics) == ["b1", "a2", "a3"])
    }

    @Test func sortsByTopicDisplayOrderThenID() {
        #expect(ids(24, order: ["c", "a", "b"]) == ["c1", "a1", "b1"]) // topics c, a, b; index 8
        #expect(ids(27, order: ["c", "a", "b"]) == ["c1", "a2", "b1"]) // index 9: a[1]
    }

    @Test func noEligibleArticlesGivesNothing() {
        let thirdOnly = [knowledgeArticle("c2", topic: "c", trimesters: [3])]
        #expect(ids(10, from: thirdOnly).isEmpty)
        #expect(ids(10, from: []).isEmpty)
    }

    @Test func weeksAreClampedTo4Through42() {
        // 42: start 42 % 3 = 0 (a); index 14: c[0]. Unclamped 45 would be index 15: c2.
        #expect(ids(45) == ids(42))
        #expect(ids(45) == ["a1", "b1", "c1"])
        // 4: start 4 % 2 = 0 (a). Unclamped 1 would start at b.
        #expect(ids(1) == ids(4))
        #expect(ids(1) == ["a1", "b2"])
    }
}

/// Phase 7 spec §3.3 on the shipped `knowledge-content.json`: every article of a
/// trimester is suggested in a fair share of that trimester's weeks.
struct BundledKnowledgeSuggestionTests {
    static let trimesterWeeks: [(Trimester, ClosedRange<Int>)] = [
        (.first, 4...13), (.second, 14...27), (.third, 28...42),
    ]

    /// The most weeks of a trimester any one article may appear in: 65%.
    /// Three different topics are picked each week, so with five eligible topics
    /// (trimesters 1 and 2) a topic with a single article is in 3/5 = 60% of the
    /// weeks on average; over 14 weeks that rounds up to 9 (64%). 65% is the
    /// tightest bound the content can meet.
    static let maxSharePercent = 65

    let library: KnowledgeLibrary

    init() throws {
        library = try KnowledgeLibrary.bundled()
    }

    private func suggestions(_ week: Int) -> [String] {
        library.suggestions(forWeek: week, visibility: .all).map(\.id)
    }

    @Test(arguments: Self.trimesterWeeks.map(\.0))
    func everyArticleGetsAFairShareOfItsTrimester(_ trimester: Trimester) {
        let weeks = Self.trimesterWeeks.first { $0.0 == trimester }!.1
        let eligible = library.articles(visibility: .all).filter { $0.applies(to: trimester) }.map(\.id)
        var counts: [String: Int] = [:]
        for week in weeks {
            for id in suggestions(week) { counts[id, default: 0] += 1 }
        }
        for id in eligible {
            let count = counts[id, default: 0]
            #expect(count >= 1, "\(id) is never suggested in trimester \(trimester.rawValue)")
            #expect(
                count * 100 <= weeks.count * Self.maxSharePercent,
                "\(id) is suggested in \(count) of \(weeks.count) weeks of trimester \(trimester.rawValue)"
            )
        }
    }

    @Test func everyWeekHasThreeDifferentTopics() {
        for week in 4...42 {
            let picked = library.suggestions(forWeek: week, visibility: .all)
            #expect(picked.count == 3)
            #expect(Set(picked.map(\.topic)).count == 3, "week \(week): \(picked.map(\.id))")
        }
    }

    @Test func consecutiveWeeksDiffer() {
        for week in 4..<42 {
            #expect(suggestions(week) != suggestions(week + 1), "weeks \(week) and \(week + 1)")
        }
    }
}
