import Charts
import KickCore
import SwiftUI

/// The Cycle history page's insights (1.2 spec §2): her recent cycle lengths
/// against the 24–38-day band, how regular they are, and what she often notices.
/// Observations from her logs only; the footnote says so.
struct CycleInsightsSection: View {
    let insights: CycleInsights
    let averageLength: Int?
    let policy: CycleDisplayPolicy

    private var isBleed: Bool { policy.predictedBleedLabel == .withdrawalBleed }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !insights.lengths.isEmpty {
                chartCard
            }
            patternsCard
            Text(L10n.insightsFootnote)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cycleInsightsFootnote")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cycleInsights")
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.insightsChartTitle)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Chart {
                RectangleMark(yStart: .value("", 24), yEnd: .value("", 38))
                    .foregroundStyle(Color.luna(.cycleSoft).opacity(0.6))
                ForEach(Array(insights.lengths.enumerated()), id: \.offset) { index, bar in
                    BarMark(x: .value("", index), y: .value("", bar.shownLength), width: .ratio(0.6))
                        .foregroundStyle(Color.luna(bar.counts ? .cycleStrong : .textSecondary).opacity(bar.counts ? 1 : 0.4))
                        .cornerRadius(3)
                        .annotation(position: .top) {
                            // A long gap (a pregnancy) stops at the cap: its real length is written on it.
                            if bar.isCapped {
                                Text("\(bar.length)")
                                    .font(.luna(.small))
                                    .foregroundStyle(.luna(.textSecondary))
                            }
                        }
                        .accessibilityLabel(L10n.insightsChartBar(Formatting.spokenDay(bar.start), L10n.days(bar.length)))
                }
                if let averageLength {
                    RuleMark(y: .value("", averageLength))
                        .foregroundStyle(Color.luna(.textPrimary).opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: 0...(insights.lengths.contains(where: \.isCapped) ? CycleInsights.chartCap + 8 : 45))
            .frame(height: 140)
            Text(L10n.insightsChartNormal)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
            // Regularity means nothing for a withdrawal bleed: hormonal contraception sets it.
            if let regularity = insights.regularity, !isBleed {
                Text(L10n.insightsRegularity(regularity))
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cycleInsightsRegularity")
                if case .variable = regularity {
                    Text(L10n.cycleIrregularBody)
                        .font(.luna(.small))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cycleInsightsChart")
    }

    private var patternsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.insightsPatternsTitle)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            if insights.patterns.isEmpty {
                Text(L10n.insightsPatternsEmpty)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cycleInsightsEmpty")
            } else {
                ForEach(Array(insights.patterns.enumerated()), id: \.offset) { _, pattern in
                    Label {
                        Text(L10n.insightPattern(pattern, bleed: isBleed))
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.luna(.cycleStrong))
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cycleInsightPattern")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lunaCard()
    }
}
