import Foundation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "content")

public enum KnowledgeLoadError: Error, Equatable {
    case resourceMissing
    case unsupportedVersion(Int)
}

/// One topic and its articles for a trimester: a section of the library screen.
public struct KnowledgeTopicSection: Equatable, Sendable, Identifiable {
    public let topic: KnowledgeTopic
    public let articles: [KnowledgeArticle]

    public var id: String { topic.id }
}

/// The bundled knowledge articles (phase 7 spec §3.2–3.3).
public struct KnowledgeLibrary: Sendable {
    public static let resourceName = "knowledge-content"
    public static let supportedVersion = 1

    public let document: KnowledgeContent

    public init(document: KnowledgeContent) {
        self.document = document
    }

    /// Throws on malformed JSON or a version other than `supportedVersion`.
    public init(data: Data) throws {
        let document = try JSONDecoder().decode(KnowledgeContent.self, from: data)
        guard document.version == Self.supportedVersion else {
            throw KnowledgeLoadError.unsupportedVersion(document.version)
        }
        self.init(document: document)
    }

    /// In display order.
    public var topics: [KnowledgeTopic] { document.topics }
    public var sources: [String] { document.sources }

    public func topic(id: String) -> KnowledgeTopic? {
        document.topics.first { $0.id == id }
    }

    public func article(id: String) -> KnowledgeArticle? {
        document.articles.first { $0.id == id }
    }

    /// Every article, minus the unreviewed ones under `.reviewedOnly` (release builds).
    public func articles(visibility: ContentVisibility) -> [KnowledgeArticle] {
        switch visibility {
        case .all: document.articles
        case .reviewedOnly: document.articles.filter(\.reviewed)
        }
    }

    /// The library screen for `trimester`: topics in display order, each with its
    /// articles in file order; topics without an article for the trimester are left out.
    public func sections(trimester: Trimester, visibility: ContentVisibility) -> [KnowledgeTopicSection] {
        let visible = articles(visibility: visibility).filter { $0.applies(to: trimester) }
        return document.topics.compactMap { topic in
            let articles = visible.filter { $0.topic == topic.id }
            return articles.isEmpty ? nil : KnowledgeTopicSection(topic: topic, articles: articles)
        }
    }

    /// Today's card: `KnowledgeSuggester` over the visible articles.
    public func suggestions(forWeek week: Int, visibility: ContentVisibility, count: Int = KnowledgeSuggester.defaultCount) -> [KnowledgeArticle] {
        KnowledgeSuggester.suggestions(
            for: week,
            from: articles(visibility: visibility),
            topicOrder: document.topics.map(\.id),
            count: count
        )
    }

    /// The article's citations, skipping any index that does not exist.
    public func references(for article: KnowledgeArticle) -> [String] {
        article.sources.compactMap { sources.indices.contains($0) ? sources[$0] : nil }
    }

    /// The content bundled in KickCore's resources. Throws if it is missing or invalid.
    public static func bundled() throws -> KnowledgeLibrary {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json") else {
            throw KnowledgeLoadError.resourceMissing
        }
        return try KnowledgeLibrary(data: Data(contentsOf: url))
    }

    /// Loads `url`; logs and returns nil when it is nil, unreadable, malformed or
    /// of another version, so the app hides the card and the library instead of crashing.
    public static func load(from url: URL?) -> KnowledgeLibrary? {
        do {
            guard let url else { throw KnowledgeLoadError.resourceMissing }
            return try KnowledgeLibrary(data: Data(contentsOf: url))
        } catch {
            logger.error("Loading knowledge content failed: \(String(describing: error))")
            return nil
        }
    }

    /// `load(from:)` for the bundled file.
    public static func loadBundled() -> KnowledgeLibrary? {
        load(from: Bundle.module.url(forResource: resourceName, withExtension: "json"))
    }
}
