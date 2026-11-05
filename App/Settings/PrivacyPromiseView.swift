import SwiftUI

/// "Your privacy": the four promises from the welcome step, plus what the app does
/// with reminders, backups and "Delete all data". Says only what the app does.
struct PrivacyPromiseView: View {
    private var promises: [(symbol: String, text: String, id: String)] {
        [
            ("heart", L10n.onboardingPromiseFree, "privacyFree"),
            ("nosign", L10n.onboardingPromiseNoAds, "privacyNoAds"),
            ("person", L10n.onboardingPromiseNoAccount, "privacyNoAccount"),
            ("lock", L10n.onboardingPromiseOnDevice, "privacyOnDevice"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(promises, id: \.id) { promise in
                        point(promise.text, symbol: promise.symbol, identifier: promise.id)
                    }
                }
                .lunaCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.privacyNotifications)
                    Text(L10n.privacyBackup)
                    Text(L10n.privacyDeleteAll)
                }
                .font(.luna(.body))
                .lineSpacing(4)
                .foregroundStyle(.luna(.articleText))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lunaCard()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("privacyDetails")

                Link(destination: AppLinks.privacyPolicy) {
                    HStack(spacing: 8) {
                        Text(L10n.privacyPolicyLink)
                            .font(.luna(.body))
                            .foregroundStyle(.luna(.textPrimary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.luna(.chevron))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .lunaCard()
                .accessibilityHint(L10n.settingsOpensInSafari)
                .accessibilityIdentifier("privacyPolicyLink")
            }
            .padding(20)
        }
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .navigationTitle(L10n.profilePrivacyPromise)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func point(_ text: String, symbol: String, identifier: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OnboardingPalette.privacyIcon)
                .frame(width: 28, height: 28)
                .background(Circle().fill(OnboardingPalette.privacyIconBackground))
                .accessibilityHidden(true)
            Text(text)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(identifier)
        }
    }
}
