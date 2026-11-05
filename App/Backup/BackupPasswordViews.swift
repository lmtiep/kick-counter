import KickCore
import SwiftUI

/// A password field with show/hide (1.1 spec "Export"). Never autocorrected or
/// capitalised, so the keyboard does not learn it; marked privacy-sensitive.
struct BackupPasswordField: View {
    let title: String
    @Binding var text: String
    @Binding var revealed: Bool
    let identifier: String
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.luna(.captionStrong))
                .foregroundStyle(.luna(.textSecondary))
                .accessibilityHidden(true)
            HStack(spacing: 4) {
                Group {
                    if revealed {
                        TextField(title, text: $text)
                    } else {
                        SecureField(title, text: $text)
                    }
                }
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .privacySensitive()
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
                .padding(.leading, 14)
                .padding(.vertical, 14)
                Button { revealed.toggle() } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textSecondary))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealed ? L10n.backupProtectHide : L10n.backupProtectShow)
                .accessibilityIdentifier("\(identifier)Reveal")
                .padding(.trailing, 4)
            }
            .background(.luna(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/// A short warning line under a field or a button.
struct BackupInlineMessage: View {
    let text: String
    let identifier: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.luna(.caption))
            .foregroundStyle(.luna(.warningText))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
    }
}

/// The restore sheet for a password-protected file (1.1 spec "Restore"): the
/// password, then the usual summary and "replace everything" step. A wrong
/// password changes nothing; she can try again or cancel.
struct UnlockBackupView: View {
    let data: Data

    @Environment(BackupCenter.self) private var backup
    @State private var password = ""
    @State private var revealed = false
    @State private var working = false
    @State private var wrongPassword = false
    @FocusState private var focused: Bool

    var body: some View {
        LunaSheet(title: L10n.backupUnlockTitle, titleIdentifier: "restoreBackupTitle") {
            Text(L10n.backupUnlockBody)
                .font(.luna(.body))
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            BackupPasswordField(
                title: L10n.backupProtectPassword,
                text: $password,
                revealed: $revealed,
                identifier: "restoreBackupPassword",
                onSubmit: { Task { await unlock() } }
            )
            .focused($focused)
            .padding(.top, 16)
            if wrongPassword {
                BackupInlineMessage(text: L10n.backupUnlockWrong, identifier: "restoreBackupWrongPassword")
                    .padding(.top, 10)
            }
            Button {
                Task { await unlock() }
            } label: {
                HStack(spacing: 8) {
                    if working {
                        ProgressView().tint(Color.luna(.onAccent))
                    }
                    Text(L10n.backupUnlockOpen)
                }
            }
            .buttonStyle(.pill(.dark))
            .disabled(password.isEmpty || working)
            .padding(.top, 20)
            .accessibilityIdentifier("restoreBackupUnlock")
            Button(L10n.commonCancel) {
                password = ""
                backup.request = nil
            }
            .buttonStyle(.pill(.text(.textSecondary), height: 44))
            .disabled(working)
            .padding(.top, 4)
            .accessibilityIdentifier("restoreBackupCancel")
        }
        .interactiveDismissDisabled(working)
        .onAppear { focused = true }
        .onDisappear { password = "" }
    }

    private func unlock() async {
        guard !password.isEmpty, !working else { return }
        working = true
        wrongPassword = false
        let result = await backup.unlock(data, password: password)
        working = false
        switch result {
        case .opened:
            password = ""
        case .wrongPassword:
            // A secure field clears itself on the next keystroke anyway: start empty.
            password = ""
            wrongPassword = true
            focused = true
            AccessibilityNotification.Announcement(L10n.backupUnlockWrong).post()
        }
    }
}
