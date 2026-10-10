import KickCore
import SwiftUI

/// "I'm pregnant" (spec §4.9): by due date or by last period, ±1 day (tap the
/// date for a calendar), today's weeks and the due date, then "Turn on
/// pregnancy mode". Cycle data is kept.
struct ImPregnantSheet: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var source: PregnancyDateSource
    @State private var date: Date
    @State private var showingPicker = false
    private let now: Date

    /// Starts from the latest logged period, unless stored pregnancy dates already
    /// belong to this pregnancy (e.g. a due date corrected by ultrasound, then a
    /// round trip through "Trying to conceive"); otherwise from the stored dates
    /// (or the usual default).
    init(lastPeriodStart: Date?, now: Date = AppClock.now()) {
        self.now = now
        let stored = PregnancyProfile.load(from: AppGroup.defaults)
        if let lastPeriodStart, !Self.belongsToCurrentPregnancy(stored, lastPeriodStart: lastPeriodStart) {
            _source = State(initialValue: .lmp)
            _date = State(initialValue: PregnancyDateInput.clamp(lastPeriodStart, for: .lmp, now: now))
        } else {
            let selection = PregnancyDateInput.initialSelection(for: stored, now: now)
            _source = State(initialValue: selection.source)
            _date = State(initialValue: selection.date)
        }
    }

    /// A stored due date whose implied LMP (due − 280 days) is no more than four
    /// weeks before the logged period is the current pregnancy, not an old one.
    private static func belongsToCurrentPregnancy(_ profile: PregnancyProfile, lastPeriodStart: Date) -> Bool {
        guard let due = profile.dueDate,
              let impliedLMP = Calendar.current.date(byAdding: .day, value: -280, to: due),
              let earliest = Calendar.current.date(byAdding: .day, value: -28, to: lastPeriodStart)
        else { return false }
        return impliedLMP >= earliest
    }

    private var dueDate: Date {
        source == .dueDate ? date : PregnancyDates.dueDate(fromLMP: date)
    }

    /// "Today: 4 weeks, 4 days · due June 7, 2027".
    private var result: String {
        let weeks = PregnancyTimeline(dueDate: dueDate, now: now).map { L10n.pregnancyWeekLabel($0.week) } ?? ""
        return L10n.imPregnantResult(weeks, Formatting.longDate(dueDate))
    }

    var body: some View {
        LunaSheet(title: L10n.imPregnantTitle) {
            Text(L10n.imPregnantSwitchBody)
                .font(.luna(.body))
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            SegmentedPill(options: [
                SegmentedOption(value: PregnancyDateSource.dueDate, title: L10n.imPregnantByDue, identifier: "imPregnantSourceDue"),
                SegmentedOption(value: PregnancyDateSource.lmp, title: L10n.imPregnantByLMP, identifier: "imPregnantSourceLMP"),
            ], selection: $source)
            .padding(.top, 16)
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    stepButton("minus", label: L10n.imPregnantEarlier, identifier: "imPregnantEarlier") { shift(by: -1) }
                    Button { showingPicker = true } label: {
                        VStack(spacing: 2) {
                            Text(source == .dueDate ? L10n.pregnancyDateSourceDueDate : L10n.pregnancyDateLMPLabel)
                                .font(.luna(.small))
                                .foregroundStyle(.luna(.textSecondary))
                            Text(Formatting.dayMonthYear(date))
                                .font(.luna(size: 21, weight: .bold, relativeTo: .title2))
                                .foregroundStyle(.luna(.textPrimary))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(minWidth: 150, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("imPregnantDate")
                    stepButton("plus", label: L10n.imPregnantLater, identifier: "imPregnantLater") { shift(by: 1) }
                }
                Text(result)
                    .font(.luna(.captionStrong))
                    .foregroundStyle(.luna(.pregOnSoft))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.luna(.pregSoft)))
                    .accessibilityIdentifier("pregnancyEstimatedDue")
            }
            .frame(maxWidth: .infinity)
            .lunaCard()
            .padding(.top, 14)
            Text(L10n.imPregnantKeepsData)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
                .padding(.top, 10)
            Button(L10n.imPregnantConfirm) {
                cycle.switchToPregnant(source: source, date: date)
                dismiss()
            }
            .buttonStyle(.pill(.filled(.pregStrong)))
            .padding(.top, 18)
            .accessibilityIdentifier("imPregnantSave")
            Button(L10n.commonNotNow) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .accessibilityIdentifier("imPregnantCancel")
        }
        .lunaSheetPresentation()
        .onChange(of: source) { _, newSource in
            date = PregnancyDateInput.convert(date, to: newSource, now: now)
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                DatePicker(
                    source == .dueDate ? L10n.pregnancyDateSourceDueDate : L10n.pregnancyDateLMPLabel,
                    selection: $date,
                    in: PregnancyDateInput.range(for: source, now: now),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.luna(.pregText))
                .padding(.horizontal)
                .accessibilityIdentifier("imPregnantPicker")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.completionDone) { showingPicker = false }
                    }
                }
            }
            .lunaSheetPresentation(detents: [.medium, .large])
        }
    }

    private func shift(by days: Int) {
        let shifted = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        date = PregnancyDateInput.clamp(shifted, for: source, now: now)
    }

    private func stepButton(_ symbol: String, label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 40, height: 40)
                .background(Circle().fill(.luna(.surface)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
