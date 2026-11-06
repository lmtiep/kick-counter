import KickCore
import SwiftUI

/// The cycle Today while predictions are paused after a pregnancy ended (1.1
/// item 4, spec §4.4): no prediction, fertile window or "late", one gentle,
/// factual line for her branch, and a way to log the period when it comes.
struct CyclePausedCard: View {
    let branch: PregnancyEndBranch
    let working: Bool
    let onStartedToday: () -> Void
    let onStartedEarlier: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "moon.stars")
                .font(.system(size: 28))
                .foregroundStyle(.luna(.cycleStrong))
                .accessibilityHidden(true)
            Text(L10n.cyclePaused(branch))
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cyclePausedText")
            Button(L10n.cycleRingStart, action: onStartedToday)
                .buttonStyle(.pill(.filled(.cycleStrong), height: 44))
                .disabled(working)
                .accessibilityLabel(L10n.cycleStartPeriod)
                .accessibilityIdentifier("cyclePausedStart")
            Button(L10n.cyclePausedEarlier, action: onStartedEarlier)
                .buttonStyle(.pill(.text(.cycleText), height: 44))
                .disabled(working)
                .accessibilityIdentifier("cyclePausedEarlier")
        }
        .lunaCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cyclePausedCard")
    }
}
