import KickCore
import SwiftUI

/// "When to get care right away" (phase 5 spec §3.2), right under the symptom
/// chips once contractions or swollen feet are chosen. Fixed, reviewed wording;
/// no diagnosis and no contraction counting.
struct SymptomSafetyCard: View {
    let symptoms: Set<Symptom>
    /// False when the current week's content is hidden (release build, not
    /// yet reviewed): the action button is hidden, since it would open a week
    /// detail with no warnings section to scroll to. The "go now" text above
    /// stays either way.
    let canShowWarnings: Bool
    let onShowWarnings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.symptomSafetyTitle, systemImage: "exclamationmark.triangle.fill")
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.warningText))
                .accessibilityAddTraits(.isHeader)
            if symptoms.contains(.contractions) {
                Text(L10n.symptomSafetyContractions)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if symptoms.contains(.swollenFeet) {
                Text(L10n.symptomSafetySwelling)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.symptomSafetyNote)
                .font(.luna(.small))
            if canShowWarnings {
                Button(L10n.symptomSafetyAction, action: onShowWarnings)
                    .buttonStyle(.pill(.text(.warningText), fullWidth: false, height: 44))
                    .accessibilityIdentifier("symptomSafetyAction")
            }
        }
        .font(.luna(.body))
        .foregroundStyle(.luna(.articleText))
        .lunaCard(.warningBackground, border: .warningBorder, padding: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("symptomSafetyCard")
    }
}

#Preview {
    SymptomSafetyCard(symptoms: [.contractions, .swollenFeet], canShowWarnings: true) {}
        .padding(22)
        .background(.luna(.background))
}
