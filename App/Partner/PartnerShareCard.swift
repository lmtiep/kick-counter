import KickCore
import SwiftUI

/// Profile, pregnancy mode (phase 8 spec §5.1): "Share with baby's dad". The
/// row opens the iCloud sharing controller; while sharing, "Stop sharing" with
/// a confirmation; under them, exactly what is shared.
struct PartnerShareCard: View {
    @Environment(PartnerShareCoordinator.self) private var share
    @Environment(\.partnerPublisher) private var publisher
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @State private var confirmingStop = false
    /// Creating the share and uploading the first snapshot before the controller shows.
    @State private var opening = false

    private var row: PartnerShareRow {
        PartnerShareRow(status: share.status, hasDueDate: dueDate > 0)
    }

    private var isBusy: Bool { share.isWorking || opening }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Task { await open() }
            } label: {
                label
            }
            .buttonStyle(.plain)
            .disabled(!row.isEnabled || isBusy)
            .accessibilityIdentifier("partnerShareRow")
            if row.canStop {
                LunaDivider()
                Button(role: .destructive) {
                    confirmingStop = true
                } label: {
                    Text(L10n.partnerShareStop)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.warningText))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityIdentifier("partnerStopSharing")
            }
            LunaDivider()
            Text(L10n.partnerSharePrivacy)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .accessibilityIdentifier("partnerSharePrivacy")
        }
        .lunaCard(padding: 0)
        .task { await share.refresh() }
        .confirmationDialog(L10n.partnerShareStopConfirm, isPresented: $confirmingStop, titleVisibility: .visible) {
            Button(L10n.partnerShareStop, role: .destructive) {
                Task { await stop() }
            }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }

    private var label: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.luna(.pregOnSoft))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.luna(.pregSoft)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.partnerShareTitle)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                Text(subtitle)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if row.isEnabled {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        switch row {
        case .checking: L10n.partnerShareChecking
        case .notShared: L10n.partnerShareInvite
        case .invited: L10n.partnerShareInvited
        case .joined: L10n.partnerShareJoined
        case .needsDueDate: L10n.partnerShareNeedsDueDate
        case .iCloudUnavailable: L10n.partnerShareICloudUnavailable
        case .iCloudFull: L10n.partnerShareICloudFull
        case .failed:
            if let code = share.failureCode {
                L10n.partnerShareFailedCode(code)
            } else {
                L10n.partnerShareFailed
            }
        }
    }

    /// Not shared: creates the share and opens the controller to invite. Shared:
    /// opens the same controller to manage it. After a failure: checks again.
    private func open() async {
        if row == .failed || row == .iCloudFull {
            await share.refresh()
            return
        }
        opening = true
        defer { opening = false }
        guard let handle = await share.startSharing() else { return }
        // Upload before the controller shows, so a partner who accepts at once
        // finds a snapshot; a failure is retried in the background.
        await publisher?.publishNow()
        CloudSharingPresenter.present(
            handle,
            onChange: { Task { await share.refresh() } },
            // Stopped from the system sheet: it deleted only the CKShare; delete the zone too.
            onStop: { Task { await stop() } }
        )
    }

    /// Deletes the zone with the share and the snapshot.
    private func stop() async {
        if await share.stopSharing() {
            publisher?.forgetPublished()
        }
    }
}
