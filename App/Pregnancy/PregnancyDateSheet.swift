import KickCore
import SwiftUI

/// Enter or edit the pregnancy dates. Used from the Pregnancy tab and Settings.
struct PregnancyDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var source: PregnancyDateSource
    @State private var date: Date
    private let now: Date

    init(now: Date = AppClock.now()) {
        self.now = now
        let selection = PregnancyDateInput.initialSelection(for: PregnancyProfile.load(from: AppGroup.defaults), now: now)
        _source = State(initialValue: selection.source)
        _date = State(initialValue: selection.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                PregnancyDateForm(source: $source, date: $date, now: now)
            }
            .scrollContentBackground(.hidden)
            .lunaBackground()
            .navigationTitle(L10n.pregnancyDateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) {
                        PregnancyProfile.save(source: source, date: date, to: AppGroup.defaults)
                        dismiss()
                    }
                    .accessibilityIdentifier("pregnancyDateSave")
                }
            }
        }
        .lunaSheetPresentation()
    }
}
