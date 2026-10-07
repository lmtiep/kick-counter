import Foundation

/// Root of `knowledge-content.json` (phase 7 spec §3.2): in-depth articles
/// grouped by topic and tagged by trimester. Checked by `KnowledgeChecks`.
public struct KnowledgeContent: Codable, Equatable, Sendable {
    public var version: Int
    /// Full citations; articles refer to them by index (append-only, never reordered).
    public var sources: [String]
    /// In display order.
    public var topics: [KnowledgeTopic]
    public var articles: [KnowledgeArticle]
}

public struct KnowledgeTopic: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: LocalizedText
    /// SF Symbol name: the row icon, and the reading screen's artwork fallback.
    public var symbol: String
}

public struct KnowledgeArticle: Codable, Equatable, Sendable, Identifiable {
    /// Stable kebab-case id, e.g. "safe-exercise".
    public var id: String
    /// A `KnowledgeTopic.id`.
    public var topic: String
    /// The trimesters the article applies to: a non-empty, ascending subset of 1...3.
    public var trimesters: [Int]
    /// False until the obstetrician signs the article off; release builds hide it.
    public var reviewed: Bool
    public var title: LocalizedText
    /// One sentence: the row subtitle and the bold lead of the reading screen.
    public var summary: LocalizedText
    /// 2–4 sections.
    public var sections: [KnowledgeSection]
    /// Indices into `KnowledgeContent.sources`; at least one.
    public var sources: [Int]

    public func applies(to trimester: Trimester) -> Bool {
        trimesters.contains(trimester.rawValue)
    }

    /// Every text of one language with its field name, in reading order:
    /// "title", "summary", then "section N heading" and "section N" (paragraphs), N from 1.
    func texts(_ language: ContentLanguage) -> [(field: String, text: String)] {
        var result: [(field: String, text: String)] = [
            (field: "title", text: title.text(language)),
            (field: "summary", text: summary.text(language)),
        ]
        for (index, section) in sections.enumerated() {
            result.append((field: "section \(index + 1) heading", text: section.heading.text(language)))
            for paragraph in section.paragraphs.paragraphs(language) {
                result.append((field: "section \(index + 1)", text: paragraph))
            }
        }
        return result
    }
}

public struct KnowledgeSection: Codable, Equatable, Sendable {
    public var heading: LocalizedText
    /// 1–4 paragraphs per language.
    public var paragraphs: LocalizedParagraphs
}

/// The optional per-article artwork asset (phase 7 spec §4.3). The app falls back
/// to the topic's SF Symbol while an asset is missing.
public enum KnowledgeArtworkName {
    /// "Knowledge-safe-exercise".
    public static func asset(articleID: String) -> String { "Knowledge-" + articleID }
}
