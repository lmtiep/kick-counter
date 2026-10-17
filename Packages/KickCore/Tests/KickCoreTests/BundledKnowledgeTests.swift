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

    /// The obstetrician reviewed every article (owner's confirmation, 17/10/2026): App Store
    /// builds (`.reviewedOnly`) show them all. The unreviewed path is covered with fixtures
    /// (`KnowledgeLibraryTests`).
    @Test func everyArticleIsReviewed() {
        #expect(library.document.articles.filter { !$0.reviewed }.map(\.id) == [])
        #expect(library.articles(visibility: .reviewedOnly).map(\.id) == library.articles(visibility: .all).map(\.id))
    }

    @Test func articlesAreInCatalogueOrder() {
        let order = KnowledgeChecks.catalogue.map(\.id)
        let written = library.document.articles.map(\.id)
        #expect(written == order.filter { written.contains($0) })
    }
}
