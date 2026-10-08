import KickCore
import SwiftUI

/// "Thêm kỳ kinh trước đây" from the cycle history (phase 13 spec §3.2): the
/// first day and how many days of bleeding. Overlaps and future dates are
/// shown inline and nothing is saved.
struct AddPastPeriodSheet: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var length: Int
    @State private var failure: CycleFailure?
    @State private var saving = false
    private let today: Date
    private let onSaved: () -> Void

    /// `defaultStart`: one typical cycle before the oldest logged period, or
    /// 28 days before today when nothing is logged.
    init(defaultStart: Date, typicalLength: Int, now: Date = AppClock.now(), onSaved: @escaping () -> Void) {
        let today = Calendar.current.startOfDay(for: now)
        self.today = today
        self.onSaved = onSaved
        _start = State(initialValue: min(Calendar.current.startOfDay(for: defaultStart), today))
        _length = State(initialValue: min(max(typicalLength, CycleSettings.periodLengthRange.lowerBound), CycleSettings.periodLengthRange.upperBound))
    }

    /// The start shown when the sheet opens (spec §3.2).
    static func defaultStart(periods: [PeriodRecord], settings: CycleSettings, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        guard let oldest = periods.map(\.startDate).min() else {
            return calendar.date(byAdding: .day, value: -CycleSettings.defaultCycleLength, to: today) ?? today
        }
        return calendar.date(byAdding: .day, value: -settings.typicalCycleLength, to: calendar.startOfDay(for: oldest)) ?? oldest
    }

    private var isBleed: Bool { cycle.policy.predictedBleedLabel == .withdrawalBleed }

    private var end: Date {
        Calendar.current.date(byAdding: .day, value: length - 1, to: Calendar.current.startOfDay(for: start)) ?? start
    }

    var body: some View {
        LunaSheet(title: isBleed ? L10n.cycleHistoryAddPastBleed : L10n.cycleHistoryAddPast) {
            LunaSheetSectionTitle(title: L10n.addPastStart)
            DatePicker(L10n.addPastStart, selection: $start, in: ...today, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(.luna(.cycleStrong))
                // At AX3+ the system calendar's month title runs into its
                // "previous month" arrow; the range line below stays full size.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .frame(maxWidth: .infinity)
                .lunaCard(padding: 8)
                .accessibilityLabel(L10n.addPastStart)
                .accessibilityIdentifier("addPastStart")

            LunaSheetSectionTitle(title: isBleed ? L10n.addPastLengthBleed : L10n.addPastLength)
            VStack(alignment: .leading, spacing: 10) {
                Stepper(value: $length, in: CycleSettings.periodLengthRange) {
                    Text(L10n.days(length))
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityLabel(isBleed ? L10n.addPastLengthBleed : L10n.addPastLength)
                .accessibilityValue(L10n.days(length))
                .accessibilityIdentifier("addPastLength")
                LunaDivider()
                rangeLine
            }
            .lunaCard(padding: 14)

            if let failure {
                Label(message(for: failure), systemImage: "exclamationmark.triangle.fill")
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.warningText))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("addPastError")
            }

            Button(L10n.addPastSave) { Task { await save() } }
                .buttonStyle(.pill(.filled(.cycleStrong)))
                .disabled(saving)
                .padding(.top, 20)
                .accessibilityIdentifier("addPastSave")
            Button(L10n.commonCancel) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .accessibilityIdentifier("addPastCancel")
        }
        .lunaSheetPresentation()
        .onChange(of: start) { failure = nil }
        .onChange(of: length) { failure = nil }
    }

    /// "Từ 3 thg 9 đến 7 thg 9", or "Vẫn đang diễn ra" when the last day is after today.
    private var rangeLine: some View {
        let ongoing = end > today
        let shown = L10n.addPastRange(Formatting.shortDay(start), Formatting.shortDay(end))
        let spoken = L10n.addPastRange(Formatting.spokenDay(start), Formatting.spokenDay(end))
        return VStack(alignment: .leading, spacing: 2) {
            Text(shown)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(spoken)
            if ongoing {
                Text(L10n.addPastOngoing)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("addPastRange")
    }

    private func message(for failure: CycleFailure) -> String {
        switch failure {
        case .overlapsExistingPeriod: L10n.addPastErrorOverlap
        case .futureDate: L10n.addPastErrorFuture
        default: L10n.addPastErrorSave
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        if let result = await cycle.addPastPeriod(start: start, length: length) {
            // Shown here, not in the screen's alert.
            cycle.clearFailure()
            failure = result
        } else {
            onSaved()
            dismiss()
        }
    }
}
