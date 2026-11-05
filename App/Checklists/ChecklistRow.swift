import KickCore
import SwiftUI

/// A tick box and its text, one tap to toggle (hospital bag and doctor questions, 1.1).
/// At least 44 pt tall; the text wraps at any Dynamic Type size.
struct ChecklistRow: View {
    let text: String
    let isDone: Bool
    let identifier: String
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.luna(isDone ? .pregStrong : .chevron))
                    .accessibilityHidden(true)
                Text(text)
                    .font(.luna(.body))
                    .foregroundStyle(Color.luna(isDone ? .textSecondary : .textPrimary))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? L10n.checklistDone : L10n.checklistNotDone)
        .accessibilityIdentifier(identifier)
    }
}

extension View {
    /// "Couldn't save" after a failed checklist write.
    func checklistSaveAlert(_ isPresented: Binding<Bool>) -> some View {
        alert(L10n.errorSave, isPresented: isPresented) {
            Button(L10n.commonOK) {}
        }
    }
}
