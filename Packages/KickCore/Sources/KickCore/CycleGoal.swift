import Foundation

/// What the cycle mode is for (phase 9 spec §3): following the cycle, or trying
/// to conceive. Same data, calendar and predictions; only the presentation changes.
public enum CycleGoal: String, Sendable, CaseIterable {
    case tracking
    case conceiving
}

/// The contraception the mother uses, asked on the tracking branch only.
/// The app only tracks it: it changes what Today and the calendar show.
public enum Contraception: String, Sendable, CaseIterable {
    case none
    case condom
    case pill
    case implantOrInjection
    case hormonalIUD
    case copperIUD
    case fertilityAwarenessOrWithdrawal
    case otherOrPrivate

    /// Hormonal methods usually stop ovulation, so the fertile window and
    /// ovulation are hidden and the bleed is a withdrawal bleed.
    public var isHormonal: Bool {
        switch self {
        case .pill, .implantOrInjection, .hormonalIUD: true
        case .none, .condom, .copperIUD, .fertilityAwarenessOrWithdrawal, .otherOrPrivate: false
        }
    }
}

public enum CycleRegularity: String, Sendable, CaseIterable {
    case regular
    case irregular
    case unknown
}

/// The cycle mode's goal and answers, kept in `AppGroup.defaults` next to
/// `CycleSettings` (not synced). Every value loads with a default:
/// - `goal`: `.conceiving`, so cycle-mode users from before phase 9 keep today's behaviour;
/// - `contraception`: nil (not asked), treated like `.none`;
/// - `regularity`: `.unknown`;
/// - `showsFertilityTests`: false (Profile's "Show ovulation tests & temperature").
public struct CyclePreferences: Equatable, Sendable {
    public var goal: CycleGoal
    public var contraception: Contraception?
    public var regularity: CycleRegularity
    /// Shows the LH test and BBT rows in the day log while tracking.
    public var showsFertilityTests: Bool

    public init(
        goal: CycleGoal = .conceiving,
        contraception: Contraception? = nil,
        regularity: CycleRegularity = .unknown,
        showsFertilityTests: Bool = false
    ) {
        self.goal = goal
        self.contraception = contraception
        self.regularity = regularity
        self.showsFertilityTests = showsFertilityTests
    }

    public static func load(from defaults: UserDefaults) -> CyclePreferences {
        CyclePreferences(
            goal: defaults.string(forKey: SettingsKey.cycleGoal).flatMap(CycleGoal.init(rawValue:)) ?? .conceiving,
            contraception: defaults.string(forKey: SettingsKey.contraception).flatMap(Contraception.init(rawValue:)),
            regularity: defaults.string(forKey: SettingsKey.cycleRegularity).flatMap(CycleRegularity.init(rawValue:)) ?? .unknown,
            showsFertilityTests: defaults.bool(forKey: SettingsKey.cycleShowsFertilityTests)
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(goal.rawValue, forKey: SettingsKey.cycleGoal)
        if let contraception {
            defaults.set(contraception.rawValue, forKey: SettingsKey.contraception)
        } else {
            defaults.removeObject(forKey: SettingsKey.contraception)
        }
        defaults.set(regularity.rawValue, forKey: SettingsKey.cycleRegularity)
        defaults.set(showsFertilityTests, forKey: SettingsKey.cycleShowsFertilityTests)
    }
}
