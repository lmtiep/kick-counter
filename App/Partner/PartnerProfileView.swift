import KickCore
import SwiftUI

/// Partner mode, Profile tab (phase 8 spec §5.2): language, what is shared,
/// medical information, version, and "Leave partner mode".
struct PartnerProfileView: View {
    let onLeave: () -> Void

    @State private var confirmingLeave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    LanguagePickerCard()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.partnerAboutTitle)
                            .font(.luna(.bodyStrong))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.partnerSharePrivacy)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .lunaCard()
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("partnerAbout")
                    VStack(alignment: .leading, spacing: 0) {
                        NavigationLink { MedicalInfoView() } label: {
                            LunaRow(title: L10n.settingsMedicalInfo)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settingsMedicalInfo")
                        LunaDivider()
                        LunaRow(title: L10n.settingsVersion, value: appVersion, showsChevron: false)
                            .accessibilityElement(children: .combine)
                    }
                    .lunaCard(padding: 0)
                    Button(role: .destructive) {
                        confirmingLeave = true
                    } label: {
                        Text(L10n.partnerLeave)
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.warningText))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .lunaCard(padding: 0)
                    .accessibilityIdentifier("partnerLeave")
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .lunaStatusBarBackdrop()
            .lunaBackground()
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(L10n.partnerLeaveConfirm, isPresented: $confirmingLeave, titleVisibility: .visible) {
                Button(L10n.partnerLeave, role: .destructive, action: onLeave)
                Button(L10n.commonCancel, role: .cancel) {}
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.appName)
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
            Text(L10n.partnerModeName)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .accessibilityIdentifier("profileModeName")
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
