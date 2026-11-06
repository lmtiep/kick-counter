import Accessibility
import KickCore
import SwiftUI

/// What the timer screen and the episode detail can present (edit spec 2026-11-06).
enum ContractionSheet: Identifiable {
    case edit(ContractionRecord)
    case addMissed
    case waterBroke
    case editMarker(LabourMarkerRecord)

    var id: String {
        switch self {
        case .edit(let record): "edit-\(record.id)"
        case .addMissed: "addMissed"
        case .waterBroke: "waterBroke"
        case .editMarker(let marker): "marker-\(marker.id)"
        }
    }
}

extension View {
    func contractionSheets(_ sheet: Binding<ContractionSheet?>) -> some View {
        self.sheet(item: sheet) { item in
            switch item {
            case .edit(let record): ContractionEditSheet(mode: .edit(record))
            case .addMissed: ContractionEditSheet(mode: .addMissed)
            case .waterBroke: LabourMarkerSheet(marker: nil)
            case .editMarker(let marker): LabourMarkerSheet(marker: marker)
            }
        }
    }
}

/// A row of a sheet: its label and a minute-resolution date and time picker.
/// A changed minute keeps the seconds the time had, so a 45 s contraction can
/// be moved without becoming a whole number of minutes.
private struct TimePickerRow: View {
    let title: String
    @Binding var time: Date
    let identifier: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let binding = Binding(
            get: { time },
            set: { time = ContractionEditRules.keepingSeconds(of: time, in: $0, calendar: AppLocale.calendar) }
        )
        VStack(alignment: .leading, spacing: 8) {
            if typeSize.isAccessibilitySize {
                // The system pills do not wrap: the date and the time on their own
                // lines, at a size that fits a phone's width.
                label
                HStack(spacing: 8) {
                    picker(binding, .date)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    picker(binding, .hourAndMinute)
                    Spacer(minLength: 0)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        label.lineLimit(1)
                        Spacer(minLength: 8)
                        picker(binding, [.date, .hourAndMinute])
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        label
                        picker(binding, [.date, .hourAndMinute])
                    }
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private func picker(_ binding: Binding<Date>, _ components: DatePickerComponents) -> some View {
        DatePicker(title, selection: binding, in: ...Date(), displayedComponents: components)
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(.luna(.pregText))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var label: some View {
        Text(title)
            .font(.luna(.bodyStrong))
            .foregroundStyle(.luna(.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Sửa cơn gò" and "Thêm cơn gò bị sót": the start, the length (5 s steps)
/// and, when editing, the end. The live-timing rules show inline and Save stays
/// off until the times are valid.
struct ContractionEditSheet: View {
    enum Mode {
        case edit(ContractionRecord)
        case addMissed
    }

    let mode: Mode
    @Environment(ContractionCoordinator.self) private var contractions
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date
    @State private var saveError: String?
    @State private var saving = false
    @Environment(\.dynamicTypeSize) private var typeSize

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .edit(let record):
            _start = State(initialValue: record.startedAt)
            _end = State(initialValue: record.endedAt ?? record.startedAt.addingTimeInterval(60))
        case .addMissed:
            // A minute ago, a minute long: it ended just now.
            let now = Date()
            _start = State(initialValue: now.addingTimeInterval(-60))
            _end = State(initialValue: now)
        }
    }

    private var editingID: UUID? {
        if case .edit(let record) = mode { record.id } else { nil }
    }

    private var isAdding: Bool { editingID == nil }

    private var duration: Binding<Int> {
        Binding(
            get: { Int(end.timeIntervalSince(start).rounded()) },
            set: { end = start.addingTimeInterval(TimeInterval($0)) }
        )
    }

    private var error: ContractionEditError? {
        ContractionEditRules.validate(
            id: editingID, start: start, end: end, existing: contractions.contractions, now: Date()
        )
    }

    var body: some View {
        LunaSheet(title: isAdding ? L10n.contractionAddTitle : L10n.contractionEditTitle, titleIdentifier: "contractionEditTitle") {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    TimePickerRow(title: L10n.contractionEditStart, time: $start, identifier: "contractionEditStart")
                    LunaDivider()
                    if !isAdding {
                        TimePickerRow(title: L10n.contractionEditEnd, time: $end, identifier: "contractionEditEnd")
                        LunaDivider()
                    }
                    Stepper(value: duration, in: 0...900, step: 5) {
                        if typeSize.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 2) {
                                durationLabel
                                durationValue
                            }
                        } else {
                            HStack(spacing: 8) {
                                durationLabel.lineLimit(1)
                                Spacer(minLength: 8)
                                durationValue
                            }
                        }
                    }
                    .accessibilityLabel(L10n.contractionEditDuration)
                    .accessibilityValue(ContractionClock.text(TimeInterval(duration.wrappedValue)))
                    .accessibilityIdentifier("contractionEditDuration")
                }
                .lunaCard(padding: 14)
                .padding(.top, 16)

                if let message {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.warningText))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("contractionEditError")
                }

                Button(L10n.commonSave) { Task { await save() } }
                    .buttonStyle(.pill(.filled(.pregStrong)))
                    .disabled(error != nil || saving)
                    .padding(.top, 20)
                    .accessibilityIdentifier("contractionEditSave")
                Button(L10n.commonCancel) { dismiss() }
                    .buttonStyle(.pill(.text(.textSecondary), height: 44))
                    .accessibilityIdentifier("contractionEditCancel")
            }
        }
        .lunaSheetPresentation()
        .onChange(of: error) { _, new in
            if let new { AccessibilityNotification.Announcement(L10n.contractionEditMessage(new)).post() }
        }
        .onChange(of: start) { saveError = nil }
        .onChange(of: end) { saveError = nil }
    }

    private var durationLabel: some View {
        Text(L10n.contractionEditDuration)
            .font(.luna(.bodyStrong))
            .foregroundStyle(.luna(.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var durationValue: some View {
        Text(ContractionClock.text(TimeInterval(duration.wrappedValue)))
            .font(.luna(.bodyStrong))
            .monospacedDigit()
            .foregroundStyle(.luna(.pregText))
    }

    private var message: String? {
        if let error { return L10n.contractionEditMessage(error) }
        return saveError
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let outcome: ContractionEditOutcome
        switch mode {
        case .edit(let record):
            outcome = await contractions.update(id: record.id, start: start, end: end)
        case .addMissed:
            outcome = await contractions.addMissed(start: start, duration: end.timeIntervalSince(start))
        }
        switch outcome {
        case .saved:
            dismiss()
        case .invalid(let error):
            saveError = L10n.contractionEditMessage(error)
        case .failed:
            // Shown here, not in the screen's alert.
            contractions.clearFailure()
            saveError = L10n.errorSave
        }
    }
}

/// "Vỡ ối": when the water broke, pre-filled with now. Opens empty to add a
/// marker, or with `marker` to edit its time.
struct LabourMarkerSheet: View {
    let marker: LabourMarkerRecord?
    @Environment(ContractionCoordinator.self) private var contractions
    @Environment(\.dismiss) private var dismiss
    @State private var time: Date
    @State private var saveError: String?
    @State private var saving = false

    init(marker: LabourMarkerRecord?) {
        self.marker = marker
        _time = State(initialValue: marker?.at ?? Date())
    }

    private var error: ContractionEditError? {
        ContractionEditRules.validateMarker(at: time, now: Date())
    }

    var body: some View {
        LunaSheet(title: L10n.contractionWaterBrokeButton, titleIdentifier: "contractionWaterBrokeTitle") {
            VStack(alignment: .leading, spacing: 0) {
                TimePickerRow(title: L10n.contractionWaterBrokeWhen, time: $time, identifier: "contractionWaterBrokeTime")
                    .lunaCard(padding: 14)
                    .padding(.top, 16)

                if let message = error.map(L10n.contractionEditMessage) ?? saveError {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.warningText))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("contractionWaterBrokeError")
                }

                Button(L10n.commonSave) { Task { await save() } }
                    .buttonStyle(.pill(.filled(.pregStrong)))
                    .disabled(error != nil || saving)
                    .padding(.top, 20)
                    .accessibilityIdentifier("contractionWaterBrokeSave")
                Button(L10n.commonCancel) { dismiss() }
                    .buttonStyle(.pill(.text(.textSecondary), height: 44))
                    .accessibilityIdentifier("contractionWaterBrokeCancel")
            }
        }
        .lunaSheetPresentation(detents: [.medium, .large])
        .onChange(of: time) { saveError = nil }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let outcome: ContractionEditOutcome
        if let marker {
            outcome = await contractions.updateMarker(id: marker.id, at: time)
        } else {
            outcome = await contractions.markWaterBroke(at: time)
        }
        switch outcome {
        case .saved:
            dismiss()
        case .invalid(let error):
            saveError = L10n.contractionEditMessage(error)
        case .failed:
            contractions.clearFailure()
            saveError = L10n.errorSave
        }
    }
}

/// After "Vỡ ối" is saved: the existing, doctor-reviewed safety line as an
/// emphasised card, with the emergency call button of the alert cards. It
/// replaces the plain safety card while a marker is current.
struct WaterBrokeCard: View {
    let at: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.luna(.warningButton))
                        .accessibilityHidden(true)
                    Text(L10n.contractionWaterBrokeAt(Formatting.time(at)))
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.warningText))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(L10n.contractionSafety)
                    .font(.luna(.bodyStrong))
                    .lineSpacing(3)
                    .foregroundStyle(.luna(.warningText))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("contractionWaterBrokeCard")
            EmergencyCallButton(identifier: "contractionWaterBrokeCall")
        }
        .lunaCard(.warningBackground, border: .warningBorder, padding: 16)
    }
}
