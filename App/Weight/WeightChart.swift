import Charts
import KickCore
import SwiftUI

/// 170 pt gain chart (phase 5 spec §3.3): x = gestational weeks 0–40, the
/// recommended band (`pregSoft`, only with a BMI group) and the mother's gain
/// (`pregStrong` 2.5 pt line with dots). VoiceOver reads every dot.
struct WeightChart: View {
    /// Points with a gain (a pre-pregnancy weight is set), oldest first.
    let points: [WeightPoint]
    /// Empty without a BMI group.
    let band: [WeightBandPoint]

    private var yDomain: ClosedRange<Double> {
        let gains = points.compactMap(\.gainKg)
        let low = min(0, (gains.min() ?? 0) - 1)
        let high = max(band.last?.highKg ?? 0, gains.max() ?? 0) + 1
        return low...high
    }

    private var xDomain: ClosedRange<Double> {
        0...max(WeightGuidance.termWeek, points.last?.exactWeek ?? 0)
    }

    var body: some View {
        Chart {
            ForEach(band) { item in
                AreaMark(
                    x: .value(L10n.weightChartWeek, Double(item.week)),
                    yStart: .value(L10n.weightChartGain, item.lowKg),
                    yEnd: .value(L10n.weightChartGain, item.highKg)
                )
                .foregroundStyle(.luna(.pregSoft))
                .accessibilityHidden(true)
            }
            ForEach(points) { point in
                LineMark(
                    x: .value(L10n.weightChartWeek, point.exactWeek),
                    y: .value(L10n.weightChartGain, point.gainKg ?? 0)
                )
                .foregroundStyle(.luna(.pregStrong))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .accessibilityHidden(true)
                PointMark(
                    x: .value(L10n.weightChartWeek, point.exactWeek),
                    y: .value(L10n.weightChartGain, point.gainKg ?? 0)
                )
                .symbol {
                    Circle()
                        .fill(.luna(.card))
                        .overlay(Circle().strokeBorder(.luna(.pregStrong), lineWidth: 2))
                        .frame(width: 8, height: 8)
                }
                .accessibilityLabel(WeightTexts.pointLabel(point))
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: [0, 13, 27, 40]) { _ in
                AxisGridLine().foregroundStyle(.luna(.divider))
                AxisValueLabel()
                    .font(.luna(size: 10, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.luna(.divider))
                AxisValueLabel()
                    .font(.luna(size: 10, weight: .regular, relativeTo: .caption2))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .frame(height: 170)
        .accessibilityIdentifier("weightChart")
    }
}

/// "Recommended range" swatch and "You" line under the chart.
struct WeightChartLegend: View {
    let showsBand: Bool

    var body: some View {
        HStack(spacing: 16) {
            if showsBand {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(.luna(.pregSoft)).frame(width: 14, height: 10)
                    Text(L10n.weightChartRange)
                }
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(.luna(.pregStrong)).frame(width: 14, height: 3)
                Text(L10n.weightChartYou)
            }
        }
        .font(.luna(.small))
        .foregroundStyle(.luna(.textSecondary))
        .accessibilityHidden(true)
    }
}
