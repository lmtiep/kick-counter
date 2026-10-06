import KickCore
import SwiftUI

/// Top of the Weight screen (phase 5 spec §3.3): gain since pre-pregnancy
/// (32/700 `pregStrong`), the latest weight and week, "BMI 21.3 · Normal",
/// the latest status, and the chart.
struct WeightSummaryCard: View {
    let points: [WeightPoint]
    let profile: MaternalProfile

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Side by side, or stacked at accessibility sizes so words are not split.
    private func row(bottom: Bool) -> AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: bottom ? .bottom : .center, spacing: bottom ? 12 : 10))
    }

    var body: some View {
        let latest = points.last
        let band = profile.category.map(WeightStats.band(category:)) ?? []
        let stacked = dynamicTypeSize.isAccessibilitySize
        let gainRow = row(bottom: true)
        let bmiRow = row(bottom: false)
        VStack(alignment: .leading, spacing: 14) {
            gainRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.weightGained)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                    Text(latest?.gainKg.map { Formatting.kilograms($0, signed: true) } ?? "–")
                        .font(.luna(.display))
                        .foregroundStyle(.luna(.pregStrong))
                    Text(L10n.weightSince)
                        .font(.luna(.small))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let latest {
                    VStack(alignment: stacked ? .leading : .trailing, spacing: 2) {
                        Text(Formatting.kilograms(latest.kg))
                            .font(.luna(size: 24, weight: .bold, relativeTo: .title2))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.weekTitle(latest.week.weeks))
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weightSummary")

            if let bmi = profile.bmi, let category = profile.category {
                bmiRow {
                    Text(L10n.weightBMI(Formatting.decimal(bmi), L10n.weightCategory(category)))
                        .font(.luna(.bodyMedium))
                        .foregroundStyle(.luna(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("weightBMI")
                    if let status = latest?.status {
                        WeightStatusPill(status: status)
                    }
                }
            } else {
                Text(L10n.weightNoHeight)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightNoHeightHint")
            }

            if !points.isEmpty {
                WeightChart(points: points, band: band)
                WeightChartLegend(showsBand: !band.isEmpty)
            }
        }
        .lunaCard()
    }
}
