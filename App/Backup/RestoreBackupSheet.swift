import KickCore
import KickData
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "restore")

/// "Khôi phục bản sao lưu" (phase 15 spec §4.2): what the file holds, a warning that
/// everything on this iPhone is replaced, then an all-or-nothing restore. A file
/// that cannot be read only shows why; nothing is touched.
struct RestoreBackupSheet: View {
    let request: BackupCenter.Request

    @Environment(BackupCenter.self) private var backup
    @Environment(KickCoordinator.self) private var kicks
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
    @Environment(PillCoordinator.self) private var pill
    @Environment(ContractionCoordinator.self) private var contractions
    @Environment(\.modelContext) private var modelContext
    @State private var working = false
    @State private var failed = false

    var body: some View {
        switch request.result {
        case .success(let file):
            LunaSheet(title: L10n.backupRestoreTitle, titleIdentifier: "restoreBackupTitle") {
                summaryCard(file.document.summary)
                    .padding(.top, 14)
                warningCard(skipped: file.skipped)
                    .padding(.top, 12)
                if failed {
                    Text(L10n.backupRestoreFailed)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.warningText))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                        .accessibilityIdentifier("restoreBackupFailed")
                }
                Button {
                    Task { await restore(file.document) }
                } label: {
                    HStack(spacing: 8) {
                        if working {
                            ProgressView().tint(Color.luna(.onAccent))
                        }
                        Text(L10n.backupRestoreConfirm)
                    }
                }
                .buttonStyle(.pill(.filled(.warningButton)))
                .disabled(working)
                .padding(.top, 20)
                .accessibilityIdentifier("restoreBackupConfirm")
                Button(L10n.commonCancel) { backup.request = nil }
                    .buttonStyle(.pill(.text(.textSecondary), height: 44))
                    .disabled(working)
                    .padding(.top, 4)
                    .accessibilityIdentifier("restoreBackupCancel")
            }
            .interactiveDismissDisabled(working)
        case .failure(let error):
            LunaSheet(title: L10n.backupErrorTitle, titleIdentifier: "restoreBackupTitle") {
                Label {
                    Text(L10n.backupError(error))
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.luna(.warningText))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lunaCard(.warningBackground, border: .warningBorder)
                .padding(.top, 14)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("restoreBackupError")
                Button(L10n.commonOK) { backup.request = nil }
                    .buttonStyle(.pill(.dark))
                    .padding(.top, 20)
                    .accessibilityIdentifier("restoreBackupClose")
            }
        }
    }

    private func summaryCard(_ summary: BackupSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.backupRestoreCreatedAt(Formatting.dayMonthYear(summary.createdAt)))
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
            Text(summary.isEmpty ? L10n.backupRestoreEmpty : L10n.backupCounts(summary))
                .font(.luna(.body))
                .foregroundStyle(.luna(.articleText))
            if let range = summary.dateRange {
                Text(L10n.backupRestoreRange(
                    Formatting.dayMonthYear(range.lowerBound), Formatting.dayMonthYear(range.upperBound)
                ))
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
            }
            Text(modeText(summary.mode))
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lunaCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("restoreBackupSummary")
    }

    private func modeText(_ mode: AppMode) -> String {
        switch mode {
        case .tryingToConceive: L10n.profileModeCycle
        case .pregnant: L10n.profileModePregnant
        case .partner: AppEnvironment.showsPartnerUI ? L10n.partnerModeName : L10n.backupRestorePartnerMode
        }
    }

    private func warningCard(skipped: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.luna(.body))
                .foregroundStyle(.luna(.warningText))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.backupRestoreWarning)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                if kicks.activeSessionID != nil {
                    Text(L10n.backupRestoreRunningSession)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textPrimary))
                }
                if skipped > 0 {
                    Text(L10n.backupRestoreSkipped(skipped))
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.articleText))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lunaCard(.warningBackground, border: .warningBorder)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("restoreBackupWarning")
    }

    /// Spec §4.2. The kick session, its Live Activity and every notification stop
    /// first, so nothing from the old data (a "+1" from the Lock Screen) lands in
    /// the restored store. Then the store, in one save that rolls back on failure:
    /// the old data is then reloaded as it was and nothing else is touched. Only
    /// after it succeeded: the preferences, the coordinators, Today and a toast.
    private func restore(_ document: BackupDocument) async {
        guard !working else { return }
        working = true
        failed = false
        defer { working = false }
        await AppDataReload.stopEverything(kicks: kicks, contractions: contractions)
        do {
            try BackupStore.replaceAll(in: modelContext.container, with: document.records)
        } catch {
            logger.error("Restoring a backup failed: \(error.localizedDescription)")
            await AppDataReload.reload(
                kicks: kicks, appointments: appointments, cycle: cycle, weight: weight, pill: pill, contractions: contractions
            )
            failed = true
            AccessibilityNotification.Announcement(L10n.backupRestoreFailed).post()
            return
        }
        BackupSettings.restore(document.settings, backupCreatedAt: document.createdAt, to: AppGroup.defaults)
        // Partner mode is hidden in 1.0 (phase 12): such a file goes through onboarding.
        if !AppEnvironment.showsPartnerUI, AppMode.hidePartnerMode(in: AppGroup.defaults) {
            logger.info("Restored partner mode hidden: onboarding again")
        }
        await AppDataReload.reload(
            kicks: kicks, appointments: appointments, cycle: cycle, weight: weight, pill: pill, contractions: contractions
        )
        BackupCenter.removeLeftovers()
        logger.info("Restored a backup")
        backup.didRestore()
    }
}
