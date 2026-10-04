import KickCore
import SwiftUI

/// "When did your last period start?" — from the empty Cycle tab.
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
        NavigationStack {
            Form {
                LastPeriodPicker(date: $date, now: now)
            }
            .navigationTitle(L10n.lastPeriodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) { Task { await save() } }
                        .disabled(saving)
                        .accessibilityIdentifier("lastPeriodSave")
                }
            }
            .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )) {
                Button(L10n.commonOK) {}
            }
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
/// today). A `Section`: place it inside a `Form`. Shared with onboarding.
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
