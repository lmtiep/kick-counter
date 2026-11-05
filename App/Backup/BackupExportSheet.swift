import KickCore
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "backup")

/// "Sao lưu ra file" (1.1 spec "Export"): first "Bảo vệ file bằng mật khẩu", on by
/// default, then the share sheet. The password lives only in this sheet's state:
/// it is cleared as soon as the file is made and whenever the sheet closes, and it
/// is never stored or logged. "Last backup" is recorded only after a completed share.
struct BackupExportSheet: View {
    /// Called after the share sheet closed; `completed` when the file was shared.
    var onFinished: (_ completed: Bool) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var protect = true
    @State private var password = ""
    @State private var confirmation = ""
    @State private var revealed = false
    @State private var working = false
    @State private var failed = false

    private var tooShort: Bool { !password.isEmpty && !BackupEncryption.isAcceptable(password: password) }
    private var mismatch: Bool { !confirmation.isEmpty && confirmation != password }
    private var canCreate: Bool {
        !working && (!protect || (BackupEncryption.isAcceptable(password: password) && password == confirmation))
    }

    var body: some View {
        LunaSheet(title: L10n.backupExport, titleIdentifier: "backupExportTitle") {
            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: $protect) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.backupProtectTitle)
                            .font(.luna(.cardTitleSmall))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.backupProtectDetail)
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(.luna(.cycleStrong))
                .padding(16)
                .accessibilityIdentifier("backupProtectToggle")
                if protect {
                    LunaDivider()
                    VStack(alignment: .leading, spacing: 12) {
                        BackupPasswordField(
                            title: L10n.backupProtectPassword, text: $password, revealed: $revealed,
                            identifier: "backupPassword"
                        )
                        if tooShort {
                            BackupInlineMessage(text: L10n.backupProtectTooShort, identifier: "backupPasswordTooShort")
                        }
                        BackupPasswordField(
                            title: L10n.backupProtectConfirm, text: $confirmation, revealed: $revealed,
                            identifier: "backupPasswordConfirm",
                            onSubmit: { if canCreate { Task { await create() } } }
                        )
                        if mismatch {
                            BackupInlineMessage(text: L10n.backupProtectMismatch, identifier: "backupPasswordMismatch")
                        }
                    }
                    .padding(16)
                }
            }
            .lunaCard(padding: 0)
            .padding(.top, 16)

            if protect {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.warningText))
                        .accessibilityHidden(true)
                    Text(L10n.backupProtectWarning)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lunaCard(.warningBackground, border: .warningBorder)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("backupProtectWarning")
                .padding(.top, 12)
            } else {
                Text(L10n.backupProtectOff)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .accessibilityIdentifier("backupProtectOff")
            }

            Button {
                Task { await create() }
            } label: {
                HStack(spacing: 8) {
                    if working {
                        ProgressView().tint(Color.luna(.onAccent))
                    }
                    Text(L10n.backupExportCreate)
                }
            }
            .buttonStyle(.pill(.dark))
            .disabled(!canCreate)
            .padding(.top, 20)
            .accessibilityIdentifier("backupExportCreate")
            Button(L10n.commonCancel) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .disabled(working)
                .padding(.top, 4)
                .accessibilityIdentifier("backupExportCancel")
        }
        .interactiveDismissDisabled(working)
        .onChange(of: protect) { _, isOn in
            if !isOn { clearPassword() }
        }
        .onDisappear { clearPassword() }
        .alert(L10n.backupExportFailed, isPresented: $failed) {
            Button(L10n.commonOK) {}
        }
    }

    private func clearPassword() {
        password = ""
        confirmation = ""
        revealed = false
    }

    /// Writes the file (sealed when protected), clears the password, then opens the share sheet.
    private func create() async {
        guard canCreate else { return }
        working = true
        let secret = protect ? password : nil
        clearPassword()
        let url: URL
        do {
            url = try await BackupCenter.makeExportFile(container: modelContext.container, now: AppClock.now(), password: secret)
        } catch {
            // Never the password: only the error's description.
            logger.error("Creating the backup file failed: \(error.localizedDescription)")
            working = false
            failed = true
            return
        }
        BackupSharePresenter.present(url) { completed in
            working = false
            if completed {
                AppGroup.defaults.set(AppClock.now(), forKey: SettingsKey.lastBackupAt)
            }
            onFinished(completed)
            if completed { dismiss() }
        }
    }
}
