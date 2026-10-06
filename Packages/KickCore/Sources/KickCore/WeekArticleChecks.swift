import Foundation

/// The two tabs of the week article sheet (phase 6 spec §3.3).
public enum ArticleTab: String, Sendable, CaseIterable, Hashable {
    case baby
    case mom
}

public enum ArticleIssue: Equatable, Sendable {
    /// The week is inside the required range but has no `article`.
    case missingArticle(week: Int)
    /// `field` ("sizeNote", "development", "body", "todo") has no paragraphs in `language`.
    case emptyParagraphs(week: Int, field: String, language: ContentLanguage)
    /// `field` ("lead" or a paragraph field) has an empty or whitespace-only text.
    case blankText(week: Int, field: String, language: ContentLanguage)
    case leadTooLong(week: Int, language: ContentLanguage, words: Int)
    /// A tab's words (Bé: lead + sizeNote + development; Mẹ: body + todo) outside 150–300.
    case tabLength(week: Int, tab: ArticleTab, language: ContentLanguage, words: Int)
    case noSources(week: Int)
    case invalidSource(week: Int, index: Int)
    /// An inch / pound / ounce unit or "″" in `field` (metric only).
    case imperialUnit(week: Int, field: String, language: ContentLanguage)
}

/// Automatic checks of the week articles (phase 6 spec §4.4–4.5), enforced by
/// unit tests on the bundled JSON. Accuracy and tone are reviewed by people.
public enum WeekArticleChecks {
    /// Maximum words in the bold lead.
    public static let leadLimit: [ContentLanguage: Int] = [.en: 30, .vi: 40]
    /// Words per tab per language (Vietnamese: syllables, which are space-separated).
    public static let tabWords: ClosedRange<Int> = 150...300

    /// Every article present is checked; `requiredWeeks` (nil = none) also reports
    /// weeks in that range without an article.
    public static func validate(_ content: PregnancyContent, requiredWeeks: ClosedRange<Int>? = nil) -> [ArticleIssue] {
        var issues: [ArticleIssue] = []
        if let requiredWeeks {
            let written = Set(content.weeks.filter { $0.article != nil }.map(\.week))
            for week in requiredWeeks where !written.contains(week) {
                issues.append(.missingArticle(week: week))
            }
        }
        for week in content.weeks {
            guard let article = week.article else { continue }
            issues += articleIssues(article, week: week.week, sourceCount: content.sources.count)
        }
        return issues
    }

    public static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    public static func tabWordCount(_ article: WeekArticle, tab: ArticleTab, language: ContentLanguage) -> Int {
        let paragraphs: [String]
        switch tab {
        case .baby:
            paragraphs = [article.lead.text(language)]
                + article.sizeNote.paragraphs(language)
                + article.development.paragraphs(language)
        case .mom:
            paragraphs = article.body.paragraphs(language) + article.todo.paragraphs(language)
        }
        return paragraphs.map(wordCount).reduce(0, +)
    }

    /// inch(es), pound(s), lb(s), ounce(s), oz as whole words (any case), or "″".
    public static func containsImperialUnit(_ text: String) -> Bool {
        text.contains("″")
            || text.firstMatch(of: /(?i)\b(?:inch|inches|pound|pounds|lb|lbs|ounce|ounces|oz)\b/) != nil
    }

    private static func articleIssues(_ article: WeekArticle, week: Int, sourceCount: Int) -> [ArticleIssue] {
        var issues: [ArticleIssue] = []
        for language in ContentLanguage.allCases {
            let lead = article.lead.text(language)
            if ContentValidator.isBlank(lead) {
                issues.append(.blankText(week: week, field: "lead", language: language))
            }
            let leadWords = wordCount(lead)
            if leadWords > leadLimit[language, default: 0] {
                issues.append(.leadTooLong(week: week, language: language, words: leadWords))
            }
            for field in article.paragraphFields {
                let paragraphs = field.paragraphs.paragraphs(language)
                if paragraphs.isEmpty {
                    issues.append(.emptyParagraphs(week: week, field: field.name, language: language))
                }
                if paragraphs.contains(where: ContentValidator.isBlank) {
                    issues.append(.blankText(week: week, field: field.name, language: language))
                }
            }
            for tab in ArticleTab.allCases {
                let words = tabWordCount(article, tab: tab, language: language)
                if !tabWords.contains(words) {
                    issues.append(.tabLength(week: week, tab: tab, language: language, words: words))
                }
            }
            for (field, text) in article.texts(language) where containsImperialUnit(text) {
                issues.append(.imperialUnit(week: week, field: field, language: language))
            }
        }
        if article.sources.isEmpty { issues.append(.noSources(week: week)) }
        for index in article.sources where !(0..<sourceCount).contains(index) {
            issues.append(.invalidSource(week: week, index: index))
        }
        return issues
    }
}
