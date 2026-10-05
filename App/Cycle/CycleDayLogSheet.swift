import Accessibility
import KickCore
import SwiftUI

/// Log or edit one day (spec §4.9): start/end a period there, LH test, BBT,
/// mucus, note. Period buttons apply at once; the signals are saved with "Save",
/// which stays above the keyboard.
struct CycleDayLogSheet: View {
    let day: Date
    private let existing: CycleLogRecord?

    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var lh: LHResult?
    @State private var temperatureText: String
    @State private var mucus: CervicalMucus?
    @State private var note: String
    @State private var temperatureInvalid = false
    @State private var failure: CycleFailure?
    @State private var saving = false
    @State private var confirmingDeletePeriod = false

    init(day: Date, existing: CycleLogRecord?) {
        self.day = Calendar.current.startOfDay(for: day)
        self.existing = existing
        _lh = State(initialValue: existing?.lh)
        _temperatureText = State(initialValue: existing?.bbtCelsius.map {
            $0.formatted(.number.precision(.fractionLength(1...2)).grouping(.never).locale(Formatting.locale))
        } ?? "")
        _mucus = State(initialValue: existing?.mucus)
        _note = State(initialValue: existing?.note ?? "")
    }

    /// The period covering this day, or an earlier one still open that this day could end.
    private var coveringPeriod: PeriodRecord? { cycle.period(on: day) }
    private var openPeriodBefore: PeriodRecord? {
        guard let open = cycle.forecast?.openPeriod, open.startDate < day else { return nil }
        return open
    }

    private var title: String {
        Calendar.current.isDate(day, inSameDayAs: AppClock.now())
            ? L10n.dayLogTitleToday(Formatting.shortDay(day))
            : Formatting.weekdayDay(day)
    }

    var body: some View {
        LunaSheet(title: title) {
            LunaSheetSectionTitle(title: L10n.dayLogPeriodSection)
            periodSection

            LunaSheetSectionTitle(title: L10n.dayLogLH)
            Picker(L10n.dayLogLH, selection: $lh) {
                Text(L10n.dayLogLHNone).tag(LHResult?.none)
                Text(L10n.dayLogLHNegative).tag(LHResult?.some(.negative))
                Text(L10n.dayLogLHPositive).tag(LHResult?.some(.positive))
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("dayLogLHPicker")

            LunaSheetSectionTitle(title: L10n.dayLogBBT)
            VStack(alignment: .leading, spacing: 6) {
                TextField(L10n.dayLogBBTPlaceholder, text: $temperatureText)
                    .keyboardType(.decimalPad)
                    .font(.luna(.body))
                    .padding(14)
                    .background(.luna(.card), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(L10n.dayLogBBT)
                    .accessibilityIdentifier("dayLogBBTField")
                    .onChange(of: temperatureText) { temperatureInvalid = false }
                if temperatureInvalid {
                    Label(L10n.cycleFailure(.invalidTemperature), systemImage: "exclamationmark.triangle.fill")
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.warningText))
                        .accessibilityIdentifier("dayLogBBTError")
                }
                Text(L10n.dayLogBBTHint)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
            }

            LunaSheetSectionTitle(title: L10n.dayLogMucus)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                mucusChip(nil, title: L10n.dayLogMucusNone)
                ForEach(CervicalMucus.allCases, id: \.self) { value in
                    mucusChip(value, title: L10n.mucus(value))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dayLogMucusPicker")

            LunaSheetSectionTitle(title: L10n.dayLogNote)
            TextField(L10n.dayLogNote, text: $note, axis: .vertical)
                .lineLimit(2...5)
                .font(.luna(.body))
                .padding(14)
                .background(.luna(.card), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityIdentifier("dayLogNoteField")

            Button(L10n.commonCancel) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .padding(.top, 12)
                .accessibilityIdentifier("dayLogCancel")
        }
        .safeAreaInset(edge: .bottom) {
            Button(L10n.commonSave) { Task { await save() } }
                .buttonStyle(.pill(.dark))
                .disabled(saving)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(.luna(.background))
                .accessibilityIdentifier("dayLogSave")
        }
        .lunaSheetPresentation()
        .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
        .confirmationDialog(L10n.dayLogPeriodDeleteConfirm, isPresented: $confirmingDeletePeriod, titleVisibility: .visible) {
            Button(L10n.commonDelete, role: .destructive) {
                if let period = coveringPeriod {
                    Task { await run { await cycle.deletePeriod(id: period.id) } }
                }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }

    @ViewBuilder
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let period = coveringPeriod {
                Text(description(of: period, formatting: Formatting.shortDay))
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.cycleOnSoft))
                    .accessibilityLabel(description(of: period, formatting: Formatting.spokenDay))
                    .accessibilityIdentifier("dayLogPeriodInfo")
                HStack(spacing: 8) {
                    if period.isOpen, day > period.startDate {
                        endButton(for: period)
                    }
                    Button(L10n.dayLogPeriodDelete, role: .destructive) { confirmingDeletePeriod = true }
                        .buttonStyle(.pill(.text(.warningText), fullWidth: false, height: 40))
                        .disabled(saving)
                        .accessibilityIdentifier("dayLogDeletePeriod")
                }
            } else {
                if let open = openPeriodBefore {
                    endButton(for: open)
                }
                Button(L10n.dayLogPeriodStart) {
                    Task { await run { await cycle.startPeriod(on: day) } }
                }
                .buttonStyle(.pill(.soft(.cycleSoft, .cycleOnSoft), fullWidth: false, height: 40))
                .disabled(saving)
                .accessibilityIdentifier("dayLogStartPeriod")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lunaCard(padding: 14)
    }

    private func endButton(for period: PeriodRecord) -> some View {
        Button(L10n.dayLogPeriodEnd) {
            Task { await run { await cycle.endPeriod(id: period.id, on: day) } }
        }
        .buttonStyle(.pill(.soft(.cycleSoft, .cycleOnSoft), fullWidth: false, height: 40))
        .disabled(saving)
        .accessibilityIdentifier("dayLogEndPeriod")
    }

    private func mucusChip(_ value: CervicalMucus?, title: String) -> some View {
        let isSelected = mucus == value
        return Button {
            mucus = value
        } label: {
            Text(title)
                .font(.luna(.body))
                .foregroundStyle(.luna(isSelected ? .onAccent : .textPrimary))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(isSelected ? Color.luna(.cycleStrong) : Color.luna(.card)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func description(of period: PeriodRecord, formatting format: (Date) -> String) -> String {
        let start = format(period.startDate)
        guard let end = period.endDate else { return L10n.dayLogPeriodSince(start) }
        return L10n.dayLogPeriodRange(start, format(end))
    }

    private func run(_ action: () async -> CycleFailure?) async {
        saving = true
        defer { saving = false }
        if let result = await action() {
            cycle.clearFailure()
            failure = result
        }
    }

    private func save() async {
        let temperature: Double?
        switch TemperatureEntry(text: temperatureText) {
        case .empty: temperature = nil
        case .valid(let value): temperature = value
        case .invalid:
            temperatureInvalid = true
            AccessibilityNotification.Announcement(L10n.cycleFailure(.invalidTemperature)).post()
            return
        }
        let log = CycleLogRecord(
            id: existing?.id ?? UUID(), day: day, lh: lh, bbtCelsius: temperature, mucus: mucus, note: note
        )
        saving = true
        defer { saving = false }
        if let result = await cycle.saveLog(log) {
            cycle.clearFailure()
            failure = result
        } else {
            dismiss()
        }
    }
}
