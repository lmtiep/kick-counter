import Charts
import KickCore
import SwiftUI

/// 170 pt bar chart (spec §4.7): the current day or week in `pregStrong`, the
/// others in `pregBar`, no session in `track`; dashed 30′ line; the axis stops at
/// 60′ and longer bars are cut there with their real value written above.
struct HistoryChart: View {
    struct Item: Identifiable {
        let id: Int
        let label: String
        let minutes: Double?
        let isCurrent: Bool
    }

    let items: [Item]

    var body: some View {
        Chart {
            ForEach(items) { item in
                BarMark(
                    x: .value(L10n.historyChartPeriod, item.label),
                    y: .value(L10n.historyChartMinutes, item.minutes.map { min($0, HistoryStats.chartMaxMinutes) } ?? 2),
                    width: .ratio(0.6)
                )
                .foregroundStyle(color(item))
                .cornerRadius(7)
                .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit, y: .disabled)) {
                    Text(item.minutes.map { L10n.historyBarMinutes(Int($0.rounded())) } ?? "–")
                        .font(.luna(size: 11, weight: .semibold, relativeTo: .caption2))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .accessibilityLabel(item.label)
                .accessibilityValue(item.minutes.map(Formatting.minutes) ?? L10n.historyNoSession)
            }
            RuleMark(y: .value(L10n.historyChartMinutes, HistoryStats.referenceMinutes))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(.luna(.pregBar))
                .annotation(position: .top, alignment: .trailing) {
                    Text(L10n.historyBarMinutes(Int(HistoryStats.referenceMinutes)))
                        .font(.luna(size: 10, weight: .regular, relativeTo: .caption2))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .accessibilityHidden(true)
        }
        // Bars stop at 60′; the extra 8′ above leaves room for a cut bar's real
        // value inside the plot (plot padding pushed the bars over the x labels).
        .chartYScale(domain: 0...(HistoryStats.chartMaxMinutes + 8))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.luna(.tiny))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .frame(height: 170)
        .padding(.top, 14)
        .accessibilityIdentifier("historyChart")
    }

    private func color(_ item: Item) -> Color {
        guard item.minutes != nil else { return .luna(.track) }
        return item.isCurrent ? .luna(.pregStrong) : .luna(.pregBar)
    }
}
