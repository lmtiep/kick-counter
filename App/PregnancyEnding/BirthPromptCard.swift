import KickCore
import SwiftUI

/// "Bé đã chào đời chưa?" on pregnancy Today from week 37 (birth celebration
/// spec §1). The button opens the ending sheet already on the birth branch's
/// date step. No dismiss or snooze: the card goes when the pregnancy ends.
struct BirthPromptCard: View {
    @State private var showingSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.luna(.cycleStrong))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.birthPromptTitle)
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.birthPromptBody)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(L10n.birthPromptButton) { showingSheet = true }
                .buttonStyle(.pill(.filled(.cycleStrong), height: 48))
                .accessibilityIdentifier("birthPromptButton")
        }
        .lunaCard(.cycleSoft, border: .cycleSoftBorder)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("birthPromptCard")
        .sheet(isPresented: $showingSheet) {
            PregnancyEndingSheet(initialBranch: .birth)
                .lunaSheetPresentation(detents: [.large])
        }
    }
}
