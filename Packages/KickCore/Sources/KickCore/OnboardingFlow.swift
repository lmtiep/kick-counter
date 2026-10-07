import Foundation

/// The first question of onboarding (phase 9 spec §4.1, step 2).
public enum OnboardingGoal: String, Sendable, CaseIterable {
    case tracking
    case conceiving
    case pregnant

    public var mode: AppMode { self == .pregnant ? .pregnant : .tryingToConceive }

    /// nil for pregnancy.
    public var cycleGoal: CycleGoal? {
        switch self {
        case .tracking: .tracking
        case .conceiving: .conceiving
        case .pregnant: nil
        }
    }

    /// The goal a stored mode and cycle goal stand for (onboarding replay).
    public init?(mode: AppMode, cycleGoal: CycleGoal) {
        switch mode {
        case .tryingToConceive: self = cycleGoal == .tracking ? .tracking : .conceiving
        case .pregnant: self = .pregnant
        case .partner: return nil
        }
    }
}

public enum OnboardingStep: String, Sendable, CaseIterable {
    case welcome
    case goal
    case lastPeriod
    case periodLength
    case cycleLength
    case regularity
    case contraception
    case dueDate
    case result
}

/// What the result screen says about the next period.
public enum OnboardingPrediction: Equatable, Sendable {
    /// "Your next period should start around …".
    case nextPeriod(Date)
    /// The entered period is older than one cycle: about this many days late.
    case late(days: Int)
}

/// What onboarding saves (`OnboardingFlow.finish()`); the view writes it with
/// the existing stores.
public enum OnboardingOutcome: Equatable, Sendable {
    case cycle(
        goal: CycleGoal,
        settings: CycleSettings,
        firstPeriodStart: Date?,
        regularity: CycleRegularity,
        contraception: Contraception?
    )
    /// `dates` is nil when the due date step was skipped.
    case pregnant(dates: PregnancyDateSelection?)

    public var mode: AppMode {
        switch self {
        case .cycle: .tryingToConceive
        case .pregnant: .pregnant
        }
    }
}

/// Onboarding's answers and step order (phase 9 spec §3.2). Pure: the view
/// shows `step`, edits the answers and calls `next()`, `skip()` and `back()`.
///
/// - tracking: welcome, goal, lastPeriod, periodLength, cycleLength, regularity, contraception, result
/// - conceiving: welcome, goal, lastPeriod, periodLength, cycleLength, regularity, result
/// - pregnant: welcome, goal, dueDate, result
public struct OnboardingFlow: Equatable, Sendable {
    public private(set) var step: OnboardingStep = .welcome
    /// Changing the goal off the goal step (e.g. a replay) would otherwise
    /// strand `step` on a step the new branch doesn't have; moving back to
    /// `.goal` keeps the flow always on a valid step.
    public var goal: OnboardingGoal? {
        didSet { if !steps.contains(step) { step = .goal } }
    }
    /// The first day of the last period; nil after "I don't remember" or a skip.
    public var lastPeriodStart: Date?
    public var periodLength: Int {
        didSet { periodLength = Self.clamp(periodLength, to: CycleSettings.periodLengthRange) }
    }
    public var cycleLength: Int {
        didSet { cycleLength = Self.clamp(cycleLength, to: CycleSettings.cycleLengthRange) }
    }
    public var regularity: CycleRegularity
    /// nil when not answered (skipped), as in `CyclePreferences`.
    public var contraception: Contraception?
    /// The due date step's value; nil once that step is skipped.
    public var pregnancyDates: PregnancyDateSelection?
    /// Kept from the stored settings: onboarding has no reminder switch.
    public let remindersEnabled: Bool
    /// What `periodLength`/`cycleLength` started from, so skipping them
    /// restores this instead of the app-wide default (a replay must not
    /// silently change a stored 30/6 to 28/5).
    private let initialPeriodLength: Int
    private let initialCycleLength: Int

