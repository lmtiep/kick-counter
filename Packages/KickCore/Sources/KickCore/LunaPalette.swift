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

    /// This colour drawn over `backdrop` (source-over in sRGB, as the screen shows it).
    public func composited(over backdrop: LunaHex) -> LunaHex {
        guard alpha < 1 else { return self }
        func channel(_ top: Double, _ bottom: Double) -> UInt32 {
            UInt32(((top * alpha + bottom * (1 - alpha)) * 255).rounded())
        }
        let rgb = channel(red, backdrop.red) << 16 | channel(green, backdrop.green) << 8 | channel(blue, backdrop.blue)
        return LunaHex(rgb)
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
    // Phase 18 (the indigo dark mode). Each one equals an existing light value,
    // so light mode is unchanged.
    case backgroundTop, backgroundBottom
    case cardBorder, cycleSoftBorder, pregSoftBorder, avatarBorder
    case onSegmentSelected, cycleText, pregText, fetusGlowEdge
}

public enum LunaPalette {
    /// Light values: the design (`Mam App.dc.html`). Dark values: the indigo dark
    /// mode of phase 18 (`docs/design/handoff-2026-10-09`, README §3), darkened
    /// where the handoff's values miss WCAG AA (see `LunaBackdrop`).
    public static func pair(_ token: LunaToken) -> LunaColorPair {
        switch token {
        // Dark: the middle stop of the indigo gradient (`LunaBackground` draws the
        // gradient; this solid value is for gaps, fades and the status bar).
        case .background: pair(0xFBF6F1, 0x3E4367)
        case .backgroundTop: pair(0xFBF6F1, 0x4B4F75)
        case .backgroundBottom: pair(0xFBF6F1, 0x393D5B)
        case .onboardingBackground: pair(0xF4F1EC, 0x1A1412)
        // Glass card: white at 9 % with a 1 pt white border at 14 % (light: invisible).
        case .card: LunaColorPair(light: LunaHex(0xFFFFFF), dark: LunaHex(0xFFFFFF, alpha: 0.09))
        case .cardBorder: LunaColorPair(light: LunaHex(0xFFFFFF), dark: LunaHex(0xFFFFFF, alpha: 0.14))
        // surfaceSunken of the handoff: segmented tracks, steppers, chips.
        case .surface: LunaColorPair(light: LunaHex(0xF4ECE5), dark: LunaHex(0x141630, alpha: 0.28))
        case .surfaceAlt: LunaColorPair(light: LunaHex(0xF1E7DF), dark: LunaHex(0x141630, alpha: 0.28))
        // The chosen segment of a segmented pill: white like a card in light mode,
        // the pink accent in dark mode (handoff: "mục segmented đã chọn").
        case .segmentSelected: pair(0xFFFFFF, 0xF49CAB)
        case .onSegmentSelected: pair(0x2B201C, 0x3A2340)
        case .textPrimary: pair(0x2B201C, 0xF7F6FC)
        case .textOnboarding: pair(0x141110, 0xF4ECE5)
        // Handoff #C9CBE3 is 3.6:1 on a glass card: the lighter #DCDDF0 instead.
        case .textSecondary: pair(0x7A6B64, 0xDCDDF0)
        case .textMuted: pair(0x9A8A82, 0xDCDDF0)
        case .chevron: pair(0xB5A69E, 0xC9CBE3)
        case .articleText: pair(0x544640, 0xECEDF7)
        // Ring and calendar segments; the filled accent (buttons, period days) and the
        // big ring figure are cycleStrong; small pink text is cycleText.
        case .cycle: pair(0xE0566B, 0xF49CAB)
        case .cycleStrong: pair(0xC2384F, 0xF7A6B4)
        case .cycleText: pair(0xC2384F, 0xFFDCE2)
        case .cycleSoft: LunaColorPair(light: LunaHex(0xFBE3E6), dark: LunaHex(0xF7A6B4, alpha: 0.12))
        case .cycleSoftBorder: LunaColorPair(light: LunaHex(0xFBE3E6), dark: LunaHex(0xF7A6B4, alpha: 0.32))
        // Darker than cycleStrong: cycleStrong on cycleSoft is only 4.34:1 (ContrastTests).
        case .cycleOnSoft: pair(0xA82D42, 0xFFF0F3)
        case .fertile: pair(0x8CCFC7, 0xA1E6E8)
        case .fertileSoft: LunaColorPair(light: LunaHex(0xE3F2F0), dark: LunaHex(0xA1E6E8, alpha: 0.08))
        case .ovulation: LunaColorPair(light: LunaHex(0xCBEAE6), dark: LunaHex(0xA1E6E8, alpha: 0.12))
        case .teal: pair(0x2F8C84, 0xA1E6E8)
        case .tealStrong: pair(0x1F6E67, 0xE6FAFA)
        // Pregnancy in dark mode: the warm peach/terracotta family lightened for the
        // indigo, like the pink cycle accents (fill #F5B48F, small text #FDE3D3).
        case .preg: pair(0xC9673E, 0xF5B48F)
        case .pregStrong: pair(0xB8572F, 0xF5B48F)
        case .pregText: pair(0xB8572F, 0xFDE3D3)
        case .pregSoft: LunaColorPair(light: LunaHex(0xF7E3D7), dark: LunaHex(0xF5B48F, alpha: 0.12))
        case .pregSoftBorder: LunaColorPair(light: LunaHex(0xF7E3D7), dark: LunaHex(0xF5B48F, alpha: 0.32))
        case .pregOnSoft: pair(0x9C4823, 0xFFF2EA)
        case .pregBar: LunaColorPair(light: LunaHex(0xE3A584), dark: LunaHex(0xF5B48F, alpha: 0.45))
        case .track: LunaColorPair(light: LunaHex(0xF1E2D8), dark: LunaHex(0xFFFFFF, alpha: 0.10))
        case .ringTrack: LunaColorPair(light: LunaHex(0xF3E6E0), dark: LunaHex(0xFFFFFF, alpha: 0.12))
        // README §3: today's ring on the calendar (#E8CFC4); dark: white at 50 %.
        case .todayRing: LunaColorPair(light: LunaHex(0xE8CFC4), dark: LunaHex(0xFFFFFF, alpha: 0.5))
        case .warningBackground: LunaColorPair(light: LunaHex(0xFDE8E4), dark: LunaHex(0xFF9C8A, alpha: 0.12))
        case .warningBorder: LunaColorPair(light: LunaHex(0xF3C2B8), dark: LunaHex(0xFF9C8A, alpha: 0.32))
        case .warningText: pair(0xA3301F, 0xFFECE8)
        case .warningButton: pair(0xC23A26, 0xFFA494)
        case .buttonDark: pair(0x2B201C, 0xF7F6FC)
        case .buttonOnboarding: pair(0x0F0D0C, 0xF4ECE5)
        // Text on every filled accent (buttons, kick dial, calendar period days):
        // white in light mode, the handoff's deep plum on the light dark-mode accents.
        case .onAccent: pair(0xFFFFFF, 0x3A2340)
        case .onButtonOnboarding: pair(0xFFFFFF, 0x141110)
        // Dark: indigo at 72 % over the system material (handoff "Tab bar").
        case .tabBar: LunaColorPair(light: LunaHex(0xFBF6F1, alpha: 0.96), dark: LunaHex(0x3A3E62, alpha: 0.72))
        case .tabInactive: pair(0xA89890, 0xDCDDF0)
        case .avatar: LunaColorPair(light: LunaHex(0xF2C9B5), dark: LunaHex(0xF7A6B4, alpha: 0.16))
        case .avatarBorder: LunaColorPair(light: LunaHex(0xF2C9B5), dark: LunaHex(0xF7A6B4, alpha: 0.35))
        case .avatarText: pair(0x8A3F1F, 0xFFF0F3)
        case .divider: LunaColorPair(light: LunaHex(0x2B201C, alpha: 0.07), dark: LunaHex(0xFFFFFF, alpha: 0.10))
        // Week detail gradient (spec §4.5) and the glow behind the fetus (README §4).
        case .heroTop: pair(0xEBB394, 0x5A5582)
        case .heroMiddle: pair(0xF7DCC9, 0x474A70)
        case .fetusGlowInner: pair(0xFCEBDD, 0x6E5F86)
        case .fetusGlowOuter: pair(0xF6D7C2, 0x534F7A)
        // Where the fetus glow ends: the page colour in light mode, nothing in dark
        // mode (the gradient shows through).
        case .fetusGlowEdge: LunaColorPair(light: LunaHex(0xFBF6F1), dark: LunaHex(0x534F7A, alpha: 0))
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

    /// What a screen is painted on: the flat page colour in light mode; in dark mode
    /// the indigo gradient, checked at its lightest, middle and darkest stops
    /// (`LunaBackground` draws no decorative glows: they would lighten the top).
    public static func backdrops(dark: Bool) -> [LunaHex] {
        dark
            ? [LunaToken.backgroundTop, .background, .backgroundBottom].map { LunaPalette.pair($0).dark }
            : [LunaPalette.pair(.background).light]
    }

    /// The opaque colours a background token can end up as on screen. A translucent
    /// surface (the dark glass card, the soft tints) is composited over every backdrop,
    /// and, except the card itself, also over a card on every backdrop (a chip in a card).
    public static func surfaces(_ token: LunaToken, dark: Bool) -> [LunaHex] {
        let value = dark ? LunaPalette.pair(token).dark : LunaPalette.pair(token).light
        if token == .background { return backdrops(dark: dark) }
        guard value.alpha < 1 else { return [value] }
        let card = dark ? LunaPalette.pair(.card).dark : LunaPalette.pair(.card).light
        return backdrops(dark: dark).flatMap { backdrop -> [LunaHex] in
            let direct = value.composited(over: backdrop)
            guard token != .card else { return [direct] }
            return [direct, value.composited(over: card.composited(over: backdrop))]
        }
    }

    /// The worst contrast of `foreground` drawn on `background`, over every surface the
    /// background can be (`surfaces`).
    public static func minimumRatio(_ foreground: LunaToken, on background: LunaToken, dark: Bool) -> Double {
        let text = dark ? LunaPalette.pair(foreground).dark : LunaPalette.pair(foreground).light
        return surfaces(background, dark: dark)
            .map { ratio(text.composited(over: $0), $0) }
            .min() ?? 1
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
        Usage(.onSegmentSelected, on: .segmentSelected),
        // Onboarding body and medical note, on the scrim behind the content.
        Usage(.articleText, on: .onboardingBackground),
        // cycleStrong: the big ring figure only; smaller pink text is cycleText.
        Usage(.cycleStrong, on: .background, large: true), Usage(.cycleStrong, on: .card, large: true),
        Usage(.cycleText, on: .background), Usage(.cycleText, on: .card), Usage(.cycleText, on: .tabBar),
        Usage(.cycleOnSoft, on: .cycleSoft), Usage(.cycleOnSoft, on: .card),
        Usage(.tealStrong, on: .background), Usage(.tealStrong, on: .card),
        Usage(.tealStrong, on: .fertileSoft), Usage(.tealStrong, on: .ovulation),
        // pregStrong: display figures only; smaller pregnancy text is pregText.
        Usage(.pregStrong, on: .background, large: true), Usage(.pregStrong, on: .card, large: true),
        Usage(.pregText, on: .card),
        Usage(.pregOnSoft, on: .pregSoft), Usage(.pregOnSoft, on: .background), Usage(.pregOnSoft, on: .card),
        Usage(.pregOnSoft, on: .tabBar), Usage(.pregOnSoft, on: .surfaceAlt), Usage(.pregOnSoft, on: .heroMiddle),
        Usage(.warningText, on: .warningBackground), Usage(.warningText, on: .card), Usage(.warningText, on: .background),
        Usage(.onAccent, on: .cycleStrong), Usage(.onAccent, on: .pregStrong), Usage(.onAccent, on: .pregOnSoft),
        Usage(.onAccent, on: .tealStrong), Usage(.onAccent, on: .warningButton), Usage(.onAccent, on: .buttonDark),
        Usage(.onButtonOnboarding, on: .buttonOnboarding),
        Usage(.avatarText, on: .avatar),
    ]
}
