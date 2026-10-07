import KickCore
import SwiftUI

/// The article a row opened (`fullScreenCover(item:)`).
struct KnowledgeSelection: Identifiable, Equatable {
    let id: String
}

/// Article rows on a card, separated by hairlines (phase 7 spec §4.1–4.2): the
/// topic symbol in a tinted circle, the title and a two-line summary. Each row
/// is a button with the identifier `<identifierPrefix>-<article id>`.
struct KnowledgeRows: View {
    let articles: [KnowledgeArticle]
    let topics: [KnowledgeTopic]
    let language: ContentLanguage
    /// "knowledgeSuggestion" on Today, "knowledgeArticle" in the library.
    let identifierPrefix: String
    let onSelect: (KnowledgeArticle) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                if index > 0 { LunaDivider() }
                Button { onSelect(article) } label: {
                    KnowledgeRowLabel(article: article, symbol: symbol(for: article), language: language)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(identifierPrefix)-\(article.id)")
            }
        }
    }

    private func symbol(for article: KnowledgeArticle) -> String {
        topics.first { $0.id == article.topic }?.symbol ?? "book"
    }
}

private struct KnowledgeRowLabel: View {
    let article: KnowledgeArticle
    let symbol: String
    let language: ContentLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.luna(.pregOnSoft))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.luna(.pregSoft)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(article.title.text(language))
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Text(article.summary.text(language))
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.luna(.chevron))
                .padding(.top, 12)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
