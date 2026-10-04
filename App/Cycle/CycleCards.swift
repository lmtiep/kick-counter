import KickCore
import SwiftUI

/// Texts shared by Today, the calendar and VoiceOver.
enum CycleTexts {
    /// "Oct 18 (in 16 days)", "Oct 18 (tomorrow)", "Days late: 4".
    static func nextPeriod(_ forecast: CycleForecast, format: (Date) -> String) -> String {
        if forecast.daysLate > 0 { return L10n.cycleNextPeriodLate(forecast.daysLate) }
        let date = format(forecast.nextPeriodStart)
        switch forecast.daysUntilNextPeriod {
        case 0: return L10n.cycleNextPeriodToday(date)
        case 1: return L10n.cycleNextPeriodTomorrow(date)
        default: return L10n.cycleNextPeriodIn(date, forecast.daysUntilNextPeriod)
        }
    }

    static func fertileRange(_ forecast: CycleForecast, format: (Date) -> String) -> String {
        L10n.cycleFertileRange(format(forecast.fertileWindow.lowerBound), format(forecast.fertileWindow.upperBound))
    }

    /// "Estimated ovulation: Oct 4" or "Ovulation confirmed by temperature: Oct 3".
    static func ovulation(_ forecast: CycleForecast, format: (Date) -> String) -> String {
        let date = format(forecast.ovulationDate)
        return forecast.ovulationConfirmed ? L10n.cycleOvulationConfirmed(date) : L10n.cycleOvulation(date)
    }

    /// What is logged for a day, e.g. "LH Positive · 36.4°C · Egg white"; nil when nothing is.
    static func logSummary(_ log: CycleLogRecord?) -> String? {
        guard let log, !log.isEmpty else { return nil }
        var parts: [String] = []
        switch log.lh {
        case .positive?: parts.append(L10n.cycleLogLH(L10n.dayLogLHPositive))
        case .negative?: parts.append(L10n.cycleLogLH(L10n.dayLogLHNegative))
        case nil: break
        }
        if let bbt = log.bbtCelsius { parts.append(Formatting.temperature(bbt)) }
        if let mucus = log.mucus { parts.append(L10n.mucus(mucus)) }
        if !log.note.isEmpty { parts.append(L10n.dayLogNote) }
        return parts.joined(separator: " · ")
    }

    /// The status of a day in words (calendar card, phase pill).
    static func status(_ status: CycleDayStatus) -> String {
        switch status {
        case .period(isPredicted: false): L10n.calendarLegendPeriod
        case .period(isPredicted: true): L10n.calendarLegendPredicted
        default: L10n.cycleStatus(status)
        }
    }
}

/// The 264 pt cycle ring (spec §4.2, README §2): coloured stretches from
/// `CycleRingGeometry`, today's marker, and the centre content on top.
/// The ring itself is decorative; the centre says the same in words.
struct CycleRingView<Center: View>: View {
    let forecast: CycleForecast
    @ViewBuilder var center: Center

    private let diameter: CGFloat = 264
    private let thickness: CGFloat = 14

