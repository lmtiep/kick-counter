import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.5: the knowledge articles in the shipped `knowledge-content.json`.
struct BundledKnowledgeTests {
    /// Every article of spec §3.1 must be written (spec §3.5); trimester coverage is checked too.
    static let requiredArticleIDs: Set<String> = KnowledgeChecks.articleIDs

    let library: KnowledgeLibrary

    init() throws {
        library = try KnowledgeLibrary.bundled()
    }

    @Test func contentIsVersion1WithTheSixTopics() {
        #expect(library.document.version == KnowledgeLibrary.supportedVersion)
        #expect(library.topics.map(\.id) == KnowledgeChecks.topicIDs)
        #expect(KnowledgeLibrary.loadBundled() != nil)
    }

    @Test func everyWrittenArticlePassesTheChecks() {
        let issues = KnowledgeChecks.validate(library.document, requiredArticleIDs: Self.requiredArticleIDs)
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test func articlesAreInCatalogueOrder() {
        let order = KnowledgeChecks.catalogue.map(\.id)
        let written = library.document.articles.map(\.id)
        #expect(written == order.filter { written.contains($0) })
    }
}
