import Foundation

/// The mother's own cycle numbers, kept in `AppGroup.defaults` (not synced).
public struct CycleSettings: Equatable, Sendable {
    public static let cycleLengthRange = 21...45
    public static let periodLengthRange = 2...10
    public static let defaultCycleLength = 28
    public static let defaultPeriodLength = 5

    public private(set) var typicalCycleLength: Int
    public private(set) var typicalPeriodLength: Int
    public var remindersEnabled: Bool

    /// Lengths outside the allowed ranges are clamped into them.
    public init(
        typicalCycleLength: Int = CycleSettings.defaultCycleLength,
        typicalPeriodLength: Int = CycleSettings.defaultPeriodLength,
        remindersEnabled: Bool = true
    ) {
        self.typicalCycleLength = Self.clamp(typicalCycleLength, to: Self.cycleLengthRange)
        self.typicalPeriodLength = Self.clamp(typicalPeriodLength, to: Self.periodLengthRange)
        self.remindersEnabled = remindersEnabled
    }

    public static func load(from defaults: UserDefaults) -> CycleSettings {
        CycleSettings(
            typicalCycleLength: defaults.object(forKey: SettingsKey.typicalCycleLength) == nil
                ? defaultCycleLength : defaults.integer(forKey: SettingsKey.typicalCycleLength),
            typicalPeriodLength: defaults.object(forKey: SettingsKey.typicalPeriodLength) == nil
                ? defaultPeriodLength : defaults.integer(forKey: SettingsKey.typicalPeriodLength),
            remindersEnabled: defaults.object(forKey: SettingsKey.cycleRemindersEnabled) == nil
                ? true : defaults.bool(forKey: SettingsKey.cycleRemindersEnabled)
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(typicalCycleLength, forKey: SettingsKey.typicalCycleLength)
        defaults.set(typicalPeriodLength, forKey: SettingsKey.typicalPeriodLength)
        defaults.set(remindersEnabled, forKey: SettingsKey.cycleRemindersEnabled)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
