import Foundation
import Testing
@testable import KickCore

struct ContrastTests {
    private func ratio(_ text: LunaToken, _ background: LunaToken, dark: Bool) -> Double {
        let textPair = LunaPalette.pair(text)
        let backgroundPair = LunaPalette.pair(background)
        return LunaContrast.ratio(dark ? textPair.dark : textPair.light, dark ? backgroundPair.dark : backgroundPair.light)
    }

    @Test func ratioMatchesTheWCAGFormula() {
        #expect(abs(LunaContrast.ratio(LunaHex(0xFFFFFF), LunaHex(0x000000)) - 21) < 0.001)
        #expect(abs(LunaContrast.ratio(LunaHex(0x777777), LunaHex(0xFFFFFF)) - 4.48) < 0.01)
        #expect(LunaContrast.ratio(LunaHex(0x2B201C), LunaHex(0x2B201C)) == 1)
    }

    @Test func designValuesAreKeptVerbatim() {
        #expect(LunaPalette.pair(.background).light == LunaHex(0xFBF6F1))
        #expect(LunaPalette.pair(.cycleStrong).light == LunaHex(0xC2384F))
        #expect(LunaPalette.pair(.pregStrong).light == LunaHex(0xB8572F))
        #expect(LunaPalette.pair(.tabBar).light == LunaHex(0xFBF6F1, alpha: 0.96))
    }

