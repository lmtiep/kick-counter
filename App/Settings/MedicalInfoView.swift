import KickCore
import SwiftUI

struct MedicalInfoView: View {
    @Environment(\.contentLibrary) private var library
    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults) private var appMode = AppMode.pregnant.rawValue

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Trying-to-conceive notes first in that mode; kick-count guidance first otherwise.
                if mode == .tryingToConceive {
                    ttcSection
                    kickSection
                } else {
                    kickSection
                    ttcSection
                }

                if let sources = library?.sources, !sources.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.medicalSourcesTitle)
                            .font(.headline)
                        Text(L10n.medicalSourcesNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(sources, id: \.self) { source in
                            Label {
                                Text(verbatim: source)
                            } icon: {
                                Image(systemName: "book.closed")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .font(.subheadline)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("medicalSources")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(L10n.medicalTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kickSection: some View {
        Text(L10n.medicalBody)
            .font(.body)
    }

    private var ttcSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.medicalTTCTitle)
                .font(.headline)
            Text(L10n.medicalTTCBody)
                .font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("medicalTTC")
    }
}
