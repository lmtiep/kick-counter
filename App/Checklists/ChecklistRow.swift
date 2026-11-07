import KickCore
import SwiftUI

/// A tick box and its text, one tap to toggle (hospital bag and doctor questions, 1.1).
/// At least 44 pt tall; the text wraps at any Dynamic Type size.
struct ChecklistRow: View {
    let text: String
    let isDone: Bool
    let identifier: String
    let toggle: () -> Void
    @ScaledMetric(relativeTo: .body) private var boxSize: CGFloat = 22

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: boxSize))
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

/// A plain progress bar for a checklist (no trimester notches, unlike the pregnancy bar).
struct ChecklistProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.luna(.track))
                Capsule().fill(.luna(.preg)).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
