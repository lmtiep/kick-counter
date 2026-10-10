import KickCore
import KickData
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "history")

/// Kick history, opened from Kicks (spec §4.7): 7 days / 4 weeks, the average
/// time to 10 movements with its chart, every session (swipe to delete) and
/// when to call the doctor.
struct HistoryView: View {
    enum Span: Hashable {
        case week
        case month
    }

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<KickSession> { $0.statusRaw != "active" },
        sort: \KickSession.startedAt,
        order: .reverse
    )
    private var sessions: [KickSession]
    @State private var pendingDelete: KickSession?
    @State private var range = Span.week

    private var now: Date { AppClock.now() }

    var body: some View {
        let states = sessions.map(\.state)
        List {
            Group {
                Text(L10n.historyHeading)
                    .font(.luna(.screenTitle))
                    .tracking(-0.56)
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                SegmentedPill(options: [
                    SegmentedOption(value: Span.week, title: L10n.historyRangeWeek, identifier: "historyRange7"),
                    SegmentedOption(value: Span.month, title: L10n.historyRangeMonth, identifier: "historyRange28"),
                ], selection: $range, selectedFill: .segmentSelectedPreg)
                averageCard(states)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

            Section {
                if sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.historyEmptyTitle)
                            .font(.luna(.cardTitleSmall))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.historyEmptyBody)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.luna(.card))
                }
                ForEach(sessions) { session in
                    SessionRow(session: session, now: now)
                        .listRowBackground(Color.luna(.card))
                        .swipeActions {
                            Button(role: .destructive) {
                                pendingDelete = session
                            } label: {
                                Label(L10n.commonDelete, systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text(L10n.historySessions)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .textCase(nil)
                    .accessibilityAddTraits(.isHeader)
            }

            guideCard
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .lunaBackground()
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            L10n.historyDeleteConfirmTitle,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) { deletePending() }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
    }

    private func averageCard(_ states: [SessionState]) -> some View {
        let calendar = AppLocale.calendar
        let average = HistoryStats.averageMinutes(states, endingAt: now, days: range == .week ? 7 : 28, calendar: calendar)
        let bars = range == .week
            ? HistoryStats.daily(states, endingAt: now, calendar: calendar)
            : HistoryStats.weekly(states, endingAt: now, calendar: calendar)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.historyAverage)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                Text(average.map(Formatting.minutes) ?? "–")
                    .font(.luna(.averageFigure))
                    .foregroundStyle(.luna(.textPrimary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("historyAverage")
            HistoryChart(items: bars.enumerated().map { index, bar in
                HistoryChart.Item(id: index, label: label(for: bar, index: index, count: bars.count), minutes: bar.minutes, isCurrent: bar.isCurrent)
            })
        }
        .lunaCard()
    }

    /// "T5"…"Nay" for days; "3 tuần trước"…"Tuần này" for weeks.
    private func label(for bar: HistoryBar, index: Int, count: Int) -> String {
        if range == .week {
            return bar.isCurrent ? L10n.historyToday : WeekdayLabel.short(for: bar.start, calendar: AppLocale.calendar)
        }
        switch count - 1 - index {
        case 0: return L10n.historyThisWeek
        case 1: return L10n.historyLastWeek
        case let weeksAgo: return L10n.historyWeeksAgo(weeksAgo)
        }
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.historyGuideTitle)
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.warningText))
            Text(L10n.historyGuideBody)
                .font(.luna(.caption))
                .lineSpacing(3)
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
        }
        .lunaCard(.warningBackground, padding: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("historyGuide")
    }

    private func deletePending() {
        guard let session = pendingDelete else { return }
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            logger.error("Deleting session failed: \(error.localizedDescription)")
            modelContext.rollback()
        }
        pendingDelete = nil
    }
}
