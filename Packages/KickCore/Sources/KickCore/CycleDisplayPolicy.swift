import Foundation

/// What the cycle screens show for a goal and a contraception (phase 9 spec §3.1).
/// Today, the calendar, the day log and the reminders all read it; the forecast
/// itself never changes.
public struct CycleDisplayPolicy: Equatable, Sendable {
    /// The fertile window's name: "Fertile window" while trying to conceive,
    /// "High chance of pregnancy" while tracking.
    public enum FertileLabel: Equatable, Sendable {
        case fertileWindow
        case highPregnancyChance
    }

    /// The predicted bleed's name: a withdrawal bleed on hormonal contraception.
    public enum BleedLabel: Equatable, Sendable {
        case predictedPeriod
        case withdrawalBleed
    }

    /// Today's phase line: the chance of conceiving for every day (`fertility`),
    /// or only the cycle day, with a status on period and fertile days (`nextPeriod`).
    public enum Headline: Equatable, Sendable {
        case fertility
        case nextPeriod
    }

    public let goal: CycleGoal
    public let contraception: Contraception?
    public let showsFertilityTestsOverride: Bool

    public init(goal: CycleGoal, contraception: Contraception?, showsFertilityTestsOverride: Bool = false) {
        self.goal = goal
        self.contraception = contraception
        self.showsFertilityTestsOverride = showsFertilityTestsOverride
    }

    public init(_ preferences: CyclePreferences) {
        self.init(
            goal: preferences.goal,
            contraception: preferences.contraception,
            showsFertilityTestsOverride: preferences.showsFertilityTests
        )
    }

    /// Before phase 9 every cycle-mode user saw this.
    public static let conceiving = CycleDisplayPolicy(goal: .conceiving, contraception: nil)

    /// Only while tracking: trying to conceive ignores a stored contraception.
    private var isHormonal: Bool { goal == .tracking && contraception?.isHormonal == true }

    public var showsFertileWindow: Bool { !isHormonal }
    public var showsOvulation: Bool { !isHormonal }
    public var fertileLabel: FertileLabel { goal == .conceiving ? .fertileWindow : .highPregnancyChance }
    public var showsNotContraceptionNote: Bool { goal == .tracking && !isHormonal }
    /// The LH test and BBT rows of the day log.
    public var showsLHAndBBT: Bool { goal == .conceiving || showsFertilityTestsOverride }
    public var predictedBleedLabel: BleedLabel { isHormonal ? .withdrawalBleed : .predictedPeriod }
    public var headline: Headline { goal == .conceiving ? .fertility : .nextPeriod }

    /// Tracking: only "period due tomorrow" and "period late".
    public var reminderKinds: Set<CycleReminderKind> {
        goal == .conceiving ? Set(CycleReminderKind.allCases) : [.period, .late]
    }

    /// A day's colour and wording on screen: fertile and ovulation days look
    /// like any other day when the fertile window is hidden.
    public func visibleStatus(_ status: CycleDayStatus) -> CycleDayStatus {
        switch status {
        case .fertile, .peak: showsFertileWindow ? status : .low
        case .period, .low: status
        }
    }
}
