import KickCore
import SwiftUI

/// Log or edit one pregnancy day (phase 5 spec §3.2): mood, pregnancy symptoms
/// and a note. Contractions or swollen feet show the safety card under the
/// chips. Flow, cycle symptoms, LH, BBT, mucus and unknown values stay as stored.
struct PregnancySymptomSheet: View {
    let day: Date
    private let existing: CycleLogRecord?
    /// After a save from the safety card: open the week detail at its warnings.
    private let onShowWarnings: () -> Void

    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var moods: Set<Mood>
    @State private var symptoms: Set<Symptom>
    @State private var note: String
    @State private var failure: CycleFailure?
    @State private var saving = false

    init(day: Date, existing: CycleLogRecord?, onShowWarnings: @escaping () -> Void) {
        self.day = Calendar.current.startOfDay(for: day)
        self.existing = existing
        self.onShowWarnings = onShowWarnings
        _moods = State(initialValue: Set(existing?.moods ?? []))
        _symptoms = State(initialValue: Set(existing?.symptoms(for: .pregnant) ?? []))
        _note = State(initialValue: existing?.note ?? "")
    }

    private var title: String {
        Calendar.current.isDate(day, inSameDayAs: AppClock.now())
            ? L10n.dayLogTitleToday(Formatting.shortDay(day))
            : Formatting.weekdayDay(day)
    }

    private var showsSafetyCard: Bool { Symptom.needsSafetyNote(symptoms) }

    var body: some View {
        LunaSheet(title: title) {
            LunaSheetSectionTitle(title: L10n.symptomMoodTitle)
            MoodChips(selection: $moods, selectedFill: .pregStrong)

            LunaSheetSectionTitle(title: L10n.symptomTitle)
            SymptomChips(mode: .pregnant, selection: $symptoms, selectedFill: .pregStrong)

            // Read right after the chips, before the note (spec §5).
            if showsSafetyCard {
                SymptomSafetyCard(symptoms: symptoms) {
                    Task {
                        if await save() { onShowWarnings() }
                    }
                }
                .padding(.top, 14)
                .transition(.opacity)
            }

            LunaSheetSectionTitle(title: L10n.dayLogNote)
            TextField(L10n.dayLogNote, text: $note, axis: .vertical)
                .lineLimit(2...5)
                .font(.luna(.body))
                .padding(14)
                .background(.luna(.card), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("symptomNoteField")

            Button(L10n.commonCancel) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .padding(.top, 12)
                .accessibilityIdentifier("symptomCancel")
        }
        // A fade (also with Reduce Motion); none in UI tests.
        .animation(LunaMotion.isEnabled ? LunaMotion.fade : nil, value: showsSafetyCard)
        .safeAreaInset(edge: .bottom) {
            Button(L10n.commonSave) { Task { await save() } }
                .buttonStyle(.pill(.filled(.pregStrong)))
                .disabled(saving)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(.luna(.background))
                .accessibilityIdentifier("symptomSave")
        }
        .lunaSheetPresentation()
        .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    /// Saves and closes; false (sheet stays open with an alert) when it failed.
    @discardableResult
    private func save() async -> Bool {
        // Start from what is stored: everything this sheet does not show stays.
        var log = existing ?? CycleLogRecord(day: day)
        log.day = day
        log.moods = RawList.ordered(moods)
        log.setSymptoms(symptoms, for: .pregnant)
        log.note = note
        saving = true
        defer { saving = false }
        if let result = await cycle.saveLog(log) {
            cycle.clearFailure()
            failure = result
            return false
        }
        dismiss()
        return true
    }
}
