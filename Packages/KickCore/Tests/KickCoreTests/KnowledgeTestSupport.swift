import Foundation
@testable import KickCore

/// `count` words ending in a full stop: knowledgeWords(3, "chữ") == "chữ chữ chữ."
func knowledgeWords(_ count: Int, _ word: String) -> String {
    Array(repeating: word, count: count).joined(separator: " ") + "."
}

/// The topic ids of spec §3.1, in display order.
let knowledgeTopicIDs = ["nutrition", "movement", "sleep", "feelings", "checkups", "birth"]

/// A topic with a placeholder name.
func knowledgeTopic(_ id: String) -> KnowledgeTopic {
    KnowledgeTopic(id: id, name: LocalizedText(en: "Topic \(id)", vi: "Chủ đề \(id)"), symbol: "book")
}

/// An article that passes every check with two sources available.
/// en: summary 20 + headings 2 × 3 + paragraphs 4 × 75 = 326 words.
/// vi: summary 30 + headings 2 × 4 + paragraphs 4 × 80 = 358 words.
func knowledgeArticle(
    _ id: String,
    topic: String,
    trimesters: [Int],
    reviewed: Bool = false
) -> KnowledgeArticle {
    let section = KnowledgeSection(
        heading: LocalizedText(en: knowledgeWords(3, "word"), vi: knowledgeWords(4, "mục")),
        paragraphs: LocalizedParagraphs(
            en: [knowledgeWords(75, "word"), knowledgeWords(75, "word")],
            vi: [knowledgeWords(80, "chữ"), knowledgeWords(80, "chữ")]
        )
    )
    return KnowledgeArticle(
        id: id,
        topic: topic,
        trimesters: trimesters,
        reviewed: reviewed,
        title: LocalizedText(en: "Title \(id)", vi: "Tiêu đề \(id)"),
        summary: LocalizedText(en: knowledgeWords(20, "word"), vi: knowledgeWords(30, "chữ")),
        sections: [section, section],
        sources: [0]
    )
}

/// Version 1 with the six topics of spec §3.1, two sources and `articles`.
func knowledgeContent(_ articles: [KnowledgeArticle]) -> KnowledgeContent {
    KnowledgeContent(
        version: 1,
        sources: ["Source A", "Source B"],
        topics: knowledgeTopicIDs.map(knowledgeTopic),
        articles: articles
    )
}
