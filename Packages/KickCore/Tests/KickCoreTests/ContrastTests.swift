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
        #expect(LunaPalette.pair(.background) == LunaColorPair(light: LunaHex(0xFBF6F1), dark: LunaHex(0x1A1412)))
        #expect(LunaPalette.pair(.cycleStrong).light == LunaHex(0xC2384F))
        #expect(LunaPalette.pair(.pregStrong).light == LunaHex(0xB8572F))
        #expect(LunaPalette.pair(.tabBar).light == LunaHex(0xFBF6F1, alpha: 0.96))
    }

    @Test(arguments: [false, true])
    func everyDeclaredPairMeetsAA(dark: Bool) {
        for usage in LunaContrast.usages {
            let value = ratio(usage.text, usage.background, dark: dark)
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
        // #9A8A82 on the background → small grey labels use textSecondary.
        #expect(ratio(.textMuted, .background, dark: false) < 4.5)
        // #A89890 on the tab bar → inactive tab labels use textSecondary.
        #expect(ratio(.tabInactive, .tabBar, dark: false) < 4.5)
        // #B8572F on the tab bar (11 pt) → the active pregnancy tab uses pregOnSoft.
        #expect(ratio(.pregStrong, .tabBar, dark: false) < 4.5)
        // #7A6B64 on #F4ECE5 / #F1E7DF → body text on surface cards uses articleText.
        #expect(ratio(.textSecondary, .surface, dark: false) < 4.5)
        #expect(ratio(.textSecondary, .surfaceAlt, dark: false) < 4.5)
        // White on the dark-mode accents → onAccent is near-black in dark mode.
        #expect(LunaPalette.pair(.onAccent).dark == LunaHex(0x1A1412))
    }

    /// The chosen segment of a segmented pill stands out from its track in both
    /// modes (dark `card` on the dark `surfaceAlt` track was nearly invisible).
    @Test(arguments: [false, true])
    func selectedSegmentStandsOutFromItsTrack(dark: Bool) {
        #expect(ratio(.segmentSelected, .surfaceAlt, dark: dark) >= 1.15)
        #expect(ratio(.segmentSelected, .onboardingBackground, dark: dark) >= 1.1)
    }

    @Test func everyTokenHasAValue() {
        for token in LunaToken.allCases {
            let pair = LunaPalette.pair(token)
            #expect(pair.light.alpha > 0 && pair.dark.alpha > 0, "\(token)")
        }
    }
}
