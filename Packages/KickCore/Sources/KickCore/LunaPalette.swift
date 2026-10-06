import Foundation

/// An sRGB colour from the design, e.g. `LunaHex(0xFBF6F1)`, optionally translucent.
public struct LunaHex: Equatable, Sendable {
    public let rgb: UInt32
    public let alpha: Double

    public init(_ rgb: UInt32, alpha: Double = 1) {
        self.rgb = rgb
        self.alpha = alpha
    }

    public var red: Double { Double((rgb >> 16) & 0xFF) / 255 }
    public var green: Double { Double((rgb >> 8) & 0xFF) / 255 }
    public var blue: Double { Double(rgb & 0xFF) / 255 }

    /// WCAG 2.x relative luminance of the opaque colour.
    public var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// The light-mode value (from the design) and the dark-mode value (derived, spec §3).
public struct LunaColorPair: Equatable, Sendable {
    public let light: LunaHex
    public let dark: LunaHex

    public init(light: LunaHex, dark: LunaHex) {
        self.light = light
        self.dark = dark
    }
}

/// Colour roles of the redesign. Views never use raw hex values: the app wraps
/// these as adaptive `Color`s (`App/DesignSystem/LunaColor.swift`).
public enum LunaToken: String, Sendable, CaseIterable {
    case background, onboardingBackground, card, surface, surfaceAlt, segmentSelected
    case textPrimary, textOnboarding, textSecondary, textMuted, chevron, articleText
    case cycle, cycleStrong, cycleSoft, cycleOnSoft
    case fertile, fertileSoft, ovulation, teal, tealStrong
    case preg, pregStrong, pregSoft, pregOnSoft, pregBar
    case track, ringTrack, todayRing
    case warningBackground, warningBorder, warningText, warningButton
    case buttonDark, buttonOnboarding, onAccent, onButtonOnboarding
    case tabBar, tabInactive, avatar, avatarText
    case divider, heroTop, heroMiddle, fetusGlowInner, fetusGlowOuter
}

public enum LunaPalette {
    public static func pair(_ token: LunaToken) -> LunaColorPair {
        switch token {
        case .background: pair(0xFBF6F1, 0x1A1412)
        case .onboardingBackground: pair(0xF4F1EC, 0x1A1412)
        case .card: pair(0xFFFFFF, 0x262019)
        case .surface: pair(0xF4ECE5, 0x2F2722)
        case .surfaceAlt: pair(0xF1E7DF, 0x342B26)
        // The chosen segment of a segmented pill: white like a card in light mode,
        // lighter than the surfaceAlt track in dark mode (a dark card vanished there).
        case .segmentSelected: pair(0xFFFFFF, 0x5A4A42)
        case .textPrimary: pair(0x2B201C, 0xF4ECE5)
        case .textOnboarding: pair(0x141110, 0xF4ECE5)
        case .textSecondary: pair(0x7A6B64, 0xB5A69E)
        case .textMuted: pair(0x9A8A82, 0x9A8A82)
        case .chevron: pair(0xB5A69E, 0x7A6B64)
        case .articleText: pair(0x544640, 0xD8CCC4)
        case .cycle: pair(0xE0566B, 0xEE7A8C)
        case .cycleStrong: pair(0xC2384F, 0xF59AA8)
        case .cycleSoft: pair(0xFBE3E6, 0x4A2128)
        // Darker than cycleStrong: cycleStrong on cycleSoft is only 4.34:1 (ContrastTests).
        case .cycleOnSoft: pair(0xA82D42, 0xF7B3BE)
        case .fertile: pair(0x8CCFC7, 0x6FBFB6)
        case .fertileSoft: pair(0xE3F2F0, 0x1E3A37)
        case .ovulation: pair(0xCBEAE6, 0x24524D)
        case .teal: pair(0x2F8C84, 0x7FD3C9)
        case .tealStrong: pair(0x1F6E67, 0xA6E3DB)
        case .preg: pair(0xC9673E, 0xE08A5F)
        case .pregStrong: pair(0xB8572F, 0xF0A07A)
        case .pregSoft: pair(0xF7E3D7, 0x45281A)
        case .pregOnSoft: pair(0x9C4823, 0xF4C2A6)
        case .pregBar: pair(0xE3A584, 0x8A4E33)
        case .track: pair(0xF1E2D8, 0x3A2E28)
        case .ringTrack: pair(0xF3E6E0, 0x3A2E28)
        // README §3: today's ring on the calendar (#E8CFC4).
        case .todayRing: pair(0xE8CFC4, 0x5A4A42)
        case .warningBackground: pair(0xFDE8E4, 0x4A1E18)
        case .warningBorder: pair(0xF3C2B8, 0x7A3328)
        case .warningText: pair(0xA3301F, 0xFF9C8A)
        case .warningButton: pair(0xC23A26, 0xE0563F)
        case .buttonDark: pair(0x2B201C, 0xF4ECE5)
        case .buttonOnboarding: pair(0x0F0D0C, 0xF4ECE5)
        // Text on every filled accent (buttons, kick dial, calendar period days):
        // white in light mode, near-black on the lighter dark-mode accents.
        case .onAccent: pair(0xFFFFFF, 0x1A1412)
        case .onButtonOnboarding: pair(0xFFFFFF, 0x141110)
        case .tabBar: LunaColorPair(light: LunaHex(0xFBF6F1, alpha: 0.96), dark: LunaHex(0x1A1412, alpha: 0.96))
        case .tabInactive: pair(0xA89890, 0x7A6B64)
        case .avatar: pair(0xF2C9B5, 0x5A3424)
        case .avatarText: pair(0x8A3F1F, 0xF2C9B5)
        case .divider: LunaColorPair(light: LunaHex(0x2B201C, alpha: 0.07), dark: LunaHex(0xF4ECE5, alpha: 0.08))
        // Week detail gradient (spec §4.5) and the glow behind the fetus (README §4).
        case .heroTop: pair(0xEBB394, 0x5A3424)
        case .heroMiddle: pair(0xF7DCC9, 0x3A2A22)
        case .fetusGlowInner: pair(0xFCEBDD, 0x4A2E22)
        case .fetusGlowOuter: pair(0xF6D7C2, 0x3A2A22)
        }
    }

