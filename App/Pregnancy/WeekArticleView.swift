import KickCore
import SwiftUI

extension WeekSizeLine.Templates {
    /// The `weekArticle.size.*` strings in the app's language.
    static var localized: Self {
        Self(
            length: L10n.weekArticleSizeLengthFormat,
            lengthAndWeight: L10n.weekArticleSizeLengthWeightFormat,
            weightAndRange: L10n.weekArticleSizeWeightFormat
        )
    }
}

extension WeekSizeLine.Numbers {
    /// `Formatting`'s numbers; `spoken` spells the units out for VoiceOver.
    static func formatted(spoken: Bool) -> Self {
        Self(
            length: { Formatting.crownRumpLength(mm: $0, spoken: spoken) },
            weight: { Formatting.weight(grams: $0, spoken: spoken) },
            rangeLow: { Formatting.weightRangeStart($0, unitOf: $1) },
            rangeHigh: { Formatting.weightInUnit($0, unitOf: $1, spoken: spoken) }
        )
    }
}

/// The selected tab of the week article sheet (phase 6 spec §4.3). Bé: lead,
/// artwork, "Bé lớn cỡ nào?", "Bé phát triển ra sao", references. Mẹ: "Cơ thể
/// mẹ tuần này", "Mẹ nên làm gì", the warnings (anchor `weekWarnings`),
/// references. A week without an article shows the bullet lists instead.
struct WeekArticleView: View {
    static let warningsAnchor = "weekWarnings"

    let content: WeekContent
    let tab: ArticleTab
    /// `PregnancyContent.sources`.
    let sources: [String]
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch tab {
            case .baby: babyTab
            case .mom: momTab
            }
            ArticleReferences(sources: referenceList, identifier: "weekReferences")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bé

    @ViewBuilder
    private var babyTab: some View {
        if let article = content.article {
            Text(article.lead.text(language))
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("weekArticleLead")
        }
        artworkRow
        ArticleHeading(L10n.weekArticleSizeHeading)
        sizeLine
        if let article = content.article {
            ArticleParagraphs(article.sizeNote.paragraphs(language))
        }
        footnote
        if let article = content.article {
            ArticleHeading(L10n.weekArticleDevelopmentHeading)
            ArticleParagraphs(article.development.paragraphs(language))
        } else {
            WeekSection(title: L10n.weekBaby, items: content.baby.items(language))
        }
    }

    /// Fetus and fruit side by side; decorative.
    private var artworkRow: some View {
        HStack(spacing: 12) {
            Color.luna(.pregSoft)
                .aspectRatio(1, contentMode: .fit)
                .overlay(WeekArtwork.fetus(content.week).resizable().scaledToFit().padding(16))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Color.luna(.fertileSoft)
                .aspectRatio(1, contentMode: .fit)
                .overlay { fruit }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.top, content.article == nil ? 4 : 18)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fruit: some View {
        if let image = WeekArtwork.fruit(content.week) {
            image.resizable().scaledToFit().padding(16)
        } else {
            Text(content.size.emoji)
                .font(.system(size: 64))
                .frame(width: 120, height: 120)
                .background(Circle().fill(Color.luna(.card).opacity(0.6)))
        }
    }

    /// The generated sentence (spec §4.2); VoiceOver reads the spoken units.
    @ViewBuilder
    private var sizeLine: some View {
        if let line = WeekSizeLine.make(for: content, language: language, templates: .localized, numbers: .formatted(spoken: false)) {
            let spoken = WeekSizeLine.make(for: content, language: language, templates: .localized, numbers: .formatted(spoken: true))
            Text(line)
                .font(.luna(.articleBody))
                .lineSpacing(4)
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .accessibilityLabel(spoken ?? line)
                .accessibilityIdentifier("weekSizeLine")
        }
    }

    /// "Hadlock's standard ends at week 40." (weeks 41–42) and the estimate note.
    @ViewBuilder
    private var footnote: some View {
        if content.weightG != nil {
            VStack(alignment: .leading, spacing: 2) {
                if content.weightBeyondStandard {
                    Text(L10n.pregnancyBabyStandardEnds(WeekContent.weightStandardLastWeek))
                }
                Text(L10n.pregnancyBabyEstimateNote)
            }
            .font(.luna(.small))
            .foregroundStyle(.luna(.textSecondary))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
        }
    }

    // MARK: Mẹ

    @ViewBuilder
    private var momTab: some View {
        if let article = content.article {
            ArticleHeading(L10n.weekArticleBodyHeading)
            ArticleParagraphs(article.body.paragraphs(language))
            ArticleHeading(L10n.weekArticleTodoHeading)
            ArticleParagraphs(article.todo.paragraphs(language))
        } else {
            WeekSection(title: L10n.weekMom, items: content.mom.items(language))
            WeekSection(title: L10n.weekTips, items: content.tips.items(language))
        }
        WarningSection(items: content.warnings.items(language))
            .id(Self.warningsAnchor)
    }

    // MARK: References

    /// The article's sources, or every source for a week without an article.
    private var referenceList: [String] {
        guard let article = content.article else { return sources }
        return article.sources.compactMap { sources.indices.contains($0) ? sources[$0] : nil }
    }
}

/// The bullet fallback for a week without an article.
private struct WeekSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
                .font(.luna(.articleBody))
                .lineSpacing(5)
                .foregroundStyle(.luna(.articleText))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 22)
        .accessibilityElement(children: .combine)
    }
}

/// "When to get care right away" in the warning colours (unchanged from phase 5).
private struct WarningSection: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.weekWarnings, systemImage: "exclamationmark.triangle.fill")
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.warningText))
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "•").accessibilityHidden(true)
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
                .font(.luna(.body))
                .foregroundStyle(.luna(.articleText))
            }
        }
        .lunaCard(.warningBackground, border: .warningBorder, padding: 16)
        .padding(.top, 22)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekWarnings")
    }
}