    public init(
        goal: OnboardingGoal? = nil,
        lastPeriodStart: Date?,
        settings: CycleSettings = CycleSettings(),
        regularity: CycleRegularity = .unknown,
        contraception: Contraception? = nil,
        pregnancyDates: PregnancyDateSelection?
    ) {
        self.goal = goal
        self.lastPeriodStart = lastPeriodStart
        periodLength = settings.typicalPeriodLength
        cycleLength = settings.typicalCycleLength
        initialPeriodLength = settings.typicalPeriodLength
        initialCycleLength = settings.typicalCycleLength
        remindersEnabled = settings.remindersEnabled
        self.regularity = regularity
        self.contraception = contraception
        self.pregnancyDates = pregnancyDates
    }

    public static func steps(for goal: OnboardingGoal) -> [OnboardingStep] {
        switch goal {
        case .tracking: [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .contraception, .result]
        case .conceiving: [.welcome, .goal, .lastPeriod, .periodLength, .cycleLength, .regularity, .result]
        case .pregnant: [.welcome, .goal, .dueDate, .result]
        }
    }

    /// The chosen branch; before a goal is chosen, the longest one (tracking),
    /// so the progress never claims fewer steps than there may be.
    public var steps: [OnboardingStep] { Self.steps(for: goal ?? .tracking) }

    /// 1-based, for "Step 3 of 8".
    public var stepNumber: Int { (steps.firstIndex(of: step) ?? 0) + 1 }
    public var stepCount: Int { steps.count }

    /// Every step but welcome and result asks something and can be skipped.
    public var isQuestion: Bool { step != .welcome && step != .result }
    public var canGoBack: Bool { step != .welcome }
    /// The goal step needs an answer before "Continue" (or "Skip").
    public var canContinue: Bool { step != .goal || goal != nil }

    public mutating func next() {
        guard canContinue, let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    public mutating func back() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    /// "Skip" / "Not sure": the step's answer goes back to its default, then the
    /// next step. A skipped goal means pregnancy, as before phase 9.
    public mutating func skip() {
        switch step {
        case .welcome, .result: return
        case .goal: if goal == nil { goal = .pregnant }
        case .lastPeriod: lastPeriodStart = nil
        case .periodLength: periodLength = initialPeriodLength
        case .cycleLength: cycleLength = initialCycleLength
        case .regularity: regularity = .unknown
        case .contraception: contraception = nil
        case .dueDate: pregnancyDates = nil
        }
        next()
    }

    /// The typical lengths as answered (clamped by `CycleSettings`).
    public var settings: CycleSettings {
        CycleSettings(typicalCycleLength: cycleLength, typicalPeriodLength: periodLength, remindersEnabled: remindersEnabled)
    }

    /// nil without a last period (the result asks her to log the next one).
    public func prediction(now: Date, calendar: Calendar = .current) -> OnboardingPrediction? {
        guard let lastPeriodStart else { return nil }
        let period = CycleRules.assumedPeriod(
            startingOn: lastPeriodStart, typicalLength: periodLength, today: now, calendar: calendar
        )
        guard let forecast = CyclePredictor.forecast(
            periods: [period], logs: [], settings: settings, now: now, calendar: calendar
        ) else { return nil }
        return forecast.daysLate > 0 ? .late(days: forecast.daysLate) : .nextPeriod(forecast.nextPeriodStart)
    }

    /// What to save. Skipping the goal step makes it pregnancy.
    public func finish() -> OnboardingOutcome {
        switch goal ?? .pregnant {
        case .pregnant:
            return .pregnant(dates: pregnancyDates)
        case let cycleBranch:
            let isTracking = cycleBranch == .tracking
            return .cycle(
                goal: isTracking ? .tracking : .conceiving,
                settings: settings,
                firstPeriodStart: lastPeriodStart,
                regularity: regularity,
                contraception: isTracking ? contraception : nil
            )
        }
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
