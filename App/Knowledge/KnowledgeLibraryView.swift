import KickCore
import SwiftUI

/// "Kiến thức" (phase 7 spec §4.2): trimester chips, then the chosen trimester's
/// articles grouped by topic in display order. A row opens the reading screen.
struct KnowledgeLibraryView: View {
    @Environment(\.knowledgeLibrary) private var library
    @State private var trimester: Int
    @State private var reading: KnowledgeSelection?
    private let language = ContentLanguage.current
    private let visibility = BuildFlags.contentVisibility

    /// `initialTrimester`: the current trimester, or nil without a due date (→ 1).
    init(initialTrimester: Int?) {
        _trimester = State(initialValue: min(max(initialTrimester ?? 1, 1), 3))
    }

    private var sections: [KnowledgeTopicSection] {
        guard let library, let value = Trimester(rawValue: trimester) else { return [] }
        return library.sections(trimester: value, visibility: visibility)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ChipScroller(
                    values: Trimester.allCases.map(\.rawValue),
                    selection: $trimester,
                    title: { L10n.pregnancyTrimester($0) },
                    identifier: { "knowledgeTrimester-\($0)" },
                    accessibilityTitle: nil,
                    selectedFill: .pregSoft,
                    selectedText: .pregOnSoft,
                    idleText: .textSecondary
                )
                .padding(.top, 8)
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.topic.name.text(language))
                            .font(.luna(.cardTitle))
                            .foregroundStyle(.luna(.textPrimary))
                            .accessibilityAddTraits(.isHeader)
                        KnowledgeRows(
                            articles: section.articles,
                            topics: library?.topics ?? [],
                            language: language,
                            identifierPrefix: "knowledgeArticle"
                        ) { reading = KnowledgeSelection(id: $0.id) }
                        .lunaCard(padding: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                }
            }
            .padding(.bottom, 24)
        }
        // Content scrolled up stays out from under the status bar.
        .lunaStatusBarBackdrop()
        .background(.luna(.background))
        .navigationTitle(L10n.knowledgeTitle)
        .fullScreenCover(item: $reading) { selection in
            KnowledgeArticleView(articleID: selection.id)
        }
    }
}
