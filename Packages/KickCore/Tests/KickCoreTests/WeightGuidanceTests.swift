import Foundation
import Testing
@testable import KickCore

struct WeightGuidanceTests {
    private func expectRange(
        _ range: ClosedRange<Double>,
        _ low: Double,
        _ high: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(range.lowerBound - low) < 1e-4, "\(range)", sourceLocation: sourceLocation)
        #expect(abs(range.upperBound - high) < 1e-4, "\(range)", sourceLocation: sourceLocation)
    }

    @Test func bmiIsRoundedToOneDecimal() {
        #expect(WeightGuidance.bmi(weightKg: 52, heightCm: 160) == 20.3)
        // 63.9 / 1.6² = 24.96 → shown and classified as 25.0.
        #expect(WeightGuidance.bmi(weightKg: 63.9, heightCm: 160) == 25.0)
    }

    @Test func categoriesSwitchAtTheIOMCutOffs() {
        #expect(BMICategory(bmi: 18.4) == .under)
        #expect(BMICategory(bmi: 18.5) == .normal)
        #expect(BMICategory(bmi: 24.9) == .normal)
        #expect(BMICategory(bmi: 25.0) == .over)
        #expect(BMICategory(bmi: 29.9) == .over)
        #expect(BMICategory(bmi: 30.0) == .obese)
        #expect(BMICategory(bmi: WeightGuidance.bmi(weightKg: 63.9, heightCm: 160)) == .over)
    }

    @Test func totalGainByWeek40FollowsIOM2009() {
        #expect(BMICategory.under.totalGainKg == 12.5...18.0)
        #expect(BMICategory.normal.totalGainKg == 11.5...16.0)
        #expect(BMICategory.over.totalGainKg == 7.0...11.5)
        #expect(BMICategory.obese.totalGainKg == 5.0...9.0)
    }

    @Test(arguments: BMICategory.allCases)
    func firstTrimesterIsTheSameForEveryGroup(category: BMICategory) {
        expectRange(WeightGuidance.range(atWeek: 0, category: category), 0, 0)
        expectRange(WeightGuidance.range(atWeek: 6.5, category: category), 0.25, 1.0)
        expectRange(WeightGuidance.range(atWeek: 13, category: category), 0.5, 2.0)
    }

    @Test func week14StartsTowardsEachGroupsTotal() {
        // 0.5 + (low − 0.5) / 27 and 2.0 + (high − 2.0) / 27.
        expectRange(WeightGuidance.range(atWeek: 14, category: .under), 0.94444, 2.59259)
        expectRange(WeightGuidance.range(atWeek: 14, category: .normal), 0.90741, 2.51852)
        expectRange(WeightGuidance.range(atWeek: 14, category: .over), 0.74074, 2.35185)
        expectRange(WeightGuidance.range(atWeek: 14, category: .obese), 0.66667, 2.25926)
    }

    @Test(arguments: BMICategory.allCases)
    func week40IsTheTotalAndLaterWeeksStayThere(category: BMICategory) {
        let total = category.totalGainKg
        expectRange(WeightGuidance.range(atWeek: 40, category: category), total.lowerBound, total.upperBound)
        expectRange(WeightGuidance.range(atWeek: 42, category: category), total.lowerBound, total.upperBound)
        expectRange(WeightGuidance.range(atWeek: -1, category: category), 0, 0)
    }

    @Test func statusComparesTheGainWithThatWeeksRange() {
        // Normal BMI, week 24: 4.98…7.70 kg.
        #expect(WeightGuidance.status(gain: 6.0, week: 24, category: .normal) == .inRange)
        #expect(WeightGuidance.status(gain: 4.9, week: 24, category: .normal) == .below)
        #expect(WeightGuidance.status(gain: 7.8, week: 24, category: .normal) == .above)
        #expect(WeightGuidance.status(gain: 2.0, week: 13, category: .obese) == .inRange)
        #expect(WeightGuidance.status(gain: 0, week: 0, category: .under) == .inRange)
    }
}
