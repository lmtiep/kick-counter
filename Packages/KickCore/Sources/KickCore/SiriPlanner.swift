import Foundation

/// What a Siri phrase, Shortcut or Control asks for (1.1 spec: Siri, Action Button and Control Center).
public enum SiriCommand: String, CaseIterable, Sendable {
    case startKicks
    case timeContraction
    case stopContractions
}

/// What the planner needs to know: the mode and the state of the two counters.
public struct SiriState: Equatable, Sendable {
    public var mode: AppMode
    public var onboarded: Bool
    public var kickSessionActive: Bool
    public var contractionRunning: Bool
    public var contractionEpisodeActive: Bool

    public init(mode: AppMode, onboarded: Bool, kickSessionActive: Bool, contractionRunning: Bool, contractionEpisodeActive: Bool) {
        self.mode = mode
        self.onboarded = onboarded
        self.kickSessionActive = kickSessionActive
        self.contractionRunning = contractionRunning
        self.contractionEpisodeActive = contractionEpisodeActive
    }
}

public enum SiriPlan: Equatable, Sendable {
    /// No session: the first kick starts one.
    case recordKick
    /// A session runs: nothing is added, so a repeated phrase never inflates a count.
    case kickAlreadyRunning
    /// Starts a contraction, or stops the running one.
    case toggleContraction
    case endContractionTracking
    case nothingToEnd
    /// Not in pregnancy mode (or not set up yet): nothing starts.
    case needsPregnancyMode
}

/// The pure decision: command and state in, plan out.
public enum SiriPlanner {
    public static func plan(_ command: SiriCommand, _ state: SiriState) -> SiriPlan {
        guard state.mode == .pregnant, state.onboarded else { return .needsPregnancyMode }
        switch command {
        case .startKicks:
            return state.kickSessionActive ? .kickAlreadyRunning : .recordKick
        case .timeContraction:
            return .toggleContraction
        case .stopContractions:
            return state.contractionRunning || state.contractionEpisodeActive ? .endContractionTracking : .nothingToEnd
        }
    }
}
