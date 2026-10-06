import Foundation

/// IOM 2009 pre-pregnancy BMI groups (standard WHO cut-offs, not the Asian ones:
/// the doctor decides, see docs/content-review-for-doctor.md §8).
public enum BMICategory: String, Sendable, CaseIterable {
    case under
    case normal
    case over
    case obese

    /// `bmi` as shown, one decimal: < 18.5, 18.5–24.9, 25.0–29.9, ≥ 30.0.
    public init(bmi: Double) {
        switch bmi {
        case ..<18.5: self = .under
        case ..<25.0: self = .normal
        case ..<30.0: self = .over
        default: self = .obese
        }
    }

    /// Recommended total gain by week 40, single pregnancy (IOM 2009).
    public var totalGainKg: ClosedRange<Double> {
        switch self {
        case .under: 12.5...18.0
        case .normal: 11.5...16.0
        case .over: 7.0...11.5
        case .obese: 5.0...9.0
        }
    }
}

public enum WeightStatus: String, Sendable, CaseIterable {
    case below
    case inRange
    case above
}

/// The recommended gain at a given week (spec §2.4): 0 → 0.5–2.0 kg linearly
/// over weeks 0–13 (every group), then linearly to the group's week-40 total,
/// then flat.
public enum WeightGuidance {
    public static let firstTrimesterEndWeek = 13.0
    public static let termWeek = 40.0
    public static let firstTrimesterGainKg: ClosedRange<Double> = 0.5...2.0

    /// kg / m², one decimal (as shown and classified).
    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let meters = heightCm / 100
        return ((weightKg / (meters * meters)) * 10).rounded() / 10
    }

    /// Recommended gain since pre-pregnancy at `week` (decimal weeks).
    public static func range(atWeek week: Double, category: BMICategory) -> ClosedRange<Double> {
        let week = min(max(week, 0), termWeek)
        let early = firstTrimesterGainKg
        if week <= firstTrimesterEndWeek {
            let share = week / firstTrimesterEndWeek
            return (early.lowerBound * share)...(early.upperBound * share)
        }
        let share = (week - firstTrimesterEndWeek) / (termWeek - firstTrimesterEndWeek)
        let total = category.totalGainKg
        let low = early.lowerBound + share * (total.lowerBound - early.lowerBound)
        let high = early.upperBound + share * (total.upperBound - early.upperBound)
        return low...high
    }

    public static func status(gain: Double, week: Double, category: BMICategory) -> WeightStatus {
        let range = range(atWeek: week, category: category)
        if gain < range.lowerBound - 1e-9 { return .below }
        if gain > range.upperBound + 1e-9 { return .above }
        return .inRange
    }
}
