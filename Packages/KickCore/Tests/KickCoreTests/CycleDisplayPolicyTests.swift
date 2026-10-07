import Foundation
import Testing
@testable import KickCore

/// Phase 9 spec §3.1: what each goal × contraception shows.
struct CycleDisplayPolicyTests {
    @Test func conceivingShowsEverythingWhateverTheContraception() {
        for contraception in [nil] + Contraception.allCases.map(Optional.some) {
            let policy = CycleDisplayPolicy(goal: .conceiving, contraception: contraception)
            #expect(policy.showsFertileWindow)
            #expect(policy.showsOvulation)
            #expect(policy.fertileLabel == .fertileWindow)
            #expect(policy.showsNotContraceptionNote == false)
            #expect(policy.showsLHAndBBT)
            #expect(policy.predictedBleedLabel == .predictedPeriod)
            #expect(policy.headline == .fertility)
            #expect(policy.reminderKinds == [.fertile, .period, .late])
        }
    }

    @Test func trackingWithoutHormonalContraceptionLabelsTheWindowAndWarns() {
        let nonHormonal: [Contraception?] = [nil, .none, .condom, .copperIUD, .fertilityAwarenessOrWithdrawal, .otherOrPrivate]
        for contraception in nonHormonal {
            let policy = CycleDisplayPolicy(goal: .tracking, contraception: contraception)
            #expect(policy.showsFertileWindow)
            #expect(policy.showsOvulation)
            #expect(policy.fertileLabel == .highPregnancyChance)
            #expect(policy.showsNotContraceptionNote)
            #expect(policy.showsLHAndBBT == false)
            #expect(policy.predictedBleedLabel == .predictedPeriod)
            #expect(policy.headline == .nextPeriod)
            #expect(policy.reminderKinds == [.period, .late])
        }
    }

    @Test func trackingWithHormonalContraceptionHidesTheWindow() {
        for contraception in [Contraception.pill, .implantOrInjection, .hormonalIUD] {
            let policy = CycleDisplayPolicy(goal: .tracking, contraception: contraception)
            #expect(policy.showsFertileWindow == false)
            #expect(policy.showsOvulation == false)
            #expect(policy.showsNotContraceptionNote == false)
            #expect(policy.showsLHAndBBT == false)
            #expect(policy.predictedBleedLabel == .withdrawalBleed)
            #expect(policy.headline == .nextPeriod)
            #expect(policy.reminderKinds == [.period, .late])
        }
    }

    @Test func theProfileOverrideShowsLHAndBBTWhileTracking() {
        let policy = CycleDisplayPolicy(goal: .tracking, contraception: .pill, showsFertilityTestsOverride: true)
        #expect(policy.showsLHAndBBT)
        #expect(CycleDisplayPolicy(CyclePreferences(goal: .tracking, showsFertilityTests: true)).showsLHAndBBT)
    }

    @Test func hiddenFertileDaysLookLikeAnyOtherDay() {
        let hormonal = CycleDisplayPolicy(goal: .tracking, contraception: .hormonalIUD)
        #expect(hormonal.visibleStatus(.fertile) == .low)
        #expect(hormonal.visibleStatus(.peak) == .low)
        #expect(hormonal.visibleStatus(.period(isPredicted: true)) == .period(isPredicted: true))
        #expect(hormonal.visibleStatus(.low) == .low)
        let tracking = CycleDisplayPolicy(goal: .tracking, contraception: .condom)
        #expect(tracking.visibleStatus(.peak) == .peak)
        #expect(CycleDisplayPolicy.conceiving.visibleStatus(.fertile) == .fertile)
    }

    @Test func thePolicyComesFromThePreferences() {
        let preferences = CyclePreferences(goal: .tracking, contraception: .pill, regularity: .regular)
        #expect(CycleDisplayPolicy(preferences) == CycleDisplayPolicy(goal: .tracking, contraception: .pill))
        #expect(CycleDisplayPolicy(CyclePreferences()) == .conceiving)
    }
}