    @Test(arguments: [false, true])
    func everyDeclaredPairMeetsAA(dark: Bool) {
        for usage in LunaContrast.usages where !dark ? usage.checksLight : true {
            let value = LunaContrast.minimumRatio(usage.text, on: usage.background, dark: dark)
            #expect(
                value >= usage.requiredRatio,
                "\(usage.text) on \(usage.background) (\(dark ? "dark" : "light")): \(value)"
            )
        }
    }

    /// Design pairs that fail AA, and the darker variant the app draws instead (spec §3).
    @Test func designPairsBelowAAAreReplaced() {
        // White on #E0566B → filled cycle buttons and calendar period days use cycleStrong.
        #expect(ratio(.onAccent, .cycle, dark: false) < 4.5)
        #expect(ratio(.onAccent, .cycleStrong, dark: false) >= 4.5)
        // White on #C9673E → the idle kick dial uses pregStrong.
        #expect(ratio(.onAccent, .preg, dark: false) < 4.5)
        // #C2384F on #FBE3E6 → period days and pills use cycleOnSoft.
        #expect(ratio(.cycleStrong, .cycleSoft, dark: false) < 4.5)
        // #2F8C84 on the background → fertile day numbers use tealStrong.
        #expect(ratio(.teal, .background, dark: false) < 4.5)
        // #9A8A82 (the design's muted grey) on the background → small grey labels use textSecondary.
        #expect(LunaContrast.ratio(LunaHex(0x9A8A82), LunaPalette.pair(.background).light) < 4.5)
        // #A89890 on the tab bar → inactive tab labels use textSecondary.
        #expect(ratio(.tabInactive, .tabBar, dark: false) < 4.5)
        // #B8572F on the tab bar (11 pt) → the active pregnancy tab uses pregOnSoft.
        #expect(ratio(.pregStrong, .tabBar, dark: false) < 4.5)
        // #7A6B64 on #F4ECE5 / #F1E7DF → body text on surface cards uses articleText.
        #expect(ratio(.textSecondary, .surface, dark: false) < 4.5)
        #expect(ratio(.textSecondary, .surfaceAlt, dark: false) < 4.5)
        // White on the dark-mode accents → onAccent is the handoff's deep plum in dark mode.
        #expect(LunaPalette.pair(.onAccent).dark == LunaHex(0x3A2340))
    }

    /// The chosen segment of a segmented pill stands out from its track in both
    /// modes (dark `card` on the dark `surfaceAlt` track was nearly invisible).
    @Test(arguments: [false, true])
    func selectedSegmentStandsOutFromItsTrack(dark: Bool) {
        #expect(LunaContrast.minimumRatio(.segmentSelected, on: .surfaceAlt, dark: dark) >= 1.15)
    }

    /// Calendar ovulation days are told apart from the fertile window without
    /// colour alone: their fills are nearly the same, so ovulation days (and the
    /// legend swatch) carry a `teal` ring that meets the 3:1 non-text contrast
    /// (WCAG 1.4.11) on the fill and on the card and background around it.
    @Test(arguments: [false, true])
    func ovulationRingStandsOutWhereTheFillDoesNot(dark: Bool) {
        for backdrop in LunaContrast.backdrops(dark: dark) {
            let ovulation = (dark ? LunaPalette.pair(.ovulation).dark : LunaPalette.pair(.ovulation).light)
            let fertile = (dark ? LunaPalette.pair(.fertileSoft).dark : LunaPalette.pair(.fertileSoft).light)
            #expect(LunaContrast.ratio(ovulation.composited(over: backdrop), fertile.composited(over: backdrop)) < 1.5)
        }
        #expect(LunaContrast.minimumRatio(.teal, on: .ovulation, dark: dark) >= 3)
        #expect(LunaContrast.minimumRatio(.teal, on: .card, dark: dark) >= 3)
        #expect(LunaContrast.minimumRatio(.teal, on: .background, dark: dark) >= 3)
    }

    /// Text/fill pairs of the symptom chips, the safety card and the weight
    /// screens (phase 5) are declared, so `everyDeclaredPairMeetsAA` checks them.
    @Test func phase5PairsAreDeclared() {
        let pairs: [(LunaToken, LunaToken)] = [
            (.onAccent, .cycleStrong), (.onAccent, .pregStrong), (.textPrimary, .surface),
            (.warningText, .warningBackground), (.articleText, .warningBackground),
            (.tealStrong, .fertileSoft), (.pregOnSoft, .pregSoft), (.pregStrong, .card),
            (.textSecondary, .card), (.textPrimary, .card), (.onAccent, .pregOnSoft),
        ]
        for (text, background) in pairs {
            #expect(LunaContrast.declares(text, on: background), "\(text) on \(background)")
        }
        #expect(!LunaContrast.declares(.chevron, on: .card))
    }

    @Test func everyTokenHasAValue() {
        for token in LunaToken.allCases where token != .fetusGlowEdge {
            let pair = LunaPalette.pair(token)
            #expect(pair.light.alpha > 0 && pair.dark.alpha > 0, "\(token)")
        }
        // The fetus glow fades out to nothing in dark mode, over the gradient.
        #expect(LunaPalette.pair(.fetusGlowEdge).dark.alpha == 0)
    }

    // MARK: - Phase 18: the indigo dark mode

    /// The only pairs checked in dark mode alone, each a light value that predates
    /// phase 18 (light mode must not change). A new exception must be added here.
    @Test func knownLightModeExceptions() {
        let exceptions = LunaContrast.usages.filter { !$0.checksLight }.map { "\($0.text)/\($0.background)" }
        #expect(exceptions == ["pregText/background"])
        #expect(LunaContrast.minimumRatio(.pregText, on: .background, dark: false) >= 4.3)
    }

    /// Content tints colour text (buttons, pickers, date headers), so their dark values
    /// must be the pale text tokens, not the accent fills (#F7A6B4 is 3.3:1 on a card).
    @Test func contentTintsMeetAAInDarkMode() {
        for tint in [LunaToken.cycleText, .pregText, .pregOnSoft] {
            #expect(LunaContrast.minimumRatio(tint, on: .card, dark: true) >= 4.5, "\(tint)")
            #expect(LunaContrast.minimumRatio(tint, on: .background, dark: true) >= 4.5, "\(tint)")
        }
        #expect(LunaContrast.minimumRatio(.cycleStrong, on: .card, dark: true) < 4.5)
    }

    /// Handoff §3: the gradient keeps the indigo hue, and light mode is unchanged by
    /// the new tokens (each new token's light value is an existing light value).
    @Test func newTokensKeepLightModeUnchanged() {
        let sameInLight: [(LunaToken, LunaToken)] = [
            (.backgroundTop, .background), (.backgroundBottom, .background), (.cardBorder, .card),
            (.cycleSoftBorder, .cycleSoft), (.pregSoftBorder, .pregSoft), (.avatarBorder, .avatar),
            (.onSegmentSelected, .textPrimary), (.cycleText, .cycleStrong), (.pregText, .pregStrong),
            (.fetusGlowEdge, .background), (.cardOpaque, .card),
            (.tabSelectedCycle, .cycleStrong), (.tabSelectedPreg, .pregOnSoft), (.fertileSoftBorder, .fertileSoft),
            (.segmentSelectedPreg, .segmentSelected),
        ]
        for (new, existing) in sameInLight {
            #expect(LunaPalette.pair(new).light == LunaPalette.pair(existing).light, "\(new)")
        }
    }

    /// Glass surfaces of the handoff: a 9 % white card with a 14 % white border, the
    /// gradient running from the lightest to the darkest stop.
    @Test func darkModeUsesGlassOnTheIndigoGradient() {
        #expect(LunaPalette.pair(.card).dark == LunaHex(0xFFFFFF, alpha: 0.09))
        #expect(LunaPalette.pair(.cardBorder).dark == LunaHex(0xFFFFFF, alpha: 0.14))
        let stops = LunaContrast.backdrops(dark: true)
        #expect(stops.count == 3)
        #expect(stops.map(\.relativeLuminance) == stops.map(\.relativeLuminance).sorted(by: >))
        for stop in stops {
            // Indigo: blue clearly above red and green.
            #expect(stop.blue > stop.red + 0.1 && stop.blue > stop.green + 0.1)
        }
    }

    /// Translucent surfaces are checked as drawn: over the gradient's stops, and over
    /// a card on them. A pair that passes on the opaque value alone can fail there.
    @Test func translucentSurfacesAreCompositedOverTheGradient() {
        let card = LunaContrast.surfaces(.card, dark: true)
        #expect(card.count == 3)
        #expect(card.allSatisfy { $0.alpha == 1 })
        #expect(LunaContrast.surfaces(.cycleSoft, dark: true).count == 6)
        #expect(LunaContrast.surfaces(.background, dark: true) == LunaContrast.backdrops(dark: true))
        // The handoff's #C9CBE3 secondary text misses AA on a glass card over the top stop.
        let handoffSecondary = LunaHex(0xC9CBE3)
        #expect(card.map { LunaContrast.ratio(handoffSecondary, $0) }.min()! < 4.5)
        // White at 50 % over black is mid grey.
        #expect(LunaHex(0xFFFFFF, alpha: 0.5).composited(over: LunaHex(0x000000)) == LunaHex(0x808080))
    }

    /// Filled accents of the dark mode carry the deep plum text of the handoff.
    @Test func darkAccentsCarryPlumText() {
        for fill in [LunaToken.cycleStrong, .pregStrong, .segmentSelected, .warningButton] {
            #expect(LunaContrast.minimumRatio(fill == .segmentSelected ? .onSegmentSelected : .onAccent, on: fill, dark: true) >= 4.5, "\(fill)")
        }
    }
}
