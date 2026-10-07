import Foundation
import Testing
@testable import KickCore

/// Phase 7 spec §3.5 on fixtures (`KnowledgeTestSupport.swift`).
struct KnowledgeChecksTests {
    /// Every catalogue article (spec §3.1), each passing the checks.
    private func completeKnowledgeContent() -> KnowledgeContent {
        knowledgeContent(KnowledgeChecks.catalogue.map { knowledgeArticle($0.id, topic: $0.topic, trimesters: $0.trimesters) })
    }

    private func safeExercise() -> KnowledgeArticle {
        knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3])
    }

    private func issues(_ article: KnowledgeArticle) -> [KnowledgeIssue] {
        KnowledgeChecks.validate(knowledgeContent([article]))
    }

    @Test func catalogueMatchesTheSpec() {
        #expect(KnowledgeChecks.topicIDs == knowledgeTopicIDs)
        #expect(KnowledgeChecks.catalogue.count == 18)
        #expect(KnowledgeChecks.articleIDs.count == 18)
        for topic in KnowledgeChecks.topicIDs {
            #expect(KnowledgeChecks.catalogue.filter { $0.topic == topic }.count == 3, "\(topic)")
        }
        let perTrimester = (1...3).map { trimester in KnowledgeChecks.catalogue.filter { $0.trimesters.contains(trimester) }.count }
        #expect(perTrimester == [7, 9, 11])
    }

    @Test func validContentPasses() {
        #expect(KnowledgeChecks.validate(knowledgeContent([])).isEmpty)
        #expect(issues(safeExercise()).isEmpty)
        #expect(KnowledgeChecks.validate(completeKnowledgeContent(), requiredArticleIDs: KnowledgeChecks.articleIDs).isEmpty)
    }

    @Test func versionSourcesAndTopicsAreChecked() {
        var content = knowledgeContent([])
        content.version = 2
        content.sources[1] = " "
        content.topics.swapAt(0, 1)
        content.topics[2].name.vi = ""
        content.topics[3].symbol = ""
        let found = KnowledgeChecks.validate(content)
        #expect(found.contains(.wrongVersion(2)))
        #expect(found.contains(.blankSource(index: 1)))
        #expect(found.contains(.topicsMismatch(found: ["movement", "nutrition", "sleep", "feelings", "checkups", "birth"])))
        #expect(found.contains(.blankTopic(topic: "sleep", language: .vi)))
        #expect(found.contains(.blankTopic(topic: "feelings", language: nil)))
        #expect(found.count == 5)
    }

    @Test func missingArticlesAreReportedOnlyWhenRequired() {
        let content = knowledgeContent([safeExercise()])
        #expect(KnowledgeChecks.validate(content, requiredArticleIDs: ["safe-exercise"]).isEmpty)
        #expect(
            KnowledgeChecks.validate(content, requiredArticleIDs: ["safe-exercise", "food-safety"])
                == [.missingArticle(id: "food-safety")]
        )
    }

    @Test func unknownDuplicateAndMisfiledArticlesAreReported() {
        var wrongTopic = knowledgeArticle("food-safety", topic: "movement", trimesters: [1, 2, 3])
        wrongTopic.sources = [1]
        let found = KnowledgeChecks.validate(knowledgeContent([
            safeExercise(),
            safeExercise(),
            knowledgeArticle("yoga", topic: "movement", trimesters: [2]),
            wrongTopic,
            knowledgeArticle("hospital-bag", topic: "birth", trimesters: [2, 3]),
            knowledgeArticle("signs-of-labour", topic: "birth", trimesters: []),
        ]))
        #expect(
            found == [
                .duplicateArticle(id: "safe-exercise"),
                .unknownArticle(id: "yoga"),
                .wrongTopic(article: "food-safety", topic: "movement"),
                .wrongTrimesters(article: "hospital-bag", trimesters: [2, 3]),
                .wrongTrimesters(article: "signs-of-labour", trimesters: []),
            ]
        )
    }

    @Test func trimesterCoverageIsCheckedOnceEverythingIsRequired() {
        var content = completeKnowledgeContent()
        content.articles.removeAll { $0.trimesters == [1] } // leaves 3 for trimester 1: food-safety, safe-exercise, antenatal
        #expect(KnowledgeChecks.validate(content).isEmpty)
        content.articles.removeAll { $0.id == "food-safety" }
        let found = KnowledgeChecks.validate(content, requiredArticleIDs: KnowledgeChecks.articleIDs)
        #expect(found.contains(.trimesterCoverage(trimester: 1, articles: 2)))
        #expect(!found.contains { if case .trimesterCoverage(trimester: 2, _) = $0 { true } else { false } })
    }

    @Test func sectionAndParagraphCountsAreChecked() {
        var article = safeExercise()
        article.sections = [article.sections[0]]
        #expect(issues(article).contains(.sectionCount(article: "safe-exercise", count: 1)))
        article = safeExercise()
        article.sections += article.sections + article.sections // 6 sections
        #expect(issues(article).contains(.sectionCount(article: "safe-exercise", count: 6)))
        article = safeExercise()
        article.sections[1].paragraphs.vi = []
        article.sections[0].paragraphs.en = Array(repeating: knowledgeWords(30, "word"), count: 5)
        let found = issues(article)
        #expect(found.contains(.paragraphCount(article: "safe-exercise", section: 2, language: .vi, count: 0)))
        #expect(found.contains(.paragraphCount(article: "safe-exercise", section: 1, language: .en, count: 5)))
    }

    @Test func blankTextIsReported() {
        var article = safeExercise()
        article.title.en = " "
        article.sections[1].heading.vi = ""
        article.sections[0].paragraphs.en[1] = "\n"
        let found = issues(article)
        #expect(found.contains(.blankText(article: "safe-exercise", field: "title", language: .en)))
        #expect(found.contains(.blankText(article: "safe-exercise", field: "section 2 heading", language: .vi)))
        #expect(found.contains(.blankText(article: "safe-exercise", field: "section 1", language: .en)))
    }

    @Test func summaryLimits() {
        var article = safeExercise()
        article.summary = LocalizedText(en: knowledgeWords(36, "word"), vi: knowledgeWords(46, "chữ"))
        let found = issues(article)
        #expect(found.contains(.summaryTooLong(article: "safe-exercise", language: .en, words: 36)))
        #expect(found.contains(.summaryTooLong(article: "safe-exercise", language: .vi, words: 46)))
        article.summary = LocalizedText(en: knowledgeWords(35, "word"), vi: knowledgeWords(45, "chữ"))
        #expect(issues(article).isEmpty)
    }

    @Test func lengthCountsSummaryHeadingsAndParagraphsButNotTheTitle() {
        var article = safeExercise()
        #expect(KnowledgeChecks.articleWordCount(article, language: .en) == 326)
        #expect(KnowledgeChecks.articleWordCount(article, language: .vi) == 358)
        article.title.en = knowledgeWords(200, "word")
        #expect(KnowledgeChecks.articleWordCount(article, language: .en) == 326)
        article = safeExercise()
        article.sections[0].paragraphs.en = [knowledgeWords(20, "word")] // 326 − 150 + 20 = 196
        article.sections[1].paragraphs.vi[0] = knowledgeWords(250, "chữ") // 358 − 80 + 250 = 528
        let found = issues(article)
        #expect(found.contains(.length(article: "safe-exercise", language: .en, words: 196)))
        #expect(found.contains(.length(article: "safe-exercise", language: .vi, words: 528)))
    }

    @Test func sourcesMustBeValid() {
        var article = safeExercise()
        article.sources = []
        #expect(issues(article) == [.noSources(article: "safe-exercise")])
        article.sources = [1, 2, -1]
        #expect(
            issues(article) == [
                .invalidSource(article: "safe-exercise", index: 2),
                .invalidSource(article: "safe-exercise", index: -1),
            ]
        )
    }

    @Test func imperialUnitsAreReported() {
        var article = safeExercise()
        article.sections[0].paragraphs.en[0] = "Walk about 2 miles or carry 10 lbs. " + knowledgeWords(67, "word")
        let found = issues(article)
        #expect(found == [.imperialUnit(article: "safe-exercise", field: "section 1", language: .en)])
    }

    @Test func doseUnitsAreReportedOutsideTheCaffeineSentences() {
        var article = safeExercise()
        article.sections[0].paragraphs.en[0] = "Take 400 mcg a day. " + knowledgeWords(70, "word")
        article.sections[1].paragraphs.vi[0] = "Uống 1000 IU mỗi ngày. " + knowledgeWords(75, "chữ")
        #expect(
            issues(article) == [
                .doseUnit(article: "safe-exercise", field: "section 1", language: .en),
                .doseUnit(article: "safe-exercise", field: "section 2", language: .vi),
            ]
        )
        article = safeExercise()
        article.sections[0].paragraphs.en[0] = KnowledgeChecks.doseAllowList[0] + " " + knowledgeWords(55, "word")
        article.sections[0].paragraphs.vi[0] = KnowledgeChecks.doseAllowList[1] + " " + knowledgeWords(50, "chữ")
        #expect(!issues(article).contains { if case .doseUnit = $0 { true } else { false } })
        #expect(KnowledgeChecks.containsDoseUnit(KnowledgeChecks.doseAllowList[0] + " Then 300 mg more."))
    }

    @Test func vietnameseTextNeedsDiacritics() {
        var article = safeExercise()
        article.sections[0].heading.vi = "Yoga cho ba bau"
        #expect(issues(article) == [.missingDiacritics(article: "safe-exercise", field: "section 1 heading")])
    }

    @Test func reviewedArticlesAreReported() {
        #expect(
            issues(knowledgeArticle("safe-exercise", topic: "movement", trimesters: [1, 2, 3], reviewed: true))
                == [.reviewed(article: "safe-exercise")]
        )
    }
}
