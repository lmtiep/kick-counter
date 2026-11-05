import KickCore
import KickData
import SwiftData
import SwiftUI

/// "Ghi câu hỏi cho bác sĩ" on pregnancy Today: a question goes to the next upcoming
/// appointment, or stays unassigned until one is added (`QuestionRouting`).
struct QuickQuestionCard: View {
    /// Called with the confirmation to show once a question is saved.
    let onSaved: (String) -> Void
    @State private var writing = false

    var body: some View {
        Button { writing = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.luna(.pregOnSoft))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.luna(.pregSoft)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.questionsQuickCard)
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                        .multilineTextAlignment(.leading)
                    Text(L10n.questionsQuickSubtitle)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "plus")
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
            .lunaCard(padding: 16)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quickQuestionCard")
        .sheet(isPresented: $writing) {
            QuickQuestionSheet(onSaved: onSaved)
                .lunaSheetPresentation(detents: [.medium, .large])
        }
    }
}

private struct QuickQuestionSheet: View {
    let onSaved: (String) -> Void
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var saveFailed = false
    @FocusState private var focused: Bool

    private var canSave: Bool { ChecklistText.clean(text) != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.questionsQuickField, text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focused)
                        .accessibilityIdentifier("quickQuestionField")
                }
            }
            .scrollContentBackground(.hidden)
            .lunaBackground()
            .tint(.luna(.pregText))
            .navigationTitle(L10n.questionsQuickCard)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.commonCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.commonSave, action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("quickQuestionSave")
                }
            }
            .checklistSaveAlert($saveFailed)
            .onAppear { focused = true }
        }
    }

    private func save() {
        guard canSave else { return }
        let targetID = QuestionRouting.target(among: appointments.upcoming, now: AppClock.now())
        let target = appointments.upcoming.first { $0.id == targetID }
        do {
            try ChecklistStore(context: modelContext).addQuestion(text, appointmentID: target?.id)
        } catch {
            saveFailed = true
            return
        }
        onSaved(target.map { L10n.questionsQuickAddedTo(Formatting.dayShortMonth($0.date)) } ?? L10n.questionsQuickAddedLoose)
        dismiss()
    }
}