    var body: some View {
        ZStack {
            ZStack {
                ForEach(Array(CycleRingGeometry.segments(for: forecast).enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(color(segment.kind), style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .padding(thickness / 2)
                }
                marker
            }
            .accessibilityHidden(true)
            center
                .frame(width: diameter - 2 * thickness - 12)
                // The ring keeps its 264 pt at every text size; past xxxLarge the
                // label and button would be cut off inside it.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .frame(width: diameter, height: diameter)
    }

    private var marker: some View {
        let angle = CycleRingGeometry.markerAngle(for: forecast)
        let offset = CycleRingGeometry.markerOffset(angle: angle, radius: Double(diameter - thickness) / 2)
        return Circle()
            .fill(.luna(.card))
            .overlay(Circle().strokeBorder(.luna(.textPrimary), lineWidth: 3))
            .frame(width: 22, height: 22)
            .offset(x: offset.x, y: offset.y)
    }

    private func color(_ kind: CycleRingKind) -> Color {
        switch kind {
        case .period: .luna(.cycle)
        case .predictedPeriod: Color.luna(.cycle).opacity(0.45)
        case .fertile: .luna(.fertile)
        case .ovulation: .luna(.teal)
        case .base: .luna(.ringTrack)
        }
    }
}

/// The 7 days under the header (spec §4.2): 6 days before today, then today,
/// coloured by status. Each day is a button that opens its log.
struct CycleWeekStrip: View {
    let forecast: CycleForecast?
    let today: Date
    let log: (Date) -> CycleLogRecord?
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WeekStrip.days(endingAt: today)) { day in
                let status = forecast?.dayStatus(for: day.date)
                Button {
                    onSelect(day.date)
                } label: {
                    VStack(spacing: 6) {
                        Text(day.isToday ? L10n.stripToday : WeekdayLabel.short(for: day.date, calendar: AppLocale.calendar))
                            .font(.luna(.tiny))
                            .tracking(0.4)
                            .foregroundStyle(.luna(.textSecondary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        DayCircle(
                            number: Formatting.dayNumber(day.date),
                            style: .strip(status),
                            isToday: day.isToday,
                            raisedToday: true
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CycleAccessibility.dayLabel(day: day.date, status: status, log: log(day.date), isToday: day.isToday))
                .accessibilityIdentifier("stripDay")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        // Seven fixed 40 pt days: larger weekday names would overlap.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// "Coming up" (spec §4.2): next period; fertile window and ovulation while not
/// late; average cycle length, typical period length, and regular / not yet.
struct ComingUpCard: View {
    let forecast: CycleForecast
    let typicalPeriodLength: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.cycleComingUp)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            row(dot: .cycle, title: L10n.cycleNextPeriodTitle, value: nextPeriodValue)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.cycleNextPeriodTitle + ": " + CycleTexts.nextPeriod(forecast, format: Formatting.spokenDay))
                .accessibilityIdentifier("cycleNextPeriodCard")
            // While late the window has passed; showing it beside "late" confuses.
            if forecast.daysLate <= 0 {
                fertileRows
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(fertileSpoken)
                    .accessibilityIdentifier("cycleFertileCard")
            }
            LunaDivider()
            HStack(alignment: .top, spacing: 8) {
                stat(L10n.days(forecast.averageCycleLength), L10n.cycleLengthTitle)
                stat(L10n.days(typicalPeriodLength), L10n.calendarLegendPeriod)
                stat(forecast.isRegular ? L10n.cycleStatsRegular : L10n.cycleStatsIrregular, L10n.cycleStatsPattern)
            }
            .accessibilityElement(children: .combine)
        }
        .lunaCard()
    }

    private var nextPeriodValue: String {
        forecast.daysLate > 0 ? L10n.cycleNextPeriodLate(forecast.daysLate) : Formatting.shortDay(forecast.nextPeriodStart)
    }

    private var fertileRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(dot: .fertile, title: L10n.cycleFertileTitle, value: CycleTexts.fertileRange(forecast, format: Formatting.shortDay))
            row(dot: .teal, title: L10n.cycleOvulationTitle, value: Formatting.shortDay(forecast.ovulationDate))
            if forecast.ovulationConfirmed {
                note(L10n.cycleOvulationConfirmedNote, color: .tealStrong)
            } else if forecast.ovulationSource == .lhTest {
                note(L10n.cycleOvulationLH, color: .textSecondary)
            }
            if forecast.confidence == .low {
                note(lowConfidence, color: .warningText, symbol: "exclamationmark.circle")
            }
        }
    }

    private var lowConfidence: String {
        forecast.usableCycleLengths.count < 2 ? L10n.cycleLowConfidenceFewCycles : L10n.cycleLowConfidenceIrregular
    }

    private var fertileSpoken: String {
        var parts = [
            L10n.cycleFertileTitle + ": " + CycleTexts.fertileRange(forecast, format: Formatting.spokenDay),
            CycleTexts.ovulation(forecast, format: Formatting.spokenDay),
        ]
        if forecast.ovulationSource == .lhTest { parts.append(L10n.cycleOvulationLH) }
        if forecast.confidence == .low { parts.append(lowConfidence) }
        return parts.joined(separator: ". ")
    }

    private func row(dot: LunaToken, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(.luna(dot)).frame(width: 10, height: 10)
            Text(title)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
                .multilineTextAlignment(.trailing)
        }
    }

    private func note(_ text: String, color: LunaToken, symbol: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.luna(.label))
        .foregroundStyle(.luna(color))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.luna(.statFigure))
                .foregroundStyle(.luna(.textPrimary))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Late, irregular and long-period notices (phase 3 rules, new style):
/// `warning` = warningBackground with a border, `soft` = cycleSoft.
struct CycleNoticeCard<Actions: View>: View {
    enum Style {
        case warning
        case soft
    }

    let title: String
    let message: String
    let style: Style
    let identifier: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(style == .warning ? .warningText : .cycleOnSoft))
                Text(message)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            actions
        }
        .lunaCard(style == .warning ? .warningBackground : .cycleSoft, border: style == .warning ? .warningBorder : nil, padding: 16)
    }
}

extension CycleNoticeCard where Actions == EmptyView {
    init(title: String, message: String, style: Style, identifier: String) {
        self.init(title: title, message: message, style: style, identifier: identifier) { EmptyView() }
    }
}
