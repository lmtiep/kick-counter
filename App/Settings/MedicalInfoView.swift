import KickCore
import SwiftUI

/// Medical information (spec §4.9): the kick-count guidance, the
/// trying-to-conceive notes and the content sources, as cards.
struct MedicalInfoView: View {
    @Environment(\.contentLibrary) private var library
    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults) private var appMode = AppMode.pregnant.rawValue

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Trying-to-conceive notes first in that mode; kick-count guidance first otherwise.
                if mode == .tryingToConceive {
                    ttcSection
                    kickSection
                } else {
                    kickSection
                    ttcSection
                }

                if let sources = library?.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.medicalSourcesTitle)
                            .font(.luna(.cardTitleSmall))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.medicalSourcesNote)
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                        ForEach(sources, id: \.self) { source in
                            Label {
                                Text(verbatim: source)
                            } icon: {
                                Image(systemName: "book.closed")
                                    .foregroundStyle(.luna(.pregStrong))
                            }
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.articleText))
                        }
                    }
                    .lunaCard()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("medicalSources")
                }
            }
            .padding(20)
        }
        // Content scrolled up stays out from under the status bar.
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .navigationTitle(L10n.medicalTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kickSection: some View {
        Text(L10n.medicalBody)
            .font(.luna(.body))
            .lineSpacing(4)
            .foregroundStyle(.luna(.articleText))
            .lunaCard()
    }

    private var ttcSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.medicalTTCTitle)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
            Text(L10n.medicalTTCBody)
                .font(.luna(.body))
                .lineSpacing(4)
                .foregroundStyle(.luna(.articleText))
        }
        .lunaCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("medicalTTC")
    }
}
