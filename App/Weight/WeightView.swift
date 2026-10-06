import KickCore
import SwiftUI

/// The mother's weight (phase 5 spec §3.3), opened from Today's shortcut or
/// card: setup (pre-pregnancy weight, optional height) until a pre-pregnancy
/// weight is known, then the gain, BMI group, status and chart; the entry
/// card; the history by week (swipe to delete, with a confirmation).
struct WeightView: View {
    @Environment(WeightCoordinator.self) private var weight
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var pendingDelete: WeightRecord?
    @State private var showingDateSheet = false
    @State private var toast: String?

    private var now: Date { AppClock.now() }
    private var due: Date? { dueDate > 0 ? Date(timeIntervalSince1970: dueDate) : nil }
    private var timeline: PregnancyTimeline? { due.flatMap { PregnancyTimeline(dueDate: $0, now: now) } }

    var body: some View {
        List {
            Group {
                Text(L10n.weightTitle)
                    .font(.luna(.screenTitle))
                    .tracking(-0.56)
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                if let due, timeline != nil {
                    if weight.profile.preWeightKg == nil {
                        setupCard
                    } else {
                        WeightSummaryCard(
                            points: WeightStats.points(weight.entries, profile: weight.profile, dueDate: due),
                            profile: weight.profile
                        )
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("weightSummaryCard")
                    }
                    WeightEntryCard(dueDate: due) { toast = L10n.weightSaved }
                    Text(L10n.weightHistory)
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .padding(.top, 10)
                        .accessibilityAddTraits(.isHeader)
                    if weight.entries.isEmpty {
                        Text(L10n.weightHistoryEmpty)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                            .accessibilityIdentifier("weightHistoryEmpty")
                    }
                } else {
                    datesCard
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

            if let due, timeline != nil {
                ForEach(WeightStats.sections(weight.entries, dueDate: due)) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            row(entry)
                                .listRowBackground(Color.luna(.card))
                                .swipeActions {
                                    Button(role: .destructive) {
                                        pendingDelete = entry
                                    } label: {
                                        Label(L10n.commonDelete, systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(section.week.map(L10n.weekTitle) ?? L10n.weightHistoryOutside)
                            .font(.luna(.captionStrong))
                            .foregroundStyle(.luna(.textSecondary))
                            .textCase(nil)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .lunaStatusBarBackdrop()
        .background(.luna(.background))
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .toast($toast)
        .sheet(isPresented: $showingDateSheet) { PregnancyDateSheet() }
        .confirmationDialog(
            L10n.weightDeleteConfirm,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                if let entry = pendingDelete { weight.delete(id: entry.id) }
                pendingDelete = nil
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .alert(weight.failure.map(L10n.weightFailure) ?? "", isPresented: Binding(
            get: { weight.failure != nil && !showingDateSheet },
            set: { if !$0 { weight.clearFailure() } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.weightSetupTitle)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Text(L10n.weightSetupBody)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            MaternalProfileForm(requiresPreWeight: true) {}
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weightSetupCard")
    }

    /// "Thu, Oct 1" and "+6.0 kg" on the left, "58.0 kg" on the right.
    private func row(_ entry: WeightRecord) -> some View {
        let gain = weight.profile.preWeightKg.map { Formatting.kilograms(WeightRules.rounded(entry.kg - $0), signed: true) }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.weekdayDay(entry.day))
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                if let gain {
                    Text(gain)
                        .font(.luna(.small))
                        .foregroundStyle(.luna(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Formatting.kilograms(entry.kg))
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weightRow")
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.pregnancyEmptyTitle)
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
            Text(L10n.pregnancyEmptyBody)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
            Button(L10n.pregnancyEmptyAction) { showingDateSheet = true }
                .buttonStyle(.pill(.filled(.pregStrong)))
                .accessibilityIdentifier("weightAddDates")
        }
        .lunaCard()
    }
}
