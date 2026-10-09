import KickCore
import SwiftUI

enum KickDialState: Equatable {
    case idle
    case running
    /// 10 reached; shown until the completion sheet is dismissed.
    case done(count: Int, duration: TimeInterval)
}

/// The 268 pt tap target (spec §4.6): 10 progress dots on a 120 pt radius
/// around the core (idle `pregStrong`, counting `pregOnSoft`, done `tealStrong`
/// — the design's lighter #C9673E fails AA with white text), the count with a
/// pop, "/ 10 movements", the mm:ss timer and a ripple on every counted tap.
/// One VoiceOver button with the phase 1 label and value.
struct KickDial: View {
    let state: KickDialState
    let count: Int
    let target: Int
    let startedAt: Date?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    /// Bumped only when a movement is added (not on undo or reset), so the ripple
    /// marks counted taps only.
    @State private var tapPulse = 0

    private let diameter: CGFloat = 268
    private let dotRadius: CGFloat = 120

    private var animates: Bool { !reduceMotion && LunaMotion.isEnabled }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.luna(.pregSoft))
                ForEach(0..<target, id: \.self) { index in
                    let angle = 2 * Double.pi * Double(index) / Double(target)
                    Circle()
                        .fill(index < filledDots ? Color.luna(.pregStrong) : Color.luna(.pregStrong).opacity(0.18))
                        .frame(width: 14, height: 14)
                        .offset(x: dotRadius * CGFloat(sin(angle)), y: -dotRadius * CGFloat(cos(angle)))
                }
                Circle()
                    .fill(.luna(coreFill))
                    // A warm drop shadow in light mode; a soft glow of the core in the
                    // indigo dark mode (as the handoff's accent buttons).
                    .shadow(color: colorScheme == .dark ? Color.luna(coreFill).opacity(0.4) : Color.luna(.pregOnSoft).opacity(0.45), radius: 15, y: 14)
                    .overlay { RippleRing(trigger: tapPulse) }
                    .overlay {
                        coreContent
                            .padding(22)
                            // The core is a fixed 208 pt circle: past AX2 the text
                            // only shrinks; VoiceOver reads the value instead.
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    }
                    .padding(30)
            }
            .frame(width: diameter, height: diameter)
            .animation(animates ? .easeOut(duration: 0.25) : nil, value: count)
        }
        .buttonStyle(KickDialPressStyle(animates: animates))
        .onChange(of: filledDots) { old, new in
            if new > old { tapPulse += 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.counterA11yButton)
        .accessibilityValue(L10n.counterA11yValue(count, target))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("kickButton")
    }

    private var filledDots: Int {
        if case .done(let total, _) = state { return total }
        return count
    }

    private var coreFill: LunaToken {
        switch state {
        case .idle: .pregStrong
        case .running: .pregOnSoft
        case .done: .tealStrong
        }
    }

    @ViewBuilder
    private var coreContent: some View {
        switch state {
        case .idle:
            VStack(spacing: 4) {
                Text(L10n.counterIdleTitle)
                    .font(.luna(size: 22, weight: .bold, relativeTo: .title2))
                Text(L10n.counterIdleBody)
                    .font(.luna(.caption))
            }
            .foregroundStyle(.luna(.onAccent))
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)
        case .running:
            VStack(spacing: 2) {
                Text(count, format: .number)
                    .font(.luna(.kickCount))
                    .contentTransition(animates ? .numericText() : .identity)
                    .lunaPop(trigger: count)
                Text(L10n.counterOfTarget(target))
                    .font(.luna(.body))
                if let startedAt {
                    TimelineView(.periodic(from: startedAt, by: 1)) { context in
                        Text(KickClock.text(elapsed: context.date.timeIntervalSince(startedAt)))
                            .font(.luna(.cardTitleSmall))
                            .monospacedDigit()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.luna(.onAccent).opacity(0.18)))
                    }
                    .padding(.top, 8)
                }
            }
            .foregroundStyle(.luna(.onAccent))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        case .done(let total, let duration):
            VStack(spacing: 2) {
                Text(L10n.counterDoneLabel)
                    .lunaLabelStyle(.onAccent)
                Text(total, format: .number)
                    .font(.luna(.doneCount))
                Text(L10n.counterDoneDetail(duration < 60 ? L10n.underOneMinute : Formatting.minutes(duration / 60)))
                    .font(.luna(.body))
            }
            .foregroundStyle(.luna(.onAccent))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
    }
}

/// The core shrinks to 95 % while pressed (README §6); not with Reduce Motion
/// or in UI tests.
private struct KickDialPressStyle: ButtonStyle {
    let animates: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(animates && configuration.isPressed ? 0.95 : 1)
            .animation(animates ? .easeOut(duration: 0.12) : nil, value: configuration.isPressed)
    }
}
