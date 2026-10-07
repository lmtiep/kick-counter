import Foundation

/// The three articles on Today's knowledge card (phase 7 spec §3.3). Pure, so
/// the same week always gives the same articles.
public enum KnowledgeSuggester {
    public static let defaultCount = 3

    /// 1. Keep the articles for the trimester of `week` (clamped to 4…42 first).
    /// 2. Group them by topic, topics in display order (`topicOrder`; unknown
    ///    topics last, by id), each topic's articles by id.
    /// 3. Rotate the topic list left by `week % topics.count`, so the next week
    ///    starts one topic later.
    /// 4. Take one article from each of the first `count` topics: the one at
    ///    `(week / topics.count + round) % articles.count`, so each topic cycles
    ///    through its articles. With fewer topics than `count`, later rounds fill
    ///    the free slots with each topic's next article. Fewer than `count`
    ///    eligible → all of them; none → [].
    public static func suggestions(
        for week: Int,
        from articles: [KnowledgeArticle],
        topicOrder: [String],
        count: Int = defaultCount
    ) -> [KnowledgeArticle] {
        let clamped = WeeklyContentLibrary.clampedWeek(week)
        let trimester = Trimester(week: clamped)
        let rank = Dictionary(topicOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let eligible = articles
            .filter { $0.applies(to: trimester) }
            .sorted { (rank[$0.topic] ?? Int.max, $0.topic, $0.id) < (rank[$1.topic] ?? Int.max, $1.topic, $1.id) }
        guard !eligible.isEmpty, count > 0 else { return [] }

        var groups: [[KnowledgeArticle]] = []
        for article in eligible {
            if groups.last?.first?.topic == article.topic {
                groups[groups.count - 1].append(article)
            } else {
                groups.append([article])
            }
        }
        let start = clamped % groups.count
        let rotated = Array(groups[start...] + groups[..<start])
        let cycle = clamped / groups.count

        var picked: [KnowledgeArticle] = []
        var round = 0
        while picked.count < min(count, eligible.count) {
            for group in rotated where round < group.count && picked.count < count {
                picked.append(group[(cycle + round) % group.count])
            }
            round += 1
        }
        return picked
    }
}
