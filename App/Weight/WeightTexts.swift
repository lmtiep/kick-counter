import KickCore
import SwiftUI

/// Words and the status pill shared by the Weight screen and Today's card.
enum WeightTexts {
    /// "58.0 kg · +6.0 kg", or "58.0 kg" without a pre-pregnancy weight.
    static func line(_ point: WeightPoint) -> String {
        guard let gain = point.gainKg else { return Formatting.kilograms(point.kg) }
        return "\(Formatting.kilograms(point.kg)) · \(Formatting.kilograms(gain, signed: true))"
    }

    /// VoiceOver for a chart dot: "Week 24: gained 6.0 kilograms, In range".
    static func pointLabel(_ point: WeightPoint) -> String {
        let gain = point.gainKg ?? 0
        let change = gain < 0
            ? L10n.weightChartLossPoint(point.week.weeks, Formatting.kilograms(-gain, spoken: true))
            : L10n.weightChartGainPoint(point.week.weeks, Formatting.kilograms(gain, spoken: true))
        guard let status = point.status else { return change }
        return "\(change), \(L10n.weightStatus(status))"
    }
}

/// "In range" (`fertileSoft` / `tealStrong`), "Below range" / "Above range"
/// (`pregSoft` / `pregOnSoft`, never red: spec §3.4).
struct WeightStatusPill: View {
    let status: WeightStatus

    var body: some View {
        let inRange = status == .inRange
        Text(L10n.weightStatus(status))
            .font(.luna(.label))
            .foregroundStyle(.luna(inRange ? .tealStrong : .pregOnSoft))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.luna(inRange ? .fertileSoft : .pregSoft)))
            .accessibilityIdentifier("weightStatusPill")
    }
}
