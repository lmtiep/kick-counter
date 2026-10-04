import KickCore
import KickData
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "history")

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<KickSession> { $0.statusRaw != "active" },
        sort: \KickSession.startedAt,
        order: .reverse
    )
    private var sessions: [KickSession]
    @State private var pendingDelete: KickSession?

    private var days: [(day: Date, sessions: [KickSession])] {
        Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.startedAt) }
            .map { (day: $0.key, sessions: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        L10n.historyEmptyTitle,
                        systemImage: "chart.bar",
                        description: Text(L10n.historyEmptyBody)
                    )
                } else {
                    List {
                        Section {
                            HistoryChart(
                                summaries: HistorySummary.daily(sessions.map(\.state), endingAt: .now),
                                endingAt: .now
                            )
                        }
                        ForEach(days, id: \.day) { group in
                            Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                                ForEach(group.sessions) { session in
                                    SessionRow(session: session)
                                        .swipeActions {
                                            Button(role: .destructive) {
                                                pendingDelete = session
                                            } label: {
                                                Label(L10n.commonDelete, systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.historyTitle)
            .confirmationDialog(
                L10n.historyDeleteConfirmTitle,
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(L10n.commonDelete, role: .destructive) { deletePending() }
                Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
            }
        }
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
