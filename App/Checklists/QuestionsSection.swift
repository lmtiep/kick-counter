import KickCore
import KickData
import SwiftData
import SwiftUI

/// Which questions a `QuestionsSection` lists.
enum QuestionsListMode {
    /// One appointment's questions, with a field to add more (the editor of a saved appointment).
    case appointment(UUID)
    /// The unassigned questions a new appointment will adopt when saved (its editor).
    case pending
    /// The unassigned questions on the appointments list.
    case unassigned
}

/// Questions for the doctor as a Section of a Form or List: tick as asked, swipe to delete.
struct QuestionsSection: View {
    let mode: QuestionsListMode
    /// Set when a write fails; the screen that owns the section shows the alert.
    @Binding var saveFailed: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistItem.createdAt) private var items: [ChecklistItem]
    @State private var newQuestion = ""

    private var questions: [ChecklistItemRecord] {
        let records = items.map(\.record)
        if case .appointment(let id) = mode { return QuestionRouting.questions(for: id, in: records) }
        return QuestionRouting.unassigned(in: records)
    }

    private var appointmentID: UUID? {
        if case .appointment(let id) = mode { return id }
        return nil
    }

    private var title: String {
        if case .unassigned = mode { return L10n.questionsUnassignedTitle }
        return L10n.questionsTitle
    }

    private var rowBackground: Color? {
        if case .unassigned = mode { return Color.luna(.card) }
        return nil
    }

    var body: some View {
        let questions = questions
        if appointmentID != nil || !questions.isEmpty {
            Section {
                ForEach(questions) { question in
                    ChecklistRow(text: question.text, isDone: question.isDone, identifier: "questionRow") {
                        write { try $0.setDone(id: question.id, done: !question.isDone) }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { write { try $0.delete(id: question.id) } } label: {
                            Label(L10n.commonDelete, systemImage: "trash")
                        }
                    }
                    .listRowBackground(rowBackground)
                }
                if appointmentID != nil {
                    HStack {
                        TextField(L10n.questionsField, text: $newQuestion, axis: .vertical)
                            .submitLabel(.done)
                            .onSubmit(add)
                            .keyboardDoneButton()
                            .accessibilityIdentifier("questionField")
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.borderless)
                        .disabled(ChecklistText.clean(newQuestion) == nil)
                        .accessibilityLabel(L10n.questionsField)
                        .accessibilityIdentifier("questionAdd")
                    }
                }
            } header: {
                Text(title)
                    .modifier(ListHeaderStyle(isList: rowBackground != nil))
                    .accessibilityIdentifier("questionsHeader")
            } footer: {
                if case .pending = mode {
                    Text(L10n.questionsPendingHint)
                } else if case .unassigned = mode {
                    Text(L10n.questionsUnassignedFooter)
                } else if questions.isEmpty {
                    Text(L10n.questionsEmpty)
                } else {
                    let progress = QuestionRouting.progress(questions)
                    Text(L10n.questionsProgress(progress.done, progress.total))
                }
            }
        }
    }

    private func add() {
        guard let appointmentID, ChecklistText.clean(newQuestion) != nil else { return }
        write { try $0.addQuestion(newQuestion, appointmentID: appointmentID) }
        if !saveFailed { newQuestion = "" }
    }

    private func write(_ change: (ChecklistStore) throws -> Void) {
        do {
            try change(ChecklistStore(context: modelContext))
        } catch {
            saveFailed = true
        }
    }
}

/// On the appointments List the section headers are Luna caption text; inside the editor's
/// Form they stay the system's, like "Ghi chú" next to them.
private struct ListHeaderStyle: ViewModifier {
    let isList: Bool

    func body(content: Content) -> some View {
        if isList {
            content.font(.luna(.captionStrong)).foregroundStyle(.luna(.textSecondary))
        } else {
            content
        }
    }
}
