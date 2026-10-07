import Foundation

public enum KnowledgeIssue: Equatable, Sendable {
    /// `version` is not `KnowledgeLibrary.supportedVersion`.
    case wrongVersion(Int)
    case blankSource(index: Int)
    /// The topic ids are not exactly `KnowledgeChecks.topicIDs`, in that order.
    case topicsMismatch(found: [String])
    /// A topic's name is blank in `language`, or its symbol is blank (`language` nil).
    case blankTopic(topic: String, language: ContentLanguage?)
    /// An article id that is not in `KnowledgeChecks.catalogue`.
    case unknownArticle(id: String)
    case duplicateArticle(id: String)
    /// A required article (`requiredArticleIDs`) is not in the file.
    case missingArticle(id: String)
    /// The article's `topic` is not the one the catalogue gives it.
    case wrongTopic(article: String, topic: String)
    /// `trimesters` is empty, outside 1...3, not strictly ascending, or not the catalogue's.
    case wrongTrimesters(article: String, trimesters: [Int])
    /// Fewer than `minimumPerTrimester` articles for a trimester (checked once every article is required).
    case trimesterCoverage(trimester: Int, articles: Int)
    case sectionCount(article: String, count: Int)
    /// Section `section` (from 1) has a paragraph count outside 1...4 in `language`.
    case paragraphCount(article: String, section: Int, language: ContentLanguage, count: Int)
    /// `field` ("title", "summary", "section N heading", "section N") is empty or whitespace.
    case blankText(article: String, field: String, language: ContentLanguage)
    case summaryTooLong(article: String, language: ContentLanguage, words: Int)
    /// Summary + headings + paragraphs outside 300–500 words.
    case length(article: String, language: ContentLanguage, words: Int)
    case noSources(article: String)
    case invalidSource(article: String, index: Int)
    case imperialUnit(article: String, field: String, language: ContentLanguage)
    /// mg, mcg, µg or IU outside an allow-listed caffeine sentence.
    case doseUnit(article: String, field: String, language: ContentLanguage)
    /// A Vietnamese text without any non-ASCII letter (likely English or unaccented).
    case missingDiacritics(article: String, field: String)
    /// `reviewed` is true; only the obstetrician's sign-off may set it (spec §3.5).
    case reviewed(article: String)
}

/// Automatic checks of `knowledge-content.json` (phase 7 spec §3.5), enforced by
/// unit tests on the bundled file. Accuracy and tone are reviewed by people.
public enum KnowledgeChecks {
    /// An article of spec §3.1: its id, topic and trimesters.
    public struct Entry: Sendable, Equatable {
        public let id: String
        public let topic: String
        public let trimesters: [Int]
    }

    /// The six topics, in display order.
    public static let topicIDs = ["nutrition", "movement", "sleep", "feelings", "checkups", "birth"]

    /// The 18 articles of spec §3.1, in file order.
    public static let catalogue: [Entry] = [
        Entry(id: "nutrition-first-trimester", topic: "nutrition", trimesters: [1]),
        Entry(id: "food-safety", topic: "nutrition", trimesters: [1, 2, 3]),
        Entry(id: "iron-calcium-balanced-meals", topic: "nutrition", trimesters: [2, 3]),
        Entry(id: "safe-exercise", topic: "movement", trimesters: [1, 2, 3]),
        Entry(id: "gentle-exercise-second-trimester", topic: "movement", trimesters: [2]),
        Entry(id: "pelvic-floor-posture", topic: "movement", trimesters: [2, 3]),
        Entry(id: "first-trimester-tiredness", topic: "sleep", trimesters: [1]),
        Entry(id: "sleep-positions", topic: "sleep", trimesters: [2, 3]),
        Entry(id: "sleeping-well-late-pregnancy", topic: "sleep", trimesters: [3]),
        Entry(id: "early-pregnancy-worries", topic: "feelings", trimesters: [1]),
        Entry(id: "changing-body-feelings", topic: "feelings", trimesters: [2]),
        Entry(id: "preparing-for-motherhood", topic: "feelings", trimesters: [3]),
        Entry(id: "antenatal-checkup-milestones", topic: "checkups", trimesters: [1, 2, 3]),
        Entry(id: "first-trimester-screening", topic: "checkups", trimesters: [1]),
        Entry(id: "anomaly-scan-glucose-test", topic: "checkups", trimesters: [2]),
        Entry(id: "signs-of-labour", topic: "birth", trimesters: [3]),
        Entry(id: "hospital-bag", topic: "birth", trimesters: [3]),
        Entry(id: "birth-plan-breastfeeding", topic: "birth", trimesters: [3]),
    ]

    public static var articleIDs: Set<String> { Set(catalogue.map(\.id)) }

    /// Maximum words in the summary.
    public static let summaryLimit: [ContentLanguage: Int] = [.en: 35, .vi: 45]
    /// Summary + headings + paragraphs, per language (Vietnamese: syllables).
    public static let articleWords: ClosedRange<Int> = 300...500
    public static let sectionRange: ClosedRange<Int> = 2...4
    public static let paragraphRange: ClosedRange<Int> = 1...4
    public static let minimumPerTrimester = 3

    /// The only sentences that may contain a dose unit: the caffeine limit used in
    /// `food-safety` (spec §3.5). Copy them into the article exactly.
    public static let doseAllowList: [String] = [
        "Most guidelines suggest keeping caffeine below 200 mg a day in total, counting coffee, tea, cola, energy drinks and chocolate.",
        "Phần lớn các hướng dẫn khuyên mẹ giữ tổng lượng caffeine dưới 200 mg mỗi ngày, tính cả cà phê, trà, nước cola, nước tăng lực và sô-cô-la.",
    ]

