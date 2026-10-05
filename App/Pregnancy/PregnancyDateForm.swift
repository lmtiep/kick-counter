import KickCore
import SwiftUI

/// Due date / last period picker shared by the date sheet and onboarding.
/// A `Section`: place it inside a `Form`.
struct PregnancyDateForm: View {
    @Binding var source: PregnancyDateSource
    @Binding var date: Date
    let now: Date

    private var dateLabel: String {
        source == .dueDate ? L10n.pregnancyDateSourceDueDate : L10n.pregnancyDateLMPLabel
    }

    var body: some View {
        Section {
            Picker(L10n.pregnancyDateSourceLabel, selection: $source) {
                Text(L10n.pregnancyDateSourceDueDate).tag(PregnancyDateSource.dueDate)
                Text(L10n.pregnancyDateSourceLMP).tag(PregnancyDateSource.lmp)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("pregnancyDateSourcePicker")

            DatePicker(
                dateLabel,
                selection: $date,
                in: PregnancyDateInput.range(for: source, now: now),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .accessibilityLabel(dateLabel)
            .accessibilityIdentifier("pregnancyDatePicker")
        } header: {
            Text(dateLabel)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(source == .dueDate ? L10n.pregnancyDateHintDueDate : L10n.pregnancyDateHintLMP)
                if source == .lmp {
                    Text(L10n.pregnancyDateEstimatedDue(
                        Formatting.longDate(PregnancyDates.dueDate(fromLMP: date))
                    ))
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("pregnancyEstimatedDue")
                }
            }
        }
        .onChange(of: source) { _, newSource in
            date = PregnancyDateInput.convert(date, to: newSource, now: now)
        }
    }
}
