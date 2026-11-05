import KickCore
import SwiftUI

/// Profile's "Dữ liệu" section (phase 15 spec §4.1, 1.1 spec): the backup reminder
/// card on top when it is due, then back up to a file (password step first),
/// "Chuyển sang iPhone mới" and restore from a file.
struct BackupDataSection: View {
    /// `SettingsKey.lastBackupAt`, as Profile last read it.
    let lastBackupAt: Date?
    /// Profile reads `lastBackupAt` again.
    let onBackupChanged: () -> Void
    /// Opens Profile's file importer.
    let onImport: () -> Void

    @State private var exporting = false
    @State private var showsReminder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsReminder {
                BackupReminderCard(lastBackupAt: lastBackupAt) {
                    exporting = true
                } later: {
                    BackupReminderStore.snooze(in: AppGroup.defaults, now: AppClock.now())
                    withAnimation { refreshReminder() }
                }
                .transition(.opacity)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.backupSection)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 2)
                Button { exporting = true } label: {
                    BackupDataRow(
                        title: L10n.backupExport,
                        systemImage: "square.and.arrow.up",
                        detail: lastBackupAt.map { L10n.backupLastBackup(Formatting.shortDay($0)) }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profileBackupExport")
                Text(L10n.backupExportFootnote)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .accessibilityIdentifier("profileBackupFootnote")
                LunaDivider()
                NavigationLink {
                    MoveToNewPhoneView(onBackupChanged: onBackupChanged)
                } label: {
                    BackupDataRow(title: L10n.backupMoveRow, systemImage: "iphone.gen3", detail: nil)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profileBackupMove")
                LunaDivider()
                Button(action: onImport) {
                    BackupDataRow(title: L10n.backupImport, systemImage: "arrow.down.doc", detail: nil)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profileBackupImport")
            }
            // No identifier on the card: it would replace the rows' own identifiers.
            .lunaCard(padding: 0)
        }
        .sheet(isPresented: $exporting) {
            BackupExportSheet { _ in
                onBackupChanged()
                refreshReminder()
            }
            .lunaSheetPresentation(detents: [.large])
        }
        .onAppear { refreshReminder() }
        .onChange(of: lastBackupAt) { refreshReminder() }
    }

    private func refreshReminder() {
        showsReminder = BackupReminderPolicy.shouldShow(
            BackupReminderStore.load(from: AppGroup.defaults), now: AppClock.now(), calendar: AppLocale.calendar
        )
    }
}

/// "Đã lâu chưa sao lưu" (1.1 spec "Reminder"): in the app only, never a notification.
struct BackupReminderCard: View {
    let lastBackupAt: Date?
    let backUp: () -> Void
    let later: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.backupReminderTitle)
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(lastBackupAt.map { L10n.backupReminderLast(Formatting.shortDay($0)) } ?? L10n.backupReminderNever)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.articleText))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("backupReminderText")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(spacing: 4) { buttons }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // No identifier on the card: it would replace the buttons' own identifiers.
        .lunaCard()
    }

    @ViewBuilder private var buttons: some View {
        Button(L10n.backupNow, action: backUp)
            .buttonStyle(.pill(.dark, height: 44))
            .accessibilityIdentifier("backupReminderNow")
        Button(L10n.commonNotNow, action: later)
            .buttonStyle(.pill(.text(.textSecondary), height: 44))
            .accessibilityIdentifier("backupReminderLater")
    }
}

/// One row of the "Dữ liệu" card.
struct BackupDataRow: View {
    let title: String
    let systemImage: String
    let detail: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                if let detail {
                    Text(detail)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.luna(.chevron))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// "Chuyển sang iPhone mới" (1.1 spec): three steps, the first with a button that
/// starts the export above.
struct MoveToNewPhoneView: View {
    let onBackupChanged: () -> Void

    @State private var exporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.backupMoveIntro)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("moveIntro")
                step(1, L10n.backupMoveStep1Title, L10n.backupMoveStep1Body) {
                    Button(L10n.backupNow) { exporting = true }
                        .buttonStyle(.pill(.dark, height: 44))
                        .padding(.top, 6)
                        .accessibilityIdentifier("moveBackUpNow")
                }
                step(2, L10n.backupMoveStep2Title, L10n.backupMoveStep2Body) { EmptyView() }
                step(3, L10n.backupMoveStep3Title, L10n.backupMoveStep3Body) { EmptyView() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .lunaBackground()
        .navigationTitle(L10n.backupMoveRow)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $exporting) {
            BackupExportSheet { _ in onBackupChanged() }
                .lunaSheetPresentation(detents: [.large])
        }
    }

    private func step<Extra: View>(
        _ number: Int, _ title: String, _ body: String, @ViewBuilder extra: () -> Extra
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: "\(number)")
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.avatarText))
                .frame(width: 32, height: 32)
                .background(.luna(.avatar), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityLabel("\(L10n.backupMoveStep(number)): \(title)")
                    .accessibilityAddTraits(.isHeader)
                Text(body)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.articleText))
                extra()
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("moveStep\(number)")
    }
}
