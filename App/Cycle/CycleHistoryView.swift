import KickCore
import SwiftUI

/// Today → "Coming up" → history → one cycle (phase 10 spec §4).
enum CycleHistoryRoute: Hashable {
    case list
    case cycle(UUID)
}

/// What VoiceOver reads for a history row (spec §4.2).
enum CycleHistoryTexts {
    static func spokenRow(_ cycle: PastCycle, policy: CycleDisplayPolicy) -> String {
        var parts: [String] = []
        if cycle.isCurrent, let day = cycle.cycleDay {
            parts.append(L10n.cycleHistorySpokenCurrent(day))
        } else {
            parts.append(L10n.cycleHistorySpokenStarted(Formatting.spokenDay(cycle.start)))
        }
        if let length = cycle.length { parts.append(L10n.days(length)) }
        let bleeding = L10n.days(cycle.periodLength)
        parts.append(policy.predictedBleedLabel == .withdrawalBleed
            ? L10n.cycleHistorySpokenBleed(bleeding)
            : L10n.cycleHistorySpokenPeriod(bleeding))
        parts.append(L10n.cycleHistorySpokenLogged(cycle.loggedDays.count))
        if !cycle.isCurrent, !cycle.countsTowardAverage { parts.append(L10n.cycleHistorySpokenNotCounted) }
        return parts.joined(separator: ", ")
    }
}

