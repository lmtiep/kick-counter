import KickCore
import SwiftUI

/// How a day number is drawn (README §2–3). Colours meet AA (KickCore
/// `ContrastTests`): filled period days use `cycleStrong`, period text on the
/// pink tint uses `cycleOnSoft`, fertile text uses `tealStrong`.
struct DayCircleStyle: Equatable {
    var fill: LunaToken?
    var foreground: LunaToken = .textPrimary
    var border: LunaToken?
    var dashed = false
    var bold = false

    static let plain = DayCircleStyle()

    // Calendar (spec §4.3)
    static let period = DayCircleStyle(fill: .cycleStrong, foreground: .onAccent)
    static let predictedPeriod = DayCircleStyle(foreground: .cycleStrong, border: .cycle, dashed: true)
    static let fertile = DayCircleStyle(fill: .fertileSoft, foreground: .tealStrong)
    static let ovulation = DayCircleStyle(fill: .ovulation, foreground: .tealStrong, border: .teal, bold: true)

    // 7-day strip on Today (spec §4.2, §4.4)
    static let stripPeriod = DayCircleStyle(fill: .cycleSoft, foreground: .cycleOnSoft)
    static let stripFertile = DayCircleStyle(foreground: .tealStrong)
    static let stripOvulation = DayCircleStyle(fill: .ovulation, foreground: .tealStrong)
    static let pregnancyStrip = DayCircleStyle(foreground: .pregOnSoft)

    static func calendar(_ status: CycleDayStatus?) -> DayCircleStyle {
        switch status {
        case .period(isPredicted: false)?: .period
        case .period(isPredicted: true)?: .predictedPeriod
        case .fertile?: .fertile
        case .peak?: .ovulation
        case .low?, nil: .plain
        }
    }

    static func strip(_ status: CycleDayStatus?) -> DayCircleStyle {
        switch status {
        case .period?: .stripPeriod
        case .fertile?: .stripFertile
        case .peak?: .stripOvulation
        case .low?, nil: .plain
        }
    }
}

/// A 40 pt day circle. `raisedToday` draws today as a white disc with a soft
/// shadow (strip); otherwise today gets a 2 pt `todayRing` (calendar).
/// The selected day gets a 2 pt `textPrimary` ring (outside the today ring when both).
struct DayCircle: View {
    let number: String
    var style: DayCircleStyle = .plain
    var isToday = false
    var raisedToday = false
    var isSelected = false
    var fontSize: CGFloat = 16
    var diameter: CGFloat = 40

    var body: some View {
        Text(number)
            .font(.luna(size: fontSize, weight: style.bold || isToday ? .bold : .medium, relativeTo: .body))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.luna(style.foreground))
            .frame(width: diameter, height: diameter)
            .background {
                if raisedToday && isToday {
                    Circle()
                        .fill(.luna(.card))
                        .shadow(color: Color.luna(.pregOnSoft).opacity(0.18), radius: 7, y: 4)
                } else if let fill = style.fill {
                    Circle().fill(.luna(fill))
                }
            }
            .overlay {
                if let border = style.border, !(raisedToday && isToday) {
                    Circle().strokeBorder(.luna(border), style: StrokeStyle(lineWidth: 1.5, dash: style.dashed ? [3, 2.5] : []))
                }
            }
            .overlay {
                // Today selected shows both rings: todayRing, then the selected ring outside it.
                let todayRing = isToday && !raisedToday
                if todayRing {
                    Circle().strokeBorder(.luna(.todayRing), lineWidth: 2).padding(-2)
                }
                if isSelected {
                    Circle().strokeBorder(.luna(.textPrimary), lineWidth: 2).padding(todayRing ? -4 : -2)
                }
            }
    }
}

#Preview {
    HStack(spacing: 6) {
        DayCircle(number: "1", style: .period)
        DayCircle(number: "2", style: .predictedPeriod)
        DayCircle(number: "3", style: .fertile, isToday: true)
        DayCircle(number: "4", style: .ovulation, isSelected: true)
        DayCircle(number: "5", style: .stripPeriod)
        DayCircle(number: "6", style: .stripFertile, isToday: true, raisedToday: true)
    }
    .padding()
    .background(.luna(.background))
}