    /// Every article present is checked in full; `requiredArticleIDs` also reports
    /// the ones missing. Trimester coverage is checked once every catalogue article is required.
    public static func validate(_ content: KnowledgeContent, requiredArticleIDs: Set<String> = []) -> [KnowledgeIssue] {
        var issues: [KnowledgeIssue] = []
        if content.version != KnowledgeLibrary.supportedVersion {
            issues.append(.wrongVersion(content.version))
        }
        for (index, source) in content.sources.enumerated() where ContentValidator.isBlank(source) {
            issues.append(.blankSource(index: index))
        }
        issues += topicIssues(content.topics)

        let entries = Dictionary(uniqueKeysWithValues: catalogue.map { ($0.id, $0) })
        var seen: Set<String> = []
        for article in content.articles {
            if !seen.insert(article.id).inserted {
                issues.append(.duplicateArticle(id: article.id))
                continue
            }
            if let entry = entries[article.id] {
                if article.topic != entry.topic {
                    issues.append(.wrongTopic(article: article.id, topic: article.topic))
                }
                if article.trimesters != entry.trimesters || !isValidTrimesterList(article.trimesters) {
                    issues.append(.wrongTrimesters(article: article.id, trimesters: article.trimesters))
                }
            } else {
                issues.append(.unknownArticle(id: article.id))
            }
            issues += articleIssues(article, sourceCount: content.sources.count)
        }
        for entry in catalogue where requiredArticleIDs.contains(entry.id) && !seen.contains(entry.id) {
            issues.append(.missingArticle(id: entry.id))
        }
        if articleIDs.isSubset(of: requiredArticleIDs) {
            for trimester in Trimester.allCases {
                let count = content.articles.filter { $0.applies(to: trimester) }.count
                if count < minimumPerTrimester {
                    issues.append(.trimesterCoverage(trimester: trimester.rawValue, articles: count))
                }
            }
        }
        return issues
    }

    public static func wordCount(_ text: String) -> Int {
        WeekArticleChecks.wordCount(text)
    }

    /// Summary + headings + paragraphs (spec §3.4); the title is not counted.
    public static func articleWordCount(_ article: KnowledgeArticle, language: ContentLanguage) -> Int {
        article.texts(language)
            .filter { $0.field != "title" }
            .map { wordCount($0.text) }
            .reduce(0, +)
    }

    /// mg, mcg, µg or IU as a whole word, once the allow-listed sentences are removed.
    public static func containsDoseUnit(_ text: String) -> Bool {
        let remaining = doseAllowList.reduce(text) { $0.replacingOccurrences(of: $1, with: "") }
        return remaining.firstMatch(of: /\b(?:mg|mcg|µg|IU)\b/) != nil
    }

    private static func isValidTrimesterList(_ trimesters: [Int]) -> Bool {
        !trimesters.isEmpty
            && trimesters.allSatisfy { (1...3).contains($0) }
            && zip(trimesters, trimesters.dropFirst()).allSatisfy { $0 < $1 }
    }

    private static func topicIssues(_ topics: [KnowledgeTopic]) -> [KnowledgeIssue] {
        var issues: [KnowledgeIssue] = []
        if topics.map(\.id) != topicIDs {
            issues.append(.topicsMismatch(found: topics.map(\.id)))
        }
        for topic in topics {
            for language in ContentLanguage.allCases where ContentValidator.isBlank(topic.name.text(language)) {
                issues.append(.blankTopic(topic: topic.id, language: language))
            }
            if ContentValidator.isBlank(topic.symbol) {
                issues.append(.blankTopic(topic: topic.id, language: nil))
            }
        }
        return issues
    }

    private static func articleIssues(_ article: KnowledgeArticle, sourceCount: Int) -> [KnowledgeIssue] {
        let id = article.id
        var issues: [KnowledgeIssue] = []
        if article.reviewed { issues.append(.reviewed(article: id)) }
        if !sectionRange.contains(article.sections.count) {
            issues.append(.sectionCount(article: id, count: article.sections.count))
        }
        for language in ContentLanguage.allCases {
            for (index, section) in article.sections.enumerated() {
                let count = section.paragraphs.paragraphs(language).count
                if !paragraphRange.contains(count) {
                    issues.append(.paragraphCount(article: id, section: index + 1, language: language, count: count))
                }
            }
            let texts = article.texts(language)
            for (field, text) in texts {
                if ContentValidator.isBlank(text) {
                    issues.append(.blankText(article: id, field: field, language: language))
                }
                if WeekArticleChecks.containsImperialUnit(text) {
                    issues.append(.imperialUnit(article: id, field: field, language: language))
                }
                if containsDoseUnit(text) {
                    issues.append(.doseUnit(article: id, field: field, language: language))
                }
                if language == .vi, !text.unicodeScalars.contains(where: { $0.value > 127 }) {
                    issues.append(.missingDiacritics(article: id, field: field))
                }
            }
            let summaryWords = wordCount(article.summary.text(language))
            if summaryWords > summaryLimit[language, default: 0] {
                issues.append(.summaryTooLong(article: id, language: language, words: summaryWords))
            }
            let words = articleWordCount(article, language: language)
            if !articleWords.contains(words) {
                issues.append(.length(article: id, language: language, words: words))
            }
        }
        if article.sources.isEmpty { issues.append(.noSources(article: id)) }
        for index in article.sources where !(0..<sourceCount).contains(index) {
            issues.append(.invalidSource(article: id, index: index))
        }
        return issues
    }
}
