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

    /// What is logged for a day in the order of phase 5 spec §3.1, e.g.
    /// "Flow: Light · Calm · Cramps · 36.4 °C · LH Positive · Egg white"; only
    /// `mode`'s symptoms. nil when nothing readable is logged.
    static func logSummary(_ log: CycleLogRecord?, mode: AppMode = .tryingToConceive) -> String? {
        logSummary(log, mode: mode, includingNote: true)
    }

    /// Same as `logSummary(_:mode:)`, but `includingNote: false` drops the
    /// trailing "Note" item — for a detail row that already shows the note's
    /// own text on a second line, so it is not shown (or spoken) twice.
    static func logSummary(_ log: CycleLogRecord?, mode: AppMode = .tryingToConceive, includingNote: Bool) -> String? {
        guard let log else { return nil }
        let items = includingNote ? log.summaryItems(mode: mode) : log.summaryItems(mode: mode).filter { $0 != .note }
        let parts = items.map(summaryText)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func summaryText(_ item: CycleLogSummaryItem) -> String {
        switch item {
        case .flow(let flow): L10n.symptomSummaryFlow(L10n.flow(flow))
        case .mood(let mood): L10n.mood(mood)
        case .symptom(let symptom): L10n.symptom(symptom)
        case .temperature(let celsius): Formatting.temperature(celsius)
        case .lh(.positive): L10n.cycleLogLH(L10n.dayLogLHPositive)
        case .lh(.negative): L10n.cycleLogLH(L10n.dayLogLHNegative)
        case .mucus(let mucus): L10n.mucus(mucus)
        case .note: L10n.dayLogNote
        }
    }

    /// The status of a day in words (calendar card, phase pill), as `policy`
    /// shows it. nil for an ordinary day while tracking: tracking never says
    /// "Low chance of conceiving" (phase 9 spec §3.1).
    static func status(_ status: CycleDayStatus, policy: CycleDisplayPolicy = .conceiving) -> String? {
        let visible = policy.visibleStatus(status)
        switch visible {
        case .period(isPredicted: false): return L10n.calendarLegendPeriod
        case .period(isPredicted: true): return predictedBleed(policy)
        case .fertile, .peak:
            return policy.fertileLabel == .highPregnancyChance ? L10n.cycleHighPregnancyChance : L10n.cycleStatus(visible)
        case .low:
            return policy.headline == .nextPeriod ? nil : L10n.cycleStatus(visible)
        }
    }

    /// What VoiceOver says about today in the ring: the trying-to-conceive
    /// wording, or `status(_:policy:)`'s while tracking — "menstruating" only
    /// on a logged period day, never on a predicted (or expected) bleed.
    static func spokenStatus(_ status: CycleDayStatus, policy: CycleDisplayPolicy) -> String? {
        if policy.headline == .fertility { return L10n.cycleStatus(status) }
        if case .period(isPredicted: false) = status { return L10n.cycleStatus(status) }
        return Self.status(status, policy: policy)
    }

    /// "Day 13 · High chance of pregnancy", or "Day 13 of your cycle" when the
    /// day has no status to show.
    static func phase(day: Int, status: CycleDayStatus, policy: CycleDisplayPolicy) -> String {
        Self.status(status, policy: policy).map { L10n.cyclePhase(day, $0) } ?? L10n.cycleDay(day)
    }

    /// "Next period", or "Expected bleed" on hormonal contraception.
    static func nextBleedTitle(_ policy: CycleDisplayPolicy) -> String {
        policy.predictedBleedLabel == .withdrawalBleed ? L10n.cycleWithdrawalBleed : L10n.cycleNextPeriodTitle
    }

    /// "Predicted period", or "Expected bleed" on hormonal contraception.
    static func predictedBleed(_ policy: CycleDisplayPolicy) -> String {
        policy.predictedBleedLabel == .withdrawalBleed ? L10n.cycleWithdrawalBleed : L10n.calendarLegendPredicted
    }

    /// "Fertile window" while trying to conceive, "High chance of pregnancy" while tracking.
    static func fertileTitle(_ policy: CycleDisplayPolicy) -> String {
        policy.fertileLabel == .highPregnancyChance ? L10n.cycleHighPregnancyChance : L10n.cycleFertileTitle
    }
}

/// The 264 pt cycle ring (spec §4.2, README §2): coloured stretches from
/// `CycleRingGeometry`, today's marker, and the centre content on top.
/// The ring itself is decorative; the centre says the same in words.
///
/// Fertile (`fertile`) and ovulation (`teal`) are only 2.3:1 apart in light mode
/// and 1.2:1 in dark, so colour is not the only cue: segments are separated by
/// 2 pt gaps and the ovulation days are drawn thicker (20 pt vs 14 pt), matching
/// the ringed ovulation dot in "Coming up".
struct CycleRingView<Center: View>: View {
    let forecast: CycleForecast
    var policy: CycleDisplayPolicy = .conceiving
    @ViewBuilder var center: Center

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let diameter: CGFloat = 264
    private let thickness: CGFloat = 14
    private let ovulationThickness: CGFloat = 20
    private let gap: CGFloat = 2

