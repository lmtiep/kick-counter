import KickCore
import SwiftUI

/// Pregnancy mode "Symptoms" (phase 5 spec §3.2), opened from Today's
/// shortcut: today's card, then the logged days grouped by gestational week.
/// Tap a day to edit it, swipe to delete (with a confirmation).
struct PregnancySymptomsView: View {
    @Environment(CycleCoordinator.self) private var cycle
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var logDay: CycleDaySelection?
    @State private var pendingDelete: CycleLogRecord?
    /// Set by the sheet's safety card: once the sheet is gone, open the week detail.
    @State private var showWarningsNext = false
    @State private var warningsWeek: WeekSelection?
    @State private var showingDateSheet = false
    @State private var actionFailure: CycleFailure?

    private var now: Date { AppClock.now() }
    private var today: Date { Calendar.current.startOfDay(for: now) }
    private var due: Date? { dueDate > 0 ? Date(timeIntervalSince1970: dueDate) : nil }
    private var timeline: PregnancyTimeline? { due.flatMap { PregnancyTimeline(dueDate: $0, now: now) } }

    var body: some View {
        List {
            Group {
                Text(L10n.symptomTitle)
                    .font(.luna(.screenTitle))
                    .tracking(-0.56)
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                if timeline != nil {
                    todayCard
                    Text(L10n.symptomsListTitle)
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .padding(.top, 10)
                        .accessibilityAddTraits(.isHeader)
                } else {
                    datesCard
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))

            if let due, timeline != nil {
                let sections = SymptomTimeline.sections(cycle.logs, dueDate: due, now: now)
                if sections.isEmpty {
                    Text(L10n.symptomsListEmpty)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                        .accessibilityIdentifier("symptomsListEmpty")
                }
                ForEach(sections) { section in
                    Section {
                        ForEach(section.logs) { log in
                            row(log)
                                .listRowBackground(Color.luna(.card))
                                .swipeActions {
                                    Button(role: .destructive) {
                                        pendingDelete = log
                                    } label: {
                                        Label(L10n.commonDelete, systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(L10n.weekTitle(section.week))
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
        .lunaStatusBarBackdrop()
        .background(.luna(.background))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logDay, onDismiss: openWarningsIfAsked) { selection in
            PregnancySymptomSheet(day: selection.date, existing: cycle.log(on: selection.date)) {
                showWarningsNext = true
            }
        }
        .fullScreenCover(item: $warningsWeek) { selection in
            WeekDetailView(currentWeek: selection.week, scrollToWarnings: true)
        }
        .sheet(isPresented: $showingDateSheet) { PregnancyDateSheet() }
        .confirmationDialog(
            L10n.symptomsDeleteConfirm,
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.commonDelete, role: .destructive) {
                // Captured now: closing the dialog clears `pendingDelete` before the task runs.
                if let log = pendingDelete {
                    Task { await delete(log) }
                }
            }
            Button(L10n.commonCancel, role: .cancel) { pendingDelete = nil }
        }
        .alert(failureMessage ?? "", isPresented: failureBinding) {
            Button(L10n.commonOK) {}
        }
    }

    // MARK: - Cards and rows

    private var todayCard: some View {
        let log = cycle.log(on: today)
        let summary = CycleTexts.logSummary(log, mode: .pregnant)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.commonToday)
                    .lunaLabelStyle(.pregStrong)
                Text(summary ?? L10n.symptomsTodayEmpty)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("symptomsTodaySummary")
            Button(summary == nil ? L10n.symptomsLogToday : L10n.symptomsEdit) {
                logDay = CycleDaySelection(date: today)
            }
            .buttonStyle(.pill(.filled(.pregStrong), fullWidth: false, height: 44))
            .accessibilityIdentifier("symptomsLogToday")
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("symptomsTodayCard")
    }

    private func row(_ log: CycleLogRecord) -> some View {
        let warns = Symptom.needsSafetyNote(log.symptoms(for: .pregnant))
        let summary = CycleTexts.logSummary(log, mode: .pregnant) ?? ""
        return Button {
            logDay = CycleDaySelection(date: log.day)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatting.weekdayDay(log.day))
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(summary)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if warns {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.luna(.warningText))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [Formatting.weekdayDay(log.day), summary, warns ? L10n.symptomsRowWarning : nil]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("symptomDayRow")
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
                .accessibilityIdentifier("symptomsAddDates")
        }
        .lunaCard()
    }

    // MARK: - Actions

    private func openWarningsIfAsked() {
        guard showWarningsNext else { return }
        showWarningsNext = false
        if let timeline {
            warningsWeek = WeekSelection(week: WeeklyContentLibrary.clampedWeek(timeline.week.weeks))
        }
    }

    /// Clears what this screen shows (mood, pregnancy symptoms, note); a day
    /// with nothing else logged is removed.
    private func delete(_ record: CycleLogRecord) async {
        var log = record
        pendingDelete = nil
        log.moods = []
        log.setSymptoms([], for: .pregnant)
        log.note = ""
        if let failure = await cycle.saveLog(log) {
            cycle.clearFailure()
            actionFailure = failure
        }
    }

    private var failureMessage: String? {
        (actionFailure ?? cycle.failure).map(L10n.cycleFailure)
    }

    /// Only while no sheet is open: the sheet reports its own errors.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { failureMessage != nil && logDay == nil },
            set: { if !$0 { actionFailure = nil; cycle.clearFailure() } }
        )
    }
}
