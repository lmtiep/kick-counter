import Foundation

public enum MaternalProfileError: Error, Equatable, Sendable {
    case invalidWeight
    case invalidHeight
}

/// Pre-pregnancy weight and height, kept in `AppGroup.defaults` (not synced),
/// like `PregnancyProfile`. 0 means "not set" (so `@AppStorage` views update).
public struct MaternalProfile: Equatable, Sendable {
    public static let preWeightRange = WeightRules.kgRange
    public static let heightRange: ClosedRange<Double> = 120.0...220.0

    public var preWeightKg: Double?
    public var heightCm: Double?

    public init(preWeightKg: Double? = nil, heightCm: Double? = nil) {
        self.preWeightKg = preWeightKg
        self.heightCm = heightCm
    }

    /// Only with both values.
    public var bmi: Double? {
        guard let preWeightKg, let heightCm else { return nil }
        return WeightGuidance.bmi(weightKg: preWeightKg, heightCm: heightCm)
    }

    /// No height (or no pre-pregnancy weight) → no group, no range, no status.
    public var category: BMICategory? { bmi.map(BMICategory.init(bmi:)) }

    public static func load(from defaults: UserDefaults) -> MaternalProfile {
        let weight = defaults.double(forKey: SettingsKey.maternalPreWeightKg)
        let height = defaults.double(forKey: SettingsKey.maternalHeightCm)
        return MaternalProfile(
            preWeightKg: preWeightRange.contains(weight) ? weight : nil,
            heightCm: heightRange.contains(height) ? height : nil
        )
    }

    /// Rounds both to one decimal; throws before writing anything when either is out of range.
    public func save(to defaults: UserDefaults) throws {
        let weight = preWeightKg.map(WeightRules.rounded)
        let height = heightCm.map(WeightRules.rounded)
        if let weight, !Self.preWeightRange.contains(weight) { throw MaternalProfileError.invalidWeight }
        if let height, !Self.heightRange.contains(height) { throw MaternalProfileError.invalidHeight }
        defaults.set(weight ?? 0, forKey: SettingsKey.maternalPreWeightKg)
        defaults.set(height ?? 0, forKey: SettingsKey.maternalHeightCm)
    }
}
