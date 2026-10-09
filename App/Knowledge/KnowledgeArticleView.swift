import KickCore
import SwiftUI
import UIKit

/// The article's artwork (phase 7 spec §4.3): the asset `Knowledge-<id>` when it
/// exists, otherwise the topic's SF Symbol at 96 pt in `pregOnSoft` on a soft circle.
struct KnowledgeArtwork: View {
    let articleID: String
    let symbol: String

    static func image(_ articleID: String) -> Image? {
        let name = KnowledgeArtworkName.asset(articleID: articleID)
        return UIImage(named: name) == nil ? nil : Image(name)
    }

    var body: some View {
        if let image = Self.image(articleID) {
            image.resizable().scaledToFit().padding(28)
        } else {
            Circle()
                .fill(.luna(.pregSoft))
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 96, weight: .light))
                        .foregroundStyle(.luna(.pregOnSoft))
                )
                .aspectRatio(1, contentMode: .fit)
                .padding(24)
        }
    }
}

/// The reading screen, presented full screen (phase 7 spec §4.3). It follows
/// `WeekDetailView`: the artwork on the hero gradient with the ✕ above it, and
/// `ArticleSheet` on top. The sheet header holds only the title and the review
/// row: nothing in it is a Button, because a header Button moves with a dragged
/// sheet and would fire its tap on release (phase 6 lesson). The body holds the
/// bold summary, the sections and the collapsed references.
struct KnowledgeArticleView: View {
    let articleID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.knowledgeLibrary) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var detent = SheetDetent.peek
    @State private var progress = 0.0
    private let language = ContentLanguage.current

    /// The sheet's top edge when expanded: 8 pt below the top safe area.
    private static let expandedTop: CGFloat = 8
    /// Room for the ✕ button above the artwork.
    private static let closeRowHeight: CGFloat = 52

    static func artworkHeight(containerHeight: CGFloat) -> CGFloat {
        min(containerHeight * 0.36, 320)
    }

    /// 12 pt below the artwork; never so low that the handle, title and review row leave the screen.
    static func peekTop(containerHeight: CGFloat) -> CGFloat {
        min(closeRowHeight + artworkHeight(containerHeight: containerHeight) + 12, containerHeight - 220)
    }

    private var article: KnowledgeArticle? { library?.article(id: articleID) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if let article {
                    backgroundLayer(article, height: proxy.size.height)
                    ArticleSheet(
                        detent: $detent,
                        progress: $progress,
                        peekTop: Self.peekTop(containerHeight: proxy.size.height),
                        expandedTop: Self.expandedTop,
                        containerHeight: proxy.size.height,
                        bottomInset: proxy.safeAreaInsets.bottom,
                        resetKey: article.id,
                        initialAnchor: nil,
                        handleIdentifier: "knowledgeSheetHandle",
                        scrollIdentifier: "knowledgeArticleScroll",
                        handleLabel: { $0 == .peek ? L10n.weekArticleExpand : L10n.weekArticleCollapse }
                    ) {
                        sheetHeader(article)
                    } content: {
                        sheetContent(article)
                    }
                }
                ArticleCloseButton(identifier: "knowledgeClose") { dismiss() }
            }
        }
        .background {
            LinearGradient(
                stops: [
                    .init(color: .luna(.heroTop), location: 0),
                    .init(color: .luna(.heroMiddle), location: 0.45),
                    .init(color: .luna(.backgroundBottom), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        // VoiceOver two-finger scrub closes the cover, like the ✕ button.
        .accessibilityAction(.escape) { dismiss() }
        .onAppear {
            // Accessibility text sizes and VoiceOver open expanded (phase 6 rule):
            // at peek the body does not scroll, so VoiceOver could not reach it.
            if dynamicTypeSize.isAccessibilitySize || voiceOverEnabled {
                detent = .expanded
                progress = 1
            }
        }
    }

    /// Decorative: hidden from VoiceOver.
    private func backgroundLayer(_ article: KnowledgeArticle, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Self.closeRowHeight)
            KnowledgeArtwork(articleID: article.id, symbol: library?.topic(id: article.topic)?.symbol ?? "book")
                .frame(height: Self.artworkHeight(containerHeight: height))
                .frame(maxWidth: .infinity)
                .opacity(1 - progress)
                .scaleEffect(reduceMotion ? 1 : 1 - 0.1 * progress)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }

    private func sheetHeader(_ article: KnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.title.text(language))
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("knowledgeTitle")
            ArticleReviewerRow(
                pendingReview: !article.reviewed,
                reviewedText: L10n.knowledgeReviewed,
                identifier: "knowledgeReviewer"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private func sheetContent(_ article: KnowledgeArticle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(article.summary.text(language))
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("knowledgeSummary")
            ForEach(Array(article.sections.enumerated()), id: \.offset) { _, section in
                ArticleHeading(section.heading.text(language))
                ArticleParagraphs(section.paragraphs.paragraphs(language))
            }
            ArticleReferences(sources: library?.references(for: article) ?? [], identifier: "knowledgeReferences")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
