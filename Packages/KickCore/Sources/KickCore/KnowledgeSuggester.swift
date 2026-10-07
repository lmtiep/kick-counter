import Foundation

/// The three articles on Today's knowledge card (phase 7 spec §3.3). Pure, so
/// the same week always gives the same articles.
public enum KnowledgeSuggester {
    public static let defaultCount = 3

    /// 1. Keep the articles for the trimester of `week` (clamped to 4…42 first).
    /// 2. Sort them by topic display order (`topicOrder`; unknown topics last), then id.
    /// 3. Rotate left by `week % eligible.count`, so the next week starts one article later.
    /// 4. Walk the rotated list taking one article per topic, then fill any free
    ///    slots in rotated order. Fewer than `count` eligible → all of them; none → [].
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
            .sorted { (rank[$0.topic] ?? Int.max, $0.id) < (rank[$1.topic] ?? Int.max, $1.id) }
        guard !eligible.isEmpty, count > 0 else { return [] }
        let start = clamped % eligible.count
        let rotated = Array(eligible[start...] + eligible[..<start])

        var picked: [KnowledgeArticle] = []
        var topics: Set<String> = []
        for article in rotated where picked.count < count && !topics.contains(article.topic) {
            picked.append(article)
            topics.insert(article.topic)
        }
        for article in rotated where picked.count < count && !picked.contains(where: { $0.id == article.id }) {
            picked.append(article)
        }
        return picked
    }
}
