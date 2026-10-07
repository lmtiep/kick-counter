import KickCore
import SwiftUI

/// "Suggested for trimester N" on pregnancy Today (phase 7 spec §4.1): up to
/// three article rows and a "See more" pill that opens the library. A row opens
/// the reading screen, which this card presents itself.
struct KnowledgeCard: View {
    let trimester: Int
    let suggestions: [KnowledgeArticle]
    let topics: [KnowledgeTopic]
    let language: ContentLanguage
    let onSeeMore: () -> Void

    @State private var reading: KnowledgeSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.knowledgeCardTitle(trimester))
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            KnowledgeRows(
                articles: suggestions,
                topics: topics,
                language: language,
                identifierPrefix: "knowledgeSuggestion"
            ) { reading = KnowledgeSelection(id: $0.id) }
            Button(L10n.knowledgeSeeMore, action: onSeeMore)
                .buttonStyle(.pill(.soft(.pregSoft, .pregOnSoft), fullWidth: false, height: 40))
                .accessibilityIdentifier("knowledgeSeeMore")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lunaCard(padding: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("knowledgeCard")
        .fullScreenCover(item: $reading) { selection in
            KnowledgeArticleView(articleID: selection.id)
        }
    }
}
