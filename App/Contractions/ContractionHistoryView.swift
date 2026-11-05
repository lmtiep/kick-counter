import KickCore
import SwiftUI

/// Past contraction episodes grouped by day (phase 20 spec §4.2): the time
/// span, the count and the averages of each; swipe to delete one, with a
/// confirmation.
struct ContractionHistoryView: View {
    @Environment(ContractionCoordinator.self) private var contractions
    @State private var pendingDelete: ContractionEpisode?
    @State private var sheet: ContractionSheet?
    @State private var pendingMarkerDelete: LabourMarkerRecord?

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
                        // A tap opens the episode's contractions, each editable.
                        NavigationLink {
                            ContractionEpisodeDetailView(entryIDs: episode.entries.map(\.id))
                        } label: {
                            row(episode)
                        }
                        .listRowBackground(Color.luna(.card))
                        .swipeActions {
                            Button(role: .destructive) {
                                pendingDelete = episode
                            } label: {
                                Label(L10n.commonDelete, systemImage: "trash")
                            }
                        }
                    }
                    ForEach(day.markers) { marker in
                        markerRow(marker)
                            .listRowBackground(Color.luna(.card))
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingMarkerDelete = marker
                                } label: {
                                    Label(L10n.commonDelete, systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(Formatting.weekdayDay(day.episodes.first?.startedAt ?? day.markers[0].at))
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
        .contractionSheets($sheet)
        .confirmationDialog(
            L10n.contractionWaterBrokeDeleteConfirm,
            isPresented: Binding(get: { pendingMarkerDelete != nil }, set: { if !$0 { pendingMarkerDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let marker = pendingMarkerDelete {
                    Task { await contractions.deleteMarker(id: marker.id) }
                }
                pendingMarkerDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingMarkerDelete = nil }
        }
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
            ForEach(episode.markers) { marker in
                Label(L10n.contractionWaterBrokeAt(Formatting.time(marker.at)), systemImage: "drop.fill")
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.pregText))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .monospacedDigit()
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("contractionEpisodeRow")
    }

    /// A "Vỡ ối" in no episode: a tap edits its time.
    private func markerRow(_ marker: LabourMarkerRecord) -> some View {
        let time = Formatting.time(marker.at)
        return Button {
            sheet = .editMarker(marker)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(L10n.contractionWaterBrokeButton, systemImage: "drop.fill")
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.pregText))
                Spacer(minLength: 8)
                Text(time)
                    .font(.luna(.bodyStrong))
                    .monospacedDigit()
                    .foregroundStyle(.luna(.textPrimary))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.contractionWaterBrokeAt(time))
        .accessibilityHint(L10n.contractionEditHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("contractionHistoryMarkerRow")
    }
}

/// One past episode's contractions, each editable or deletable (edit spec
/// 2026-11-06: history rows open the same sheet). Found again by the ids it was
/// opened with, so an edit that moves a contraction away does not lose the screen.
struct ContractionEpisodeDetailView: View {
    let entryIDs: [UUID]
    @Environment(ContractionCoordinator.self) private var contractions
    @Environment(\.dismiss) private var dismiss
    @State private var sheet: ContractionSheet?
    @State private var pendingDelete: ContractionEntry?
    @State private var pendingMarkerDelete: LabourMarkerRecord?

    private var episode: ContractionEpisode? {
        contractions.stats(week: nil).episodes.first { episode in episode.entries.contains { entryIDs.contains($0.id) } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let episode {
                    Text(Formatting.weekdayDay(episode.startedAt))
                        .font(.luna(.screenTitle))
                        .tracking(-0.56)
                        .foregroundStyle(.luna(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                }
                ContractionEpisodeCard(
                    episode: episode,
                    markers: episode?.markers ?? [],
                    onDelete: { pendingDelete = $0 },
                    onEdit: { sheet = .edit($0.record) },
                    onEditMarker: { sheet = .editMarker($0) },
                    onDeleteMarker: { pendingMarkerDelete = $0 }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .containerRelativeFrame(.horizontal)
        }
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("contractionEpisodeDetail")
        .contractionSheets($sheet)
        .onChange(of: episode == nil) { _, gone in
            if gone { dismiss() }
        }
        .confirmationDialog(
            L10n.contractionDeleteConfirm,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let entry = pendingDelete { Task { await contractions.delete(id: entry.id) } }
                pendingDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .confirmationDialog(
            L10n.contractionWaterBrokeDeleteConfirm,
            isPresented: Binding(get: { pendingMarkerDelete != nil }, set: { if !$0 { pendingMarkerDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let marker = pendingMarkerDelete { Task { await contractions.deleteMarker(id: marker.id) } }
                pendingMarkerDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingMarkerDelete = nil }
        }
    }
}
