import Foundation

/// What a Siri phrase, Shortcut or Control asks for (1.1 spec: Siri, Action Button and Control Center).
public enum SiriCommand: String, CaseIterable, Sendable {
    case recordKick
    case timeContraction
    case stopContractions
}

/// What the planner needs to know: the mode and the state of the two counters.
public struct SiriState: Equatable, Sendable {
    public var mode: AppMode
    public var onboarded: Bool
    public var contractionRunning: Bool
    public var contractionEpisodeActive: Bool
    /// A pregnancy has ended (1.1 item 4): the answer never mentions pregnancy mode.
    public var pregnancyEnded: Bool

    public init(
        mode: AppMode, onboarded: Bool, contractionRunning: Bool, contractionEpisodeActive: Bool, pregnancyEnded: Bool = false
    ) {
        self.mode = mode
        self.onboarded = onboarded
        self.contractionRunning = contractionRunning
        self.contractionEpisodeActive = contractionEpisodeActive
        self.pregnancyEnded = pregnancyEnded
    }
}

public enum SiriPlan: Equatable, Sendable {
    /// One kick, as the Live Activity "+" button: starts a session if none runs, else adds to it.
    case recordKick
    /// Starts a contraction, or stops the running one.
    case toggleContraction
    case endContractionTracking
    case nothingToEnd
    /// Not in pregnancy mode (or not set up yet): nothing starts.
    case needsPregnancyMode
    /// After a pregnancy ended (cycle mode): a neutral "Luna Mom is tracking your
    /// cycle", never a nudge toward pregnancy mode.
    case trackingCycle
}

/// The pure decision: command and state in, plan out.
public enum SiriPlanner {
    public static func plan(_ command: SiriCommand, _ state: SiriState) -> SiriPlan {
        guard state.mode == .pregnant, state.onboarded else {
            return state.pregnancyEnded && state.mode != .pregnant ? .trackingCycle : .needsPregnancyMode
        }
        switch command {
        case .recordKick:
            return .recordKick
        case .timeContraction:
            return .toggleContraction
        case .stopContractions:
            return state.contractionRunning || state.contractionEpisodeActive ? .endContractionTracking : .nothingToEnd
        }
    }
}
