import Foundation
import Testing
@testable import KickCore

/// Phase 9 spec §3: the cycle goal, contraception and regularity in the App Group defaults.
struct CyclePreferencesTests {
    @Test func nothingStoredMeansConceivingForExistingUsers() {
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        CycleSettings(typicalCycleLength: 30).save(to: defaults)
        #expect(CyclePreferences.load(from: defaults) == CyclePreferences(
            goal: .conceiving, contraception: nil, regularity: .unknown, showsFertilityTests: false
        ))
    }

    @Test func everyValueRoundTrips() {
        let defaults = makeTestDefaults()
        let preferences = CyclePreferences(goal: .tracking, contraception: .copperIUD, regularity: .irregular, showsFertilityTests: true)
        preferences.save(to: defaults)
        #expect(defaults.string(forKey: SettingsKey.cycleGoal) == "tracking")
        #expect(defaults.string(forKey: SettingsKey.contraception) == "copperIUD")
        #expect(defaults.string(forKey: SettingsKey.cycleRegularity) == "irregular")
        #expect(defaults.bool(forKey: SettingsKey.cycleShowsFertilityTests))
        #expect(CyclePreferences.load(from: defaults) == preferences)
    }

    @Test func savingNoContraceptionRemovesTheStoredOne() {
        let defaults = makeTestDefaults()
        CyclePreferences(goal: .tracking, contraception: .pill).save(to: defaults)
        CyclePreferences(goal: .tracking, contraception: nil).save(to: defaults)
        #expect(defaults.object(forKey: SettingsKey.contraception) == nil)
        #expect(CyclePreferences.load(from: defaults).contraception == nil)
    }

    @Test func unknownStoredValuesFallBackToTheDefaults() {
        let defaults = makeTestDefaults()
        defaults.set("avoiding", forKey: SettingsKey.cycleGoal)
        defaults.set("patch", forKey: SettingsKey.contraception)
        defaults.set("sometimes", forKey: SettingsKey.cycleRegularity)
        #expect(CyclePreferences.load(from: defaults) == CyclePreferences())
    }

    @Test func onlyThePillImplantInjectionAndHormonalIUDAreHormonal() {
        let hormonal = Contraception.allCases.filter(\.isHormonal)
        #expect(hormonal == [.pill, .implantOrInjection, .hormonalIUD])
        #expect(Contraception.allCases.count == 8)
    }
}
