import KickCore
import SwiftUI

/// Trying-to-conceive mode, tab 2: month grid coloured by cycle status.
/// Swipe or use the arrows to change month; tap a past day to log it.
struct CycleCalendarView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @State private var month = CycleCalendarGrid.startOfMonth(AppClock.now())
    @State private var logDay: CycleDaySelection?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthHeader
                    grid
                    CycleLegend()
                    if cycle.forecast == nil {
                        Text(L10n.calendarEmptyHint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                    showMonth(value.translation.width < 0 ? 1 : -1)
                }
            )
            .navigationTitle(L10n.calendarTitle)
            .sheet(item: $logDay) { selection in
                CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { showMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(L10n.calendarPrevious)
            .accessibilityIdentifier("calendarPrevious")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("calendarMonthTitle")
            Spacer()
            Button { showMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(L10n.calendarNext)
            .accessibilityIdentifier("calendarNext")
        }
    }

    private var grid: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: AppClock.now())
        let days = CycleCalendarGrid.days(inMonthOf: month, calendar: calendar)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(CycleCalendarGrid.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    CalendarDayCell(
                        day: day,
                        status: cycle.forecast?.dayStatus(for: day),
                        log: cycle.log(on: day),
                        isToday: day == today,
                        isFuture: day > today
                    ) {
                        logDay = CycleDaySelection(date: day)
                    }
                } else {
                    Color.clear
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func showMonth(_ offset: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            month = CycleCalendarGrid.month(offset, from: month)
        }
    }
}

struct CalendarDayCell: View {
    let day: Date
    /// nil when nothing has been logged yet (no forecast).
    let status: CycleDayStatus?
    let log: CycleLogRecord?
    let isToday: Bool
    let isFuture: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 46

    private var isRecordedPeriod: Bool { status == .period(isPredicted: false) }
    private var isPredictedPeriod: Bool { status == .period(isPredicted: true) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.day()))
                    .font(.callout.weight(isToday || isRecordedPeriod || status == .peak ? .bold : .regular))
                HStack(spacing: 2) {
                    if let symbol = status.flatMap(CyclePalette.symbol(for:)) {
                        Image(systemName: symbol)
                    }
                    if log != nil {
                        Circle().frame(width: 5, height: 5)
                    }
                }
                .font(.system(size: 8))
                .frame(height: 9)
            }
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isPredictedPeriod {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(CyclePalette.period, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
                if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary, lineWidth: 2)
                }
            }
            .opacity(isFuture && status == nil ? 0.5 : 1)
        }
        // Not .plain: a disabled plain button fades the whole cell, which made the
        // predicted peak days unreadable. Future days keep their colours.
        .buttonStyle(CalendarDayButtonStyle())
        .disabled(isFuture)
        .accessibilityLabel(CycleAccessibility.dayLabel(day: day, status: status, log: log, isToday: isToday))
        .accessibilityIdentifier("calendarDay")
    }

    private var background: Color {
        switch status {
        case .period(isPredicted: false)?: CyclePalette.period
        case .period(isPredicted: true)?: CyclePalette.period.opacity(0.12)
        case .fertile?: CyclePalette.fertile.opacity(0.3)
        case .peak?: CyclePalette.peak
        case .low?, nil: Color.clear
        }
    }

    /// Light text on the solid period and peak fills, normal text elsewhere.
    private var foreground: Color {
        switch status {
        case .period(isPredicted: false)?, .peak?: Color(.systemBackground)
        default: Color.primary
        }
    }
}

/// Pressed feedback only; ignores the disabled state so future days stay legible.
private struct CalendarDayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct CycleLegend: View {
    private struct Item: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let fill: Color
        var dashed = false
    }

    private var items: [Item] {
        [
            Item(id: "period", title: L10n.calendarLegendPeriod, symbol: "drop.fill", fill: CyclePalette.period),
            Item(id: "predicted", title: L10n.calendarLegendPredicted, symbol: "drop", fill: CyclePalette.period.opacity(0.12), dashed: true),
            Item(id: "fertile", title: L10n.calendarLegendFertile, symbol: "leaf.fill", fill: CyclePalette.fertile.opacity(0.3)),
            Item(id: "peak", title: L10n.calendarLegendPeak, symbol: "sparkles", fill: CyclePalette.peak),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item.fill)
                        .overlay {
                            if item.dashed {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(CyclePalette.period, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                            }
                        }
                        .overlay {
                            Image(systemName: item.symbol)
                                .font(.caption2)
                                .foregroundStyle(item.id == "period" || item.id == "peak" ? Color(.systemBackground) : Color.primary)
                        }
                        .frame(width: 28, height: 22)
                    Text(item.title).font(.subheadline)
                }
            }
            HStack(spacing: 10) {
                Circle().frame(width: 6, height: 6)
                    .frame(width: 28, height: 22)
                Text(L10n.calendarLegendLogged).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("calendarLegend")
    }
}

/// What VoiceOver reads for a calendar day, e.g.
/// "October 12, fertile window, positive LH test logged".
enum CycleAccessibility {
    static func dayLabel(day: Date, status: CycleDayStatus?, log: CycleLogRecord?, isToday: Bool) -> String {
        var parts = [Formatting.spokenDay(day)]
        if isToday { parts.append(L10n.calendarA11yToday) }
        switch status {
        case .period(isPredicted: false)?: parts.append(L10n.calendarA11yPeriod)
        case .period(isPredicted: true)?: parts.append(L10n.calendarA11yPredicted)
        case .fertile?: parts.append(L10n.calendarA11yFertile)
        case .peak?: parts.append(L10n.calendarA11yPeak)
        case .low?, nil: break
        }
        if let log {
            switch log.lh {
            case .positive?: parts.append(L10n.calendarA11yLHPositive)
            case .negative?: parts.append(L10n.calendarA11yLHNegative)
            case nil: break
            }
            if let bbt = log.bbtCelsius { parts.append(L10n.calendarA11yTemperature(Formatting.temperature(bbt))) }
            if let mucus = log.mucus { parts.append(L10n.mucus(mucus)) }
            if !log.note.isEmpty { parts.append(L10n.calendarA11yNote) }
        }
        return parts.joined(separator: ", ")
    }
}
