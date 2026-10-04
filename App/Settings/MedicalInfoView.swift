import SwiftUI

struct MedicalInfoView: View {
    @Environment(\.contentLibrary) private var library

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.medicalBody)
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.medicalTTCTitle)
                        .font(.headline)
                    Text(L10n.medicalTTCBody)
                        .font(.body)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("medicalTTC")

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
}
