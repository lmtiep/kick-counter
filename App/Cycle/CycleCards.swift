import KickCore
import SwiftUI

/// Ring of the current cycle's days coloured by status, with today marked.
/// Decorative: `CycleStatusCard` says the same in words.
struct CycleRing: View {
    let forecast: CycleForecast
    var lineWidth: CGFloat = 14

    private var length: Int { max(forecast.averageCycleLength, forecast.cycleDay) }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(0..<length, id: \.self) { index in
                    Circle()
                        .trim(from: start(of: index), to: end(of: index))
                        .stroke(color(of: index), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .padding(lineWidth / 2)
                }
                Circle()
                    .fill(Color.primary)
                    .frame(width: lineWidth * 0.7, height: lineWidth * 0.7)
                    .offset(y: -(size - lineWidth) / 2)
                    .rotationEffect(.degrees(360 * (Double(forecast.cycleDay) - 0.5) / Double(length)))
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func start(of index: Int) -> CGFloat { (CGFloat(index) + 0.08) / CGFloat(length) }
    private func end(of index: Int) -> CGFloat { (CGFloat(index) + 0.92) / CGFloat(length) }

    private func color(of index: Int) -> Color {
        let day = Calendar.current.date(byAdding: .day, value: index, to: forecast.currentPeriodStart) ?? forecast.currentPeriodStart
        return CyclePalette.ringColor(for: forecast.dayStatus(for: day))
    }
}

/// "Day 12 of your cycle · High chance of conceiving" around the ring.
struct CycleStatusCard: View {
    let forecast: CycleForecast
    @ScaledMetric(relativeTo: .title) private var ringSize: CGFloat = 190

    private var todayStatus: CycleDayStatus { forecast.dayStatus(for: forecast.today) }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                CycleRing(forecast: forecast)
                VStack(spacing: 2) {
                    Text(forecast.cycleDay, format: .number)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .accessibilityHidden(true)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text(L10n.cycleDay(forecast.cycleDay))
                    .font(.title3.bold())
                // While late a "low chance" status would mislead (she may be pregnant).
                if forecast.daysLate > 0 {
                    Label(L10n.cycleStatusLate, systemImage: "calendar.badge.exclamationmark")
                        .foregroundStyle(.primary)
                        .font(.headline)
                } else {
                    Label {
                        Text(L10n.cycleStatus(todayStatus))
                    } icon: {
                        Image(systemName: CyclePalette.symbol(for: todayStatus) ?? "circle")
                            .foregroundStyle(CyclePalette.ringColor(for: todayStatus))
                    }
                    .font(.headline)
                }
            }
            .multilineTextAlignment(.center)
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cycleStatusCard")
    }
}

struct NextPeriodCard: View {
    let forecast: CycleForecast

    private var value: String { value(formatting: Formatting.cycleDate) }
    /// The same text with the date in spoken form, for VoiceOver.
    private var spokenValue: String { value(formatting: Formatting.spokenDay) }

    private func value(formatting format: (Date) -> String) -> String {
        if forecast.daysLate > 0 { return L10n.cycleNextPeriodLate(forecast.daysLate) }
        let date = format(forecast.nextPeriodStart)
        let days = forecast.daysUntilNextPeriod
        switch days {
        case 0: return L10n.cycleNextPeriodToday(date)
        case 1: return L10n.cycleNextPeriodTomorrow(date)
        default: return L10n.cycleNextPeriodIn(date, days)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(L10n.cycleNextPeriodTitle)
            } icon: {
                Image(systemName: "drop.fill").foregroundStyle(CyclePalette.period)
            }
            .font(.headline)
            Text(value)
                .font(.title3.weight(.semibold))
                .accessibilityLabel(spokenValue)
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cycleNextPeriodCard")
    }
}

struct FertileWindowCard: View {
    let forecast: CycleForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(L10n.cycleFertileTitle)
            } icon: {
                Image(systemName: "leaf.fill").foregroundStyle(CyclePalette.fertile)
            }
            .font(.headline)
            Text(range(formatting: Formatting.cycleDate))
                .font(.title3.weight(.semibold))
                .accessibilityLabel(range(formatting: Formatting.spokenDay))
            Label {
                Text(ovulation(formatting: Formatting.cycleDate))
                    .accessibilityLabel(ovulation(formatting: Formatting.spokenDay))
            } icon: {
                Image(systemName: forecast.ovulationConfirmed ? "checkmark.seal.fill" : "sparkles")
                    .foregroundStyle(CyclePalette.peak)
            }
            .font(.subheadline)
            if forecast.ovulationSource == .lhTest {
                Text(L10n.cycleOvulationLH)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if forecast.confidence == .low {
                Label(
                    forecast.usableCycleLengths.count < 2 ? L10n.cycleLowConfidenceFewCycles : L10n.cycleLowConfidenceIrregular,
                    systemImage: "exclamationmark.circle"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.orange)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cycleFertileCard")
    }

    private func range(formatting format: (Date) -> String) -> String {
        L10n.cycleFertileRange(format(forecast.fertileWindow.lowerBound), format(forecast.fertileWindow.upperBound))
    }

    private func ovulation(formatting format: (Date) -> String) -> String {
        let date = format(forecast.ovulationDate)
        return forecast.ovulationConfirmed ? L10n.cycleOvulationConfirmed(date) : L10n.cycleOvulation(date)
    }
}

/// Orange notice card, same style as `OverdueBanner`.
struct CycleNoticeCard<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String
    let identifier: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(message).font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            actions
        }
        .card(tint: Color.orange.opacity(0.12))
    }
}

extension CycleNoticeCard where Actions == EmptyView {
    init(symbol: String, title: String, message: String, identifier: String) {
        self.init(symbol: symbol, title: title, message: message, identifier: identifier) { EmptyView() }
    }
}
