import KickCore
import SwiftUI

/// Shown when 10 movements are reached (phase 1 content, new style).
struct CompletionView: View {
    let session: SessionState
    let onDone: () -> Void

    var body: some View {
        LunaSheet(title: L10n.completionTitle, titleIdentifier: "completionTitle") {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.luna(.tealStrong))
                    .accessibilityHidden(true)
                if let duration = session.duration {
                    Text(L10n.completionDuration(Formatting.duration(duration)))
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                }
                if session.exceededThreshold {
                    Text(L10n.completionExceeded)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.warningText))
                        .fixedSize(horizontal: false, vertical: true)
                        .lunaCard(.warningBackground, border: .warningBorder, padding: 16)
                }
                Button(L10n.completionDone, action: onDone)
                    .buttonStyle(.pill(.dark))
                    .accessibilityIdentifier("completionDone")
            }
            .padding(.top, 16)
        }
    }
}