    private static func pair(_ light: UInt32, _ dark: UInt32) -> LunaColorPair {
        LunaColorPair(light: LunaHex(light), dark: LunaHex(dark))
    }
}

/// WCAG AA contrast for the text/background pairs the UI really uses (spec §3).
public enum LunaContrast {
    public struct Usage: Sendable {
        public let text: LunaToken
        public let background: LunaToken
        /// ≥ 18 pt, or ≥ 14 pt bold (700): 3:1 is enough; otherwise 4.5:1.
        public let isLargeText: Bool

        public init(_ text: LunaToken, on background: LunaToken, large: Bool = false) {
            self.text = text
            self.background = background
            isLargeText = large
        }

        public var requiredRatio: Double { isLargeText ? 3 : 4.5 }
    }

    /// Whether `usages` lists that text colour on that background.
    public static func declares(_ text: LunaToken, on background: LunaToken) -> Bool {
        usages.contains { $0.text == text && $0.background == background }
    }

    public static func ratio(_ first: LunaHex, _ second: LunaHex) -> Double {
        let lighter = max(first.relativeLuminance, second.relativeLuminance)
        let darker = min(first.relativeLuminance, second.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Every text colour drawn on every background in the redesign. Views must not
    /// draw text in a pair missing from this list.
    public static let usages: [Usage] = [
        Usage(.textPrimary, on: .background), Usage(.textPrimary, on: .card),
        Usage(.textPrimary, on: .surface), Usage(.textPrimary, on: .surfaceAlt),
        Usage(.textPrimary, on: .cycleSoft), Usage(.textPrimary, on: .pregSoft),
        Usage(.textPrimary, on: .fertileSoft), Usage(.textPrimary, on: .ovulation),
        Usage(.textPrimary, on: .warningBackground), Usage(.textPrimary, on: .track),
        Usage(.textPrimary, on: .heroTop), Usage(.textPrimary, on: .heroMiddle),
        Usage(.textSecondary, on: .background), Usage(.textSecondary, on: .card),
        Usage(.textSecondary, on: .onboardingBackground), Usage(.textSecondary, on: .tabBar),
        Usage(.articleText, on: .background), Usage(.articleText, on: .card),
        Usage(.articleText, on: .surface), Usage(.articleText, on: .surfaceAlt),
        Usage(.articleText, on: .warningBackground),
        Usage(.textOnboarding, on: .onboardingBackground), Usage(.textOnboarding, on: .card),
        // Onboarding last-period step: the title can sit on the pink hero gradient.
        Usage(.textOnboarding, on: .cycleSoft),
        Usage(.textPrimary, on: .segmentSelected),
        // Onboarding body and medical note, on the scrim behind the content.
        Usage(.articleText, on: .onboardingBackground),
        Usage(.cycleStrong, on: .background), Usage(.cycleStrong, on: .card), Usage(.cycleStrong, on: .tabBar),
        Usage(.cycleOnSoft, on: .cycleSoft), Usage(.cycleOnSoft, on: .card),
        Usage(.tealStrong, on: .background), Usage(.tealStrong, on: .card),
        Usage(.tealStrong, on: .fertileSoft), Usage(.tealStrong, on: .ovulation),
        Usage(.pregStrong, on: .background, large: true), Usage(.pregStrong, on: .card),
        Usage(.pregOnSoft, on: .pregSoft), Usage(.pregOnSoft, on: .background), Usage(.pregOnSoft, on: .card),
        Usage(.pregOnSoft, on: .tabBar), Usage(.pregOnSoft, on: .surfaceAlt), Usage(.pregOnSoft, on: .heroMiddle),
        Usage(.warningText, on: .warningBackground), Usage(.warningText, on: .card), Usage(.warningText, on: .background),
        Usage(.onAccent, on: .cycleStrong), Usage(.onAccent, on: .pregStrong), Usage(.onAccent, on: .pregOnSoft),
        Usage(.onAccent, on: .tealStrong), Usage(.onAccent, on: .warningButton), Usage(.onAccent, on: .buttonDark),
        Usage(.onButtonOnboarding, on: .buttonOnboarding),
        Usage(.avatarText, on: .avatar),
    ]
}
