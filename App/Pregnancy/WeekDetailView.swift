import KickCore
import SwiftUI

/// The week opened from Today (fetus, "This week", baby and tips cards).
struct WeekSelection: Identifiable, Equatable {
    let week: Int
    var id: Int { week }
}

/// Full-screen week detail, weeks 4…42 (spec §4.5): close button, fetus, a row
/// of week chips scrolled to the current week, and the week's panel. Swipe left
/// or right on the panel to change week.
struct WeekDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.contentLibrary) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: Int
    private let language = ContentLanguage.current

    init(currentWeek: Int) {
        _selection = State(initialValue: WeeklyContentLibrary.clampedWeek(currentWeek))
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    Image("Fetus")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 170)
                        .frame(width: 220, height: 220)
                        .background(
                            RadialGradient(
                                colors: [Color.luna(.card).opacity(0.7), Color.luna(.card).opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                            .clipShape(Circle())
                        )
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .accessibilityHidden(true)
                    ChipScroller(
                        values: Array(WeeklyContentLibrary.weekRange),
                        selection: $selection,
                        title: { L10n.weekChip($0) },
                        identifier: { "weekChip-\($0)" }
                    )
                    .padding(.bottom, 16)
                    panel(minHeight: proxy.size.height * 0.6)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 30).onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                                changeWeek(by: value.translation.width < 0 ? 1 : -1)
                            }
                        )
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background {
                // linear-gradient(heroTop 0 %, heroMiddle 38 %, background 60 %), then the panel colour.
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .luna(.heroTop), location: 0),
                            .init(color: .luna(.heroMiddle), location: 0.38 / 0.6),
                            .init(color: .luna(.background), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: (proxy.size.height + proxy.safeAreaInsets.top) * 0.6)
                    Color.luna(.card)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.luna(.textPrimary))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.luna(.card).opacity(0.55)))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.commonClose)
            .accessibilityIdentifier("weekDetailClose")
            Spacer()
            Text(L10n.weekTitle(selection))
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("weekDetailTitle")
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func panel(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.luna(.chevron))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 18)
                .accessibilityHidden(true)
            Text(L10n.weekHeadline(selection))
                .font(.luna(.weekTitle))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("weekHeadline")
            switch library?.display(forWeek: selection, visibility: BuildFlags.contentVisibility) {
            case .content(let content, let pendingReview)?:
                reviewer(pendingReview: pendingReview)
                tiles(content)
                Text(L10n.weekSizeLine(content.size.name(language)))
                    .font(.luna(size: 17, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
                figures(content)
                WeekSection(title: L10n.weekBaby, items: content.baby.items(language))
                WeekSection(title: L10n.weekMom, items: content.mom.items(language))
                WeekSection(title: L10n.weekTips, items: content.tips.items(language))
                WarningSection(items: content.warnings.items(language))
                sources
            case .underReview?:
                UnderReviewCard()
                    .padding(.top, 18)
            case nil:
                EmptyView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(.luna(.card), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
    }

    private func reviewer(pendingReview: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .font(.system(size: 15, weight: .medium))
                // articleText, not textSecondary: drawn on `surface` (AA rule).
                .foregroundStyle(.luna(.articleText))
                .frame(width: 38, height: 38)
                .background(Circle().fill(.luna(.surface)))
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.weekReviewer)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
                // No doctor's name yet (spec §4.5).
                Text(pendingReview ? L10n.weekPendingReview : L10n.weekReviewed)
                    .font(.luna(.label))
                    .foregroundStyle(.luna(.textPrimary))
            }
        }
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekReviewer")
    }

    private func tiles(_ content: WeekContent) -> some View {
        HStack(spacing: 12) {
            Color.luna(.pregSoft)
                .aspectRatio(1, contentMode: .fit)
                .overlay(Image("Fetus").resizable().scaledToFit().padding(16))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            Color.luna(.fertileSoft)
                .aspectRatio(1, contentMode: .fit)
                .overlay(Text(content.size.emoji).font(.system(size: 64)))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.top, 20)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func figures(_ content: WeekContent) -> some View {
        if content.weightG != nil || content.crlMm != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    if let crl = content.crlMm {
                        figure(title: L10n.pregnancyBabyCRL, value: Formatting.crownRumpLength(mm: crl), detail: nil)
                    }
                    if let grams = content.weightG {
                        figure(title: L10n.pregnancyBabyWeight, value: Formatting.weight(grams: grams), detail: weightRange(content))
                    }
                }
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
                }
            }
            .padding(.top, 14)
        }
    }

    /// "Typically 275–387 g" (Hadlock 10th–90th percentile).
    private func weightRange(_ content: WeekContent) -> String? {
        guard let grams = content.weightG, let low = content.weightP10G, let high = content.weightP90G else { return nil }
        return L10n.weekTypicalRange(Formatting.weightRange(low, high, unitOf: grams))
    }

    private func figure(title: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Secondary text on `surface` uses articleText (textSecondary fails AA there).
            Text(title)
                .font(.luna(.small))
                .foregroundStyle(.luna(.articleText))
            Text(value)
                .font(.luna(.figure))
                .foregroundStyle(.luna(.textPrimary))
            if let detail {
                Text(detail)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.luna(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var sources: some View {
        if let sources = library?.sources, !sources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.medicalSourcesTitle)
                    .font(.luna(.captionStrong))
                    .foregroundStyle(.luna(.textPrimary))
                ForEach(sources, id: \.self) { source in
                    Text(verbatim: source)
                        .font(.luna(.small))
                        .foregroundStyle(.luna(.textSecondary))
                }
            }
            .padding(.top, 22)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weekSources")
        }
    }

    private func changeWeek(by offset: Int) {
        let week = selection + offset
        guard WeeklyContentLibrary.weekRange.contains(week) else { return }
        withAnimation(reduceMotion || !LunaMotion.isEnabled ? nil : .easeOut(duration: 0.2)) { selection = week }
    }
}

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

/// "When to get care right away" in the warning colours.
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
