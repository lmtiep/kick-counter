import KickCore
import SwiftUI

enum AppointmentEditorMode: Identifiable {
    case new(date: Date, title: String, milestoneID: String?)
    case edit(AppointmentRecord)

    var id: String {
        switch self {
        case .new(_, _, let milestoneID): "new-\(milestoneID ?? "custom")"
        case .edit(let record): record.id.uuidString
        }
    }
}

struct AppointmentEditorSheet: View {
    let mode: AppointmentEditorMode

    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var title: String
    @State private var note: String
    @State private var saving = false
    @State private var saveFailed = false

    init(mode: AppointmentEditorMode) {
        self.mode = mode
        switch mode {
        case .new(let date, let title, _):
            _date = State(initialValue: date)
            _title = State(initialValue: title)
            _note = State(initialValue: "")
        case .edit(let record):
            _date = State(initialValue: record.date)
            _title = State(initialValue: record.title)
            _note = State(initialValue: record.note)
        }
    }

    private var editedRecord: AppointmentRecord? {
        if case .edit(let record) = mode { return record }
        return nil
    }

    private var canSave: Bool {
        !saving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.appointmentsFieldTitle, text: $title)
                        .accessibilityIdentifier("appointmentTitleField")
                    DatePicker(L10n.appointmentsFieldDate, selection: $date)
                        .accessibilityIdentifier("appointmentDatePicker")
                }
                Section(L10n.appointmentsFieldNote) {
                    TextField(L10n.appointmentsFieldNote, text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                if let record = editedRecord, !record.isDone {
                    Section {
                        Button(L10n.appointmentsMarkDone) {
                            Task {
                                await appointments.markDone(id: record.id)
                                dismiss()
                            }
                        }
                        .accessibilityIdentifier("appointmentMarkDoneButton")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .lunaBackground()
            .tint(.luna(.pregStrong))
            .navigationTitle(editedRecord == nil ? L10n.appointmentsAdd : L10n.appointmentsEdit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave) { Task { await save() } }
                        .disabled(!canSave)
                        .accessibilityIdentifier("appointmentSaveButton")
                }
            }
            .alert(L10n.errorSave, isPresented: $saveFailed) {
                Button(L10n.commonOK) {}
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let succeeded: Bool
        switch mode {
        case .new(_, _, let milestoneID):
            succeeded = await appointments.add(date: date, title: title, note: note, milestoneID: milestoneID) != nil
        case .edit(let record):
            var updated = record
            updated.date = date
            updated.title = title
            updated.note = note
            succeeded = await appointments.update(updated)
        }
        if succeeded {
            dismiss()
        } else {
            // Shown here rather than on the list, which is covered by this sheet.
            appointments.clearFailure()
            saveFailed = true
        }
    }
}
