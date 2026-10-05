import KickCore
import SwiftUI

/// "When did your last period start?" — from the empty Today screen (spec §4.9).
struct LastPeriodSheet: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var failure: CycleFailure?
    @State private var saving = false
    private let now: Date

    init(now: Date = AppClock.now()) {
        self.now = now
        _date = State(initialValue: now)
    }

    var body: some View {
        LunaSheet(title: L10n.lastPeriodTitle) {
            LunaSheetSectionTitle(title: L10n.lastPeriodDate)
            DatePicker(
                L10n.lastPeriodDate,
                selection: $date,
                in: CycleRules.lastPeriodRange(now: now, calendar: .current),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .accessibilityLabel(L10n.lastPeriodDate)
            .accessibilityIdentifier("lastPeriodPicker")
            .lunaCard(padding: 8)
            Text(L10n.lastPeriodHint)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
                .padding(.top, 8)
            Button(L10n.commonSave) { Task { await save() } }
                .buttonStyle(.pill(.filled(.cycleStrong)))
                .disabled(saving)
                .padding(.top, 20)
                .accessibilityIdentifier("lastPeriodSave")
            Button(L10n.commonCancel) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .accessibilityIdentifier("lastPeriodCancel")
        }
        .lunaSheetPresentation()
        .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if let failure = await cycle.logLastPeriod(startingOn: date) {
            cycle.clearFailure()
            self.failure = failure
        } else {
            dismiss()
        }
    }
}

/// Wheel picker for the first day of the last period (the past year up to
/// today). A `Section`: place it inside a `Form`. Used by onboarding's "Another day".
struct LastPeriodPicker: View {
    @Binding var date: Date
    let now: Date

    var body: some View {
        Section {
            DatePicker(
                L10n.lastPeriodDate,
                selection: $date,
                in: CycleRules.lastPeriodRange(now: now, calendar: .current),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .accessibilityLabel(L10n.lastPeriodDate)
            .accessibilityIdentifier("lastPeriodPicker")
        } header: {
            Text(L10n.lastPeriodDate)
        } footer: {
            Text(L10n.lastPeriodHint)
        }
    }
}
