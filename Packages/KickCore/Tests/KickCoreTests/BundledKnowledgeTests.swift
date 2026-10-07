import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.5: the knowledge articles in the shipped `knowledge-content.json`.
struct BundledKnowledgeTests {
    /// Articles that must already be written. Each task widens it:
    /// [] (Task 1) → safe-exercise (Task 2) → + nutrition and movement (Task 3)
    /// → + sleep and feelings (Task 4) → KnowledgeChecks.articleIDs (Task 5).
    static let requiredArticleIDs: Set<String> = [
        "nutrition-first-trimester", "food-safety", "iron-calcium-balanced-meals",
        "safe-exercise", "gentle-exercise-second-trimester", "pelvic-floor-posture",
    ]

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
