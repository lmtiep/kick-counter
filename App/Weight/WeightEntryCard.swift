import Accessibility
import KickCore
import SwiftUI

/// "Log weight" (phase 5 spec §3.3): the day (today by default, never later
/// than today nor before the last period), the weight with −/+ 0.1 kg buttons
/// and a field that takes "56,2" and "56.2", and Save.
struct WeightEntryCard: View {
    let dueDate: Date
    let onSaved: () -> Void

    @Environment(WeightCoordinator.self) private var weight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var day = Calendar.current.startOfDay(for: AppClock.now())
    @State private var text = ""
    @State private var invalid = false
    @State private var failure: WeightFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.weightAdd)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            DatePicker(
                L10n.weightAddDate,
                selection: $day,
                in: WeightRules.dayRange(dueDate: dueDate, now: AppClock.now(), calendar: .current),
                displayedComponents: .date
            )
            .font(.luna(.body))
            .foregroundStyle(.luna(.textPrimary))
            .tint(.luna(.pregStrong))
            .accessibilityIdentifier("weightDatePicker")
            // At accessibility sizes the −/+ buttons go under the figure so it is not cut.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    kgField
                    HStack {
                        stepButton(symbol: "minus", label: L10n.weightLess, delta: -0.1, identifier: "weightMinus")
                        Spacer()
                        stepButton(symbol: "plus", label: L10n.weightMore, delta: 0.1, identifier: "weightPlus")
                    }
                }
            } else {
                HStack(spacing: 12) {
                    stepButton(symbol: "minus", label: L10n.weightLess, delta: -0.1, identifier: "weightMinus")
                    kgField
                    stepButton(symbol: "plus", label: L10n.weightMore, delta: 0.1, identifier: "weightPlus")
                }
            }
            if invalid {
                Label(L10n.weightInvalidKg, systemImage: "exclamationmark.triangle.fill")
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.warningText))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightKgError")
            }
            Button(L10n.commonSave, action: save)
                .buttonStyle(.pill(.filled(.pregStrong)))
                .accessibilityIdentifier("weightSave")
        }
        .lunaCard()
        .onAppear { if text.isEmpty { prefill() } }
        .onChange(of: day) { prefill() }
        // Set up just now: start from the pre-pregnancy weight.
        .onChange(of: weight.profile.preWeightKg) { if weight.entries.isEmpty { prefill() } }
        .alert(failure.map(L10n.weightFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
    }

    /// The figure (32/700, tabular digits) and "kg".
    private var kgField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField(L10n.weightAddKg, text: $text, prompt: Text(verbatim: "–"))
                .keyboardType(.decimalPad)
                .font(.luna(.display))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .accessibilityLabel(L10n.weightAddKg)
                .accessibilityIdentifier("weightKgField")
                .onChange(of: text) { invalid = false }
            Text(verbatim: "kg")
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textSecondary))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
    }

    /// 42 pt round −/+ button on `surface`.
    private func stepButton(symbol: String, label: String, delta: Double, identifier: String) -> some View {
        Button {
            let value = (currentValue ?? startValue) + delta
            text = format(min(max(WeightRules.rounded(value), WeightRules.kgRange.lowerBound), WeightRules.kgRange.upperBound))
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 42, height: 42)
                .background(Circle().fill(.luna(.surface)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var currentValue: Double? {
        if case .valid(let value) = DecimalEntry(text: text, range: WeightRules.kgRange) { return value }
        return nil
    }

    /// The day's stored weight, else the latest, else the pre-pregnancy weight.
    private var knownValue: Double? {
        weight.entry(on: day)?.kg ?? weight.latest?.kg ?? weight.profile.preWeightKg
    }

    /// Where −/+ start from an empty field.
    private var startValue: Double { knownValue ?? 60 }

    private func prefill() {
        text = knownValue.map(format) ?? ""
    }

    private func format(_ kg: Double) -> String {
        kg.formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(Formatting.locale))
    }

    private func save() {
        guard case .valid(let kg) = DecimalEntry(text: text, range: WeightRules.kgRange) else {
            invalid = true
            AccessibilityNotification.Announcement(L10n.weightInvalidKg).post()
            return
        }
        switch weight.save(kg: kg, on: day) {
        case nil:
            onSaved()
        case .outOfRange?:
            invalid = true
            AccessibilityNotification.Announcement(L10n.weightInvalidKg).post()
        case let other?:
            weight.clearFailure()
            failure = other
        }
    }
}
