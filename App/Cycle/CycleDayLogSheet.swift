import Accessibility
import KickCore
import SwiftUI

/// Log or edit one day: start/end a period there, LH test, BBT, mucus, note.
/// Period buttons apply at once; the signals are saved with "Save".
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
            $0.formatted(.number.precision(.fractionLength(1...2)).grouping(.never))
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

    var body: some View {
        NavigationStack {
            Form {
                periodSection

                Section(L10n.dayLogLH) {
                    Picker(L10n.dayLogLH, selection: $lh) {
                        Text(L10n.dayLogLHNone).tag(LHResult?.none)
                        Text(L10n.dayLogLHNegative).tag(LHResult?.some(.negative))
                        Text(L10n.dayLogLHPositive).tag(LHResult?.some(.positive))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("dayLogLHPicker")
                }

                Section {
                    TextField(L10n.dayLogBBTPlaceholder, text: $temperatureText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(L10n.dayLogBBT)
                        .accessibilityIdentifier("dayLogBBTField")
                        .onChange(of: temperatureText) { temperatureInvalid = false }
                    if temperatureInvalid {
                        Label(L10n.cycleFailure(.invalidTemperature), systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("dayLogBBTError")
                    }
                } header: {
                    Text(L10n.dayLogBBT)
                } footer: {
                    Text(L10n.dayLogBBTHint)
                }

                Section(L10n.dayLogMucus) {
                    Picker(L10n.dayLogMucus, selection: $mucus) {
                        Text(L10n.dayLogMucusNone).tag(CervicalMucus?.none)
                        ForEach(CervicalMucus.allCases, id: \.self) { value in
                            Text(L10n.mucus(value)).tag(CervicalMucus?.some(value))
                        }
                    }
                    .accessibilityIdentifier("dayLogMucusPicker")
                }

                Section(L10n.dayLogNote) {
                    TextField(L10n.dayLogNote, text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("dayLogNoteField")
                }
            }
            .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) { Task { await save() } }
                        .disabled(saving)
                        .accessibilityIdentifier("dayLogSave")
                }
            }
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
    }

    @ViewBuilder
    private var periodSection: some View {
        Section(L10n.dayLogPeriodSection) {
            if let period = coveringPeriod {
                Text(description(of: period, formatting: Formatting.cycleDate))
                    .accessibilityLabel(description(of: period, formatting: Formatting.spokenDay))
                    .accessibilityIdentifier("dayLogPeriodInfo")
                if period.isOpen, day > period.startDate {
                    endButton(for: period)
                }
                Button(L10n.dayLogPeriodDelete, role: .destructive) { confirmingDeletePeriod = true }
                    .accessibilityIdentifier("dayLogDeletePeriod")
            } else {
                if let open = openPeriodBefore {
                    endButton(for: open)
                }
                Button(L10n.dayLogPeriodStart) {
                    Task { await run { await cycle.startPeriod(on: day) } }
                }
                .disabled(saving)
                .accessibilityIdentifier("dayLogStartPeriod")
            }
        }
    }

    private func endButton(for period: PeriodRecord) -> some View {
        Button(L10n.dayLogPeriodEnd) {
            Task { await run { await cycle.endPeriod(id: period.id, on: day) } }
        }
        .disabled(saving)
        .accessibilityIdentifier("dayLogEndPeriod")
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
