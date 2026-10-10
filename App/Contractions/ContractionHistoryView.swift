import KickCore
import SwiftUI

/// Past contraction episodes grouped by day (phase 20 spec §4.2): the time
/// span, the count and the averages of each; swipe to delete one, with a
/// confirmation.
struct ContractionHistoryView: View {
    @Environment(ContractionCoordinator.self) private var contractions
    @State private var pendingDelete: ContractionEpisode?

    var body: some View {
        let days = contractions.stats(week: nil).pastEpisodesByDay(calendar: AppLocale.calendar)
        List {
            Group {
                Text(L10n.contractionHistory)
                    .font(.luna(.screenTitle))
                    .tracking(-0.56)
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                if days.isEmpty {
                    Text(L10n.contractionHistoryEmpty)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .accessibilityIdentifier("contractionHistoryEmpty")
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

            ForEach(days) { day in
                Section {
                    ForEach(day.episodes) { episode in
                        row(episode)
                            .listRowBackground(Color.luna(.card))
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDelete = episode
                                } label: {
                                    Label(L10n.commonDelete, systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(Formatting.weekdayDay(day.episodes[0].startedAt))
                        .font(.luna(.captionStrong))
                        .foregroundStyle(.luna(.textSecondary))
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("contractionHistoryList")
        .confirmationDialog(
            L10n.contractionHistoryDeleteConfirm,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let episode = pendingDelete {
                    Task { await contractions.delete(ids: episode.entries.map(\.id)) }
                }
                pendingDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        } message: {
            Text(L10n.contractionHistoryDeleteMessage)
        }
    }

    private func row(_ episode: ContractionEpisode) -> some View {
        let end = episode.endedAt ?? episode.lastStartedAt
        let span = Formatting.time(episode.startedAt) + "\u{2009}–\u{2009}" + Formatting.time(end)
        let averages = L10n.contractionHistoryAverages(
            duration: episode.averageDuration.map(ContractionClock.text) ?? L10n.contractionValueNone,
            interval: episode.averageInterval.map(ContractionClock.text) ?? L10n.contractionValueNone
        )
        return VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(span)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                    Spacer(minLength: 8)
                    Text(L10n.contractionHistoryCount(episode.count))
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.pregText))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(span)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(L10n.contractionHistoryCount(episode.count))
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.pregText))
                }
            }
            Text(averages)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .monospacedDigit()
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("contractionEpisodeRow")
    }
}