struct CycleHistoryView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dynamicTypeSize) private var typeSize

    private var history: CycleHistorySummary {
        CycleHistory.make(periods: cycle.periods, logs: cycle.logs, now: AppClock.now())
    }

    var body: some View {
        let history = history
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if history.cycles.isEmpty {
                    Text(L10n.cycleHistoryEmpty)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lunaCard()
                        .accessibilityIdentifier("cycleHistoryEmpty")
                } else {
                    summaryCard(history)
                    VStack(spacing: 0) {
                        ForEach(Array(history.cycles.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { LunaDivider().padding(.horizontal, 18) }
                            NavigationLink(value: CycleHistoryRoute.cycle(item.periodID)) {
                                CycleHistoryRowView(cycle: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(CycleHistoryTexts.spokenRow(item, policy: cycle.policy))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("cycleHistoryRow")
                        }
                    }
                    .lunaCard(padding: 0)
                }
            }
            .padding(20)
        }
        .background(.luna(.background))
        .navigationTitle(L10n.cycleHistoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func summaryCard(_ history: CycleHistorySummary) -> some View {
        // Side by side; one above the other at accessibility sizes.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 4) {
                if let average = history.averageCycleLength {
                    // The figure and its label are one spoken element
                    // ("cycleHistoryAverageCycle"); the range is a second,
                    // separately reachable element, so `.combine` on this group
                    // does not swallow its own identifier (final review).
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.days(average))
                            .font(.luna(.statFigure))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.cycleHistoryAverageCycle)
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("cycleHistoryAverageCycle")
                    if let range = history.cycleLengthRange, range.lowerBound < range.upperBound {
                        Text(L10n.cycleHistoryRange(range.lowerBound, range.upperBound))
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                            .accessibilityIdentifier("cycleHistoryRange")
                    }
                } else {
                    Text(L10n.cycleHistoryNeedMore)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("cycleHistoryNeedMore")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let period = history.averagePeriodLength {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.days(period))
                        .font(.luna(.statFigure))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(cycle.policy.predictedBleedLabel == .withdrawalBleed ? L10n.cycleHistoryAverageBleed : L10n.cycleHistoryAveragePeriod)
                        .font(.luna(.small))
                        .foregroundStyle(.luna(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("cycleHistoryAveragePeriod")
            }
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cycleHistorySummary")
    }
}

/// Title, length, the bar and the "not counted" note (spec §4.2).
struct CycleHistoryRowView: View {
    let cycle: PastCycle
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the length moves under the title, so neither truncates.
        let stacked = typeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cycle.isCurrent ? L10n.cycleHistoryCurrent(cycle.cycleDay ?? 1) : Formatting.shortDay(cycle.start))
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                    if stacked { lengthText }
                }
                Spacer(minLength: 8)
                if !stacked { lengthText }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.textSecondary))
            }
            CycleHistoryBar(cycle: cycle)
            if !cycle.isCurrent, !cycle.countsTowardAverage {
                Text(L10n.cycleHistoryNotCounted)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var lengthText: some View {
        if let length = cycle.length {
            Text(L10n.days(length))
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The track is as wide as 45 days; bleeding is a rose segment, logged days are dots.
struct CycleHistoryBar: View {
    let cycle: PastCycle
    private static let fullDays = 45

    var body: some View {
        GeometryReader { proxy in
            let dayWidth = proxy.size.width / CGFloat(Self.fullDays)
            let days = min(cycle.length ?? cycle.cycleDay ?? 1, Self.fullDays)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.luna(.cycleSoft))
                    .overlay {
                        if cycle.isCurrent {
                            Capsule().strokeBorder(.luna(.cycle), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                    .frame(width: dayWidth * CGFloat(days))
                Capsule()
                    .fill(.luna(.cycle))
                    .frame(width: dayWidth * CGFloat(min(cycle.periodLength, days)))
                ForEach(cycle.loggedDays.filter { $0 < days }, id: \.self) { offset in
                    Circle()
                        .fill(.luna(.cycleStrong))
                        .frame(width: 4, height: 4)
                        .offset(x: dayWidth * (CGFloat(offset) + 0.5) - 2)
                }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

/// One cycle's logged days, oldest first; tapping a day opens the day log (spec §4.3).
struct CycleDetailView: View {
    let periodID: UUID
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var logDay: CycleDaySelection?

    private var past: PastCycle? {
        CycleHistory.make(periods: cycle.periods, logs: cycle.logs, now: AppClock.now())
            .cycles.first { $0.periodID == periodID }
    }

    var body: some View {
        let past = past
        ScrollView {
            VStack(spacing: 0) {
                if let past, !past.loggedDays.isEmpty {
                    ForEach(Array(past.loggedDays.enumerated()), id: \.element) { index, offset in
                        if index > 0 { LunaDivider().padding(.horizontal, 18) }
                        dayRow(past, offset: offset)
                    }
                } else {
                    Text(L10n.cycleHistoryDetailEmpty)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .accessibilityIdentifier("cycleDetailEmpty")
                }
            }
            .lunaCard(padding: 0)
            .padding(20)
        }
        .background(.luna(.background))
        .navigationTitle(past.map(title) ?? L10n.cycleHistoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $logDay) { selection in
            CycleDayLogSheet(day: selection.date, existing: cycle.log(on: selection.date))
        }
        .onAppear {
            if past == nil { dismiss() }
        }
        .onChange(of: past == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }

    private func title(_ past: PastCycle) -> String {
        guard let length = past.length,
              let last = Calendar.current.date(byAdding: .day, value: length - 1, to: past.start)
        else { return L10n.cycleHistoryCurrentTitle }
        return Formatting.shortDay(past.start) + " – " + Formatting.shortDay(last)
    }

    private func dayRow(_ past: PastCycle, offset: Int) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: past.start) ?? past.start
        let log = cycle.log(on: date)
        let summary = CycleTexts.logSummary(log, includingNote: false) ?? ""
        let note = log?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let heading = L10n.cycleHistoryDetailDay(offset + 1, Formatting.shortDay(date))
        let spokenHeading = L10n.cycleHistoryDetailDay(offset + 1, Formatting.spokenDay(date))
        return Button {
            logDay = CycleDaySelection(date: date)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(heading)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                    if !summary.isEmpty {
                        Text(summary)
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !note.isEmpty {
                        Text(verbatim: note)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.textSecondary))
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([spokenHeading, summary, note].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("cycleDetailDay")
    }
}