    var body: some View {
        ZStack {
            ZStack {
                let segments = CycleRingGeometry.segments(for: forecast, policy: policy)
                // Half the gap, as a fraction of the ring's centre line.
                let inset = segments.count > 1 ? Double(gap / (.pi * (diameter - thickness))) / 2 : 0
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start + inset, to: segment.end - inset)
                        .stroke(
                            color(segment.kind),
                            style: StrokeStyle(lineWidth: segment.kind == .ovulation ? ovulationThickness : thickness, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(thickness / 2)
                }
                marker
            }
            .accessibilityHidden(true)
            center
                // At accessibility sizes a narrower column keeps the label and
                // the button clear of the arc.
                .frame(width: dynamicTypeSize.isAccessibilitySize ? diameter * 0.7 : diameter - 2 * thickness - 12)
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
    var policy: CycleDisplayPolicy = .conceiving
    let today: Date
    let log: (Date) -> CycleLogRecord?
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WeekStrip.days(endingAt: today, calendar: AppLocale.calendar)) { day in
                let status = forecast.map { policy.visibleStatus($0.dayStatus(for: day.date)) }
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
                .accessibilityLabel(CycleAccessibility.dayLabel(
                    day: day.date, status: status, log: log(day.date), isToday: day.isToday, policy: policy
                ))
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
/// Phase 9: `policy` names the window, adds the "not contraception" note while
/// tracking, and hides the window on hormonal contraception (with its note).
/// Phase 10: a link to the cycle history.
struct ComingUpCard: View {
    let forecast: CycleForecast
    let typicalPeriodLength: Int
    var policy: CycleDisplayPolicy = .conceiving

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.cycleComingUp)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            row(dot: .cycle, title: CycleTexts.nextBleedTitle(policy), value: nextPeriodValue)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(CycleTexts.nextBleedTitle(policy) + ": " + CycleTexts.nextPeriod(forecast, format: Formatting.spokenDay))
                .accessibilityIdentifier("cycleNextPeriodCard")
            // While late the window has passed; showing it beside "late" confuses.
            if forecast.daysLate <= 0, policy.showsFertileWindow {
                fertileRows
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(fertileSpoken)
                    .accessibilityIdentifier("cycleFertileCard")
            }
            if forecast.daysLate <= 0, forecast.confidence == .low {
                note(lowConfidence, color: .warningText, symbol: "exclamationmark.circle")
            }
            // Beside the fertile rows only: while late `cycleDisclaimer` covers it.
            if forecast.daysLate <= 0, policy.showsNotContraceptionNote {
                goalNote(L10n.cycleNotContraception, identifier: "cycleNotContraceptionNote")
            }
            if !policy.showsFertileWindow {
                goalNote(L10n.cycleHormonalNote, identifier: "cycleHormonalNote")
            }
            LunaDivider()
            HStack(alignment: .top, spacing: 8) {
                stat(L10n.days(forecast.averageCycleLength), L10n.cycleLengthTitle)
                stat(L10n.days(typicalPeriodLength), L10n.calendarLegendPeriod)
                stat(forecast.isRegular ? L10n.cycleStatsRegular : L10n.cycleStatsIrregular, L10n.cycleStatsPattern)
            }
            .accessibilityElement(children: .combine)
            LunaDivider()
            NavigationLink(value: CycleHistoryRoute.list) {
                HStack {
                    Text(L10n.cycleHistoryLink)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.cycleOnSoft))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.luna(.cycleOnSoft))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cycleHistoryLink")
        }
        .lunaCard()
    }

    private var nextPeriodValue: String {
        forecast.daysLate > 0 ? L10n.cycleNextPeriodLate(forecast.daysLate) : Formatting.shortDay(forecast.nextPeriodStart)
    }

    /// A quiet, multi-sentence aside under the rows: the icon sits on the first
    /// line's baseline, and the text gets a little extra leading so the
    /// paragraph stays readable in Vietnamese and at the largest sizes.
    private func goalNote(_ text: String, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .accessibilityHidden(true)
            Text(text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        }
        .font(.luna(.label))
        .foregroundStyle(.luna(.textSecondary))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private var fertileRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(dot: .fertile, title: CycleTexts.fertileTitle(policy), value: CycleTexts.fertileRange(forecast, format: Formatting.shortDay))
            row(dot: .teal, ringed: true, title: L10n.cycleOvulationTitle, value: Formatting.shortDay(forecast.ovulationDate))
            if forecast.ovulationConfirmed {
                note(L10n.cycleOvulationConfirmedNote, color: .tealStrong)
            } else if forecast.ovulationSource == .lhTest {
                note(L10n.cycleOvulationLH, color: .textSecondary)
            }
        }
    }

    private var lowConfidence: String {
        forecast.usableCycleLengths.count < 2 ? L10n.cycleLowConfidenceFewCycles : L10n.cycleLowConfidenceIrregular
    }

    private var fertileSpoken: String {
        var parts = [
            CycleTexts.fertileTitle(policy) + ": " + CycleTexts.fertileRange(forecast, format: Formatting.spokenDay),
            CycleTexts.ovulation(forecast, format: Formatting.spokenDay),
        ]
        if forecast.ovulationSource == .lhTest { parts.append(L10n.cycleOvulationLH) }
        return parts.joined(separator: ". ")
    }

    private func row(dot: LunaToken, ringed: Bool = false, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            // Ovulation: a dot with a ring around it, like its thicker stretch on
            // the cycle ring (its colour alone is too close to the fertile one).
            Circle().fill(.luna(dot)).frame(width: 10, height: 10)
                .padding(ringed ? 3 : 0)
                .overlay {
                    if ringed { Circle().strokeBorder(.luna(dot), lineWidth: 1.5) }
                }
                .frame(width: 16, height: 16)
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
            if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
            Text(text)
        }
        .font(.luna(.label))
        .foregroundStyle(.luna(color))
        // One VoiceOver stop, like `goalNote` (the low-confidence warning stands alone).
        .accessibilityElement(children: .combine)
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
