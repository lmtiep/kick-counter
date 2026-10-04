import KickCore
import SwiftUI

/// The design's animations (README "Animation onboarding", §4, §6). With
/// Reduce Motion they fall back to a fade of at most 0.2 s; in UI tests
/// (`-uiTesting`) they are off, so screenshots show the final frame.
enum LunaMotion {
    static var isEnabled: Bool { !AppClock.launchOptions.isUITesting }

    static let reveal = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 1.1)
    static let kenBurns = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 1.8)
    static let waveRise = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 1).delay(0.25)
    static let contentUp = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8).delay(0.45)
    static let dots = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.5)
    static let overlay = Animation.easeOut(duration: 0.28)
    static let fade = Animation.easeOut(duration: 0.2)
}

enum LunaEntrance {
    /// Circular wipe from the right edge (`circle(0% at 105% 38%)` → 150 %), 1.1 s.
    case reveal
    /// Image settles from `scale(1.18) translateX(6%)`, 1.8 s.
    case kenBurns
    /// Wave band rises 70 pt, 1 s after 0.25 s.
    case waveRise
    /// Text and controls rise 28 pt and fade in, 0.8 s after 0.45 s.
    case contentUp

    var animation: Animation {
        switch self {
        case .reveal: LunaMotion.reveal
        case .kenBurns: LunaMotion.kenBurns
        case .waveRise: LunaMotion.waveRise
        case .contentUp: LunaMotion.contentUp
        }
    }
}

private struct EntranceModifier: ViewModifier {
    let effect: LunaEntrance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = !LunaMotion.isEnabled

    func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content.opacity(shown ? 1 : 0)
            } else {
                switch effect {
                case .reveal:
                    content.mask { RevealMask(progress: shown ? 1 : 0) }
                case .kenBurns:
                    // Scaling around x = 1/6 moves the centre right by 6 % (README).
                    content.scaleEffect(shown ? 1 : 1.18, anchor: UnitPoint(x: 1.0 / 6, y: 0.5))
                case .waveRise:
                    content.offset(y: shown ? 0 : 70)
                case .contentUp:
                    content.offset(y: shown ? 0 : 28).opacity(shown ? 1 : 0)
                }
            }
        }
        .onAppear {
            guard !shown else { return }
            withAnimation(reduceMotion ? LunaMotion.fade : effect.animation) { shown = true }
        }
    }
}

/// The growing circle of `reveal`, centred at 105 % × 38 % of the view.
private struct RevealMask: View, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let radius = progress * 1.5 * sqrt((size.width * size.width + size.height * size.height) / 2)
            Circle()
                .frame(width: radius * 2, height: radius * 2)
                .position(x: size.width * 1.05, y: size.height * 0.38)
        }
    }
}

/// The fetus image bobs up 8 pt and tilts ±2° every 5 s (README §4).
private struct FloatModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -8 : 0)
            .rotationEffect(.degrees(reduceMotion || !LunaMotion.isEnabled ? 0 : (up ? 2 : -2)))
            .onAppear {
                guard !reduceMotion, LunaMotion.isEnabled else { return }
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { up = true }
            }
    }
}

/// The kick count grows to 120 % and back in 0.3 s each time it changes.
private struct PopModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion || !LunaMotion.isEnabled {
            content
        } else {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    CubicKeyframe(1.2, duration: 0.12)
                    CubicKeyframe(1.0, duration: 0.18)
                }
            }
        }
    }
}

private struct RippleValue {
    var scale = 1.0
    var opacity = 0.0
}

/// A 3 pt ring that grows to 135 % and fades from 60 % in 0.6 s whenever
/// `trigger` changes (each counted kick).
struct RippleRing<Trigger: Equatable>: View {
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion && LunaMotion.isEnabled {
            Circle()
                .strokeBorder(.luna(.onAccent), lineWidth: 3)
                .keyframeAnimator(initialValue: RippleValue(), trigger: trigger) { view, value in
                    view.scaleEffect(value.scale).opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(1.0)
                        CubicKeyframe(1.35, duration: 0.6)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0.6)
                        LinearKeyframe(0, duration: 0.6)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    func lunaEntrance(_ effect: LunaEntrance) -> some View {
        modifier(EntranceModifier(effect: effect))
    }

    func lunaFloat() -> some View {
        modifier(FloatModifier())
    }

    func lunaPop<Trigger: Equatable>(trigger: Trigger) -> some View {
        modifier(PopModifier(trigger: trigger))
    }
}
