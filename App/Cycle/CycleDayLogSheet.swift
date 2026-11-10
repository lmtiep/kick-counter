import Accessibility
import KickCore
import StoreKit
import SwiftUI

/// Log or edit one day (phase 5 spec §3.1): start/end a period there, then
/// flow and spotting, mood and symptoms, sex and sex drive, the ovulation signs
/// (LH test, BBT, mucus), a pregnancy test and a note (1.2 spec §1). Period buttons apply at once; the rest is saved with "Save", which
/// stays above the keyboard. Pregnancy symptoms and values this build cannot
/// read are kept as they are.
struct CycleDayLogSheet: View {
    let day: Date
    private let existing: CycleLogRecord?

    @Environment(CycleCoordinator.self) private var cycle
    @Environment(KickCoordinator.self) private var kicks
    @Environment(ContractionCoordinator.self) private var contractions
    @Environment(\.requestReview) private var requestReview
    @Environment(\.dismiss) private var dismiss
    @State private var lh: LHResult?
    @State private var temperatureText: String
    @State private var mucus: CervicalMucus?
    @State private var note: String
    @State private var flow: MenstrualFlow?
    @State private var moods: Set<Mood>
    @State private var symptoms: Set<Symptom>
    @State private var spotting: Bool
    @State private var sex: SexLog?
    @State private var sexDrive: SexDrive?
    @State private var pregnancyTest: PregnancyTestResult?
    /// A positive test was just saved: offer pregnancy tracking before closing.
    @State private var offeringPregnancy = false
    @State private var showingImPregnant = false
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
        _flow = State(initialValue: existing?.flow)
        _moods = State(initialValue: Set(existing?.moods ?? []))
        _symptoms = State(initialValue: Set(existing?.symptoms(for: .tryingToConceive) ?? []))
        _spotting = State(initialValue: existing?.spotting ?? false)
        _sex = State(initialValue: existing?.sex)
        _sexDrive = State(initialValue: existing?.sexDrive)
        _pregnancyTest = State(initialValue: existing?.pregnancyTest)
    }

    /// The period covering this day, or an earlier one this day could end:
    /// the nearest period within `CycleRules.longPeriodDays` (closed or open,
    /// phase 13), or an open one left running longer.
    private var coveringPeriod: PeriodRecord? { cycle.period(on: day) }
    private var periodBefore: PeriodRecord? {
        if let nearest = CycleRules.extendablePeriod(before: day, in: cycle.periods, calendar: .current) { return nearest }
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

            LunaSheetSectionTitle(title: L10n.symptomFlowTitle)
            FlowChips(selection: $flow)
            FlowLayout {
                // Spotting is not a period day and never moves the forecast.
                SelectableChip(title: L10n.dayLogSpotting, isSelected: spotting) { spotting.toggle() }
                    .accessibilityIdentifier("dayLogSpotting")
            }
            .padding(.top, 8)

            LunaSheetSectionTitle(title: L10n.symptomMoodTitle)
            MoodChips(selection: $moods)

            LunaSheetSectionTitle(title: L10n.symptomTitle)
            SymptomChips(mode: .tryingToConceive, selection: $symptoms)

            LunaSheetSectionTitle(title: L10n.dayLogSex)
            SingleChoiceChips(selection: $sex, identifier: "dayLogSex", title: L10n.sex)

            LunaSheetSectionTitle(title: L10n.dayLogSexDrive)
            SingleChoiceChips(selection: $sexDrive, identifier: "dayLogSexDrive", title: L10n.sexDrive)

            Text(L10n.dayLogSignals)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .padding(.top, 26)
                .accessibilityAddTraits(.isHeader)

            // Phase 9: hidden while tracking unless Profile turns them on; a
            // stored LH result or temperature is kept as it is.
            if cycle.policy.showsLHAndBBT {
                fertilityTests
            }

            LunaSheetSectionTitle(title: L10n.dayLogMucus)
            FlowLayout {
                mucusChip(nil, title: L10n.dayLogMucusNone)
                ForEach(CervicalMucus.allCases, id: \.self) { value in
                    mucusChip(value, title: L10n.mucus(value))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dayLogMucusPicker")

            LunaSheetSectionTitle(title: L10n.dayLogPregnancyTest)
            SingleChoiceChips(selection: $pregnancyTest, identifier: "dayLogPregnancyTest", title: L10n.pregnancyTest)

            LunaSheetSectionTitle(title: L10n.dayLogNote)
            TextField(L10n.dayLogNote, text: $note, axis: .vertical)
                .lineLimit(2...5)
                .font(.luna(.body))
                .padding(14)
                .lunaGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .background(.luna(.backgroundBottom))
                .accessibilityIdentifier("dayLogSave")
        }
        .lunaSheetPresentation()
        .alert(failure.map(L10n.cycleFailure) ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.commonOK) {}
        }
        .alert(L10n.positiveTestTitle, isPresented: $offeringPregnancy) {
            Button(L10n.positiveTestSwitch) { showingImPregnant = true }
                .accessibilityIdentifier("positiveTestSwitch")
            Button(L10n.positiveTestLater, role: .cancel) { dismiss() }
                .accessibilityIdentifier("positiveTestLater")
        } message: {
            Text(L10n.positiveTestMessage)
        }
        // Offered, never switched by itself: her log is already saved.
        .sheet(isPresented: $showingImPregnant, onDismiss: { dismiss() }) {
            ImPregnantSheet(lastPeriodStart: cycle.forecast?.currentPeriodStart)
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

    /// The LH test and basal body temperature (trying to conceive, or
    /// tracking with Profile's override on).
    @ViewBuilder
    private var fertilityTests: some View {
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
                .lunaGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    // Open or closed: ending it here shortens it (phase 13).
                    if day > period.startDate, period.endDate.map({ day < Calendar.current.startOfDay(for: $0) }) ?? true {
                        endButton(for: period)
                    }
                    Button(L10n.dayLogPeriodDelete, role: .destructive) { confirmingDeletePeriod = true }
                        .buttonStyle(.pill(.text(.warningText), fullWidth: false, height: 40))
                        .disabled(saving)
                        .accessibilityIdentifier("dayLogDeletePeriod")
                }
            } else {
                // Ending the earlier period here (it lengthens) comes first, so
                // a day after an assumed end is not logged as a new period by mistake.
                if let earlier = periodBefore {
                    Button(L10n.dayLogPeriodEndHere) {
                        Task { await run { await cycle.endPeriod(id: earlier.id, on: day) } }
                    }
                    .buttonStyle(.pill(.soft(.cycleSoft, .cycleOnSoft), fullWidth: false, height: 40))
                    .disabled(saving)
                    .accessibilityIdentifier("dayLogExtendPeriod")
                }
                Button(L10n.dayLogPeriodStart) {
                    Task {
                        await run { await cycle.startPeriod(on: day) }
                        if failure == nil {
                            ReviewPrompter.moment(
                                .periodStarted(totalPeriods: cycle.periods.count),
                                kicks: kicks, contractions: contractions, requestReview: requestReview
                            )
                        }
                    }
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
        SelectableChip(title: title, isSelected: mucus == value) { mucus = value }
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
        // Start from what is stored: pregnancy symptoms and unknown values stay.
        var log = existing ?? CycleLogRecord(day: day)
        log.day = day
        log.lh = lh
        log.bbtCelsius = temperature
        log.mucus = mucus
        log.note = note
        log.flow = flow
        log.moods = RawList.ordered(moods)
        log.setSymptoms(symptoms, for: .tryingToConceive)
        log.spotting = spotting
        log.sex = sex
        log.sexDrive = sexDrive
        log.pregnancyTest = pregnancyTest
        saving = true
        defer { saving = false }
        if let result = await cycle.saveLog(log) {
            cycle.clearFailure()
            failure = result
        } else if pregnancyTest == .positive, existing?.pregnancyTest != .positive {
            offeringPregnancy = true
        } else {
            dismiss()
        }
    }
}
