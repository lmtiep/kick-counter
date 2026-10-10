import KickCore
import SwiftUI

/// The onboarding's own colours (phase 18, handoff README §1). Onboarding is
/// light only, so these are fixed values rather than light/dark Luna tokens.
enum OnboardingPalette {
    /// Screen background, the same cream as the illustrations' backgrounds.
    static let background = Color(hex: 0xFFFAF2)
    /// Titles, card titles and the top bar's labels.
    static let ink = Color(hex: 0x3A2A24)
    /// Body text, card subtitles and notes.
    static let secondary = Color(hex: 0x7A6B64)
    /// The privacy and medical lines on the welcome step.
    static let commitment = Color(hex: 0x5E504A)
    /// The primary button, the current progress dot and the selected language.
    static let accent = Color(hex: 0xB4583A)
    /// Text on `accent`.
    static let onAccent = Color(hex: 0xFFFAF2)
    /// "Restore from backup" and other text links.
    static let link = Color(hex: 0x8E5A43)
    /// The other progress dots.
    static let dot = Color(hex: 0xE3D6CC)
    /// The top bar's pills (progress, language, back, skip).
    static let pill = Color.white.opacity(0.85)
    /// The disabled primary button.
    static let disabledFill = Color(hex: 0xEFE4DA)
    static let disabledText = Color(hex: 0xB5A69E)
    /// An unselected choice card; a selected one is plain white.
    static let cardUnselected = Color.white.opacity(0.6)
    static let card = Color.white
    /// The empty radio ring.
    static let radio = Color(hex: 0xDCCFC6)
    /// Tinted fills inside cards (unselected "Other day", the due date's − / + buttons).
    static let soft = Color(hex: 0xF5ECE4)
    /// The privacy line's lock.
    static let privacyIcon = Color(hex: 0x5E7A5A)
    static let privacyIconBackground = Color(hex: 0xE6EDE3)
    /// The medical line's "!" and the due date's week chip.
    static let warmSoft = Color(hex: 0xF7E3D7)

    /// The goal cards: main colour and its light tint.
    static func goal(_ goal: OnboardingGoal) -> (main: Color, soft: Color) {
        switch goal {
        case .tracking: (Color(hex: 0xE0566B), Color(hex: 0xFBE3E6))
        case .conceiving: (Color(hex: 0x4FA79E), Color(hex: 0xDDF0EC))
        case .pregnant: (Color(hex: 0xD9824F), Color(hex: 0xF7E3D7))
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The onboarding's buttons: the 58 pt primary pill (`accent`, or the cream
/// disabled look) and text buttons in `ink`. Pressing shrinks to 98 %.
struct OnboardingButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case text
    }

    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        OnboardingButtonLabel(configuration: configuration, kind: kind)
    }
}

private struct OnboardingButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let kind: OnboardingButtonStyle.Kind
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animates: Bool { !reduceMotion && LunaMotion.isEnabled }

    var body: some View {
        configuration.label
            .font(.luna(size: kind == .primary ? 16 : 15, weight: .medium, relativeTo: .body))
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: kind == .primary ? 58 : 44)
            .background {
                if kind == .primary {
                    Capsule().fill(isEnabled ? OnboardingPalette.accent : OnboardingPalette.disabledFill)
                }
            }
            .contentShape(Capsule())
            .scaleEffect(animates && configuration.isPressed ? 0.98 : 1)
            .opacity(kind == .text && !isEnabled ? 0.4 : 1)
            .animation(animates ? .easeOut(duration: 0.12) : nil, value: configuration.isPressed)
            .animation(animates ? .easeOut(duration: 0.3) : nil, value: isEnabled)
    }

    private var foreground: Color {
        switch kind {
        case .primary: isEnabled ? OnboardingPalette.onAccent : OnboardingPalette.disabledText
        case .text: OnboardingPalette.ink
        }
    }
}

extension ButtonStyle where Self == OnboardingButtonStyle {
    static func onboarding(_ kind: OnboardingButtonStyle.Kind = .primary) -> OnboardingButtonStyle {
        OnboardingButtonStyle(kind: kind)
    }
}

extension View {
    /// The onboarding cover is always light (phase 18 spec §1), also its sheets.
    func onboardingLight() -> some View {
        environment(\.colorScheme, .light).preferredColorScheme(.light)
    }

    /// A white onboarding card, radius 18 (handoff README §1, steps 3–8).
    func onboardingCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
