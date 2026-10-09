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
    /// Onboarding's primary button and restore link follow the text (phase 18 handoff §1).
    static let buttonUp = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8).delay(0.6)
    static let linkUp = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8).delay(0.7)
    static let dots = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.5)
    static let overlay = Animation.easeOut(duration: 0.28)
    static let fade = Animation.easeOut(duration: 0.2)
    /// The week article sheet settling on a detent (phase 6 spec §3.5).
    static let sheetSpring = Animation.spring(response: 0.35, dampingFraction: 0.85)

    /// `sheetSpring`, or nil (the sheet jumps) under Reduce Motion and in UI tests.
    static func sheet(reduceMotion: Bool) -> Animation? {
        isEnabled && !reduceMotion ? sheetSpring : nil
    }
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
    /// As `contentUp`, after 0.6 s (the onboarding button).
    case buttonUp
    /// As `contentUp`, after 0.7 s (the restore link).
    case linkUp

    var animation: Animation {
        switch self {
        case .reveal: LunaMotion.reveal
        case .kenBurns: LunaMotion.kenBurns
        case .waveRise: LunaMotion.waveRise
        case .contentUp: LunaMotion.contentUp
        case .buttonUp: LunaMotion.buttonUp
        case .linkUp: LunaMotion.linkUp
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
                case .contentUp, .buttonUp, .linkUp:
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
private struct RevealMask: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    // A Shape (nonisolated `path(in:)`) rather than a View: a View's Animatable
    // conformance crosses into main-actor-isolated code under Swift 6.
    func path(in rect: CGRect) -> Path {
        let radius = progress * 1.5 * sqrt((rect.width * rect.width + rect.height * rect.height) / 2)
        let center = CGPoint(x: rect.minX + rect.width * 1.05, y: rect.minY + rect.height * 0.38)
        return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
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
    // Not private: keeps the memberwise init usable from other files.
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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
