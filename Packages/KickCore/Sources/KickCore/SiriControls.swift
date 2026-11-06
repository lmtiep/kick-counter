import Foundation

/// What a command did, for the short generic dialog (no numbers, no medical wording).
public enum SiriResult: Equatable, Sendable {
    case kickRecorded
    case contractionStarted
    case contractionStopped
    case contractionDiscarded
    case trackingEnded
    case nothingToEnd
    case needsPregnancyMode
    /// After a pregnancy ended: "Luna Mom is tracking your cycle."
    case trackingCycle
    case failed
}

/// Runs a `SiriCommand` on the app's coordinators: the entry point of the App Intents (Siri, Shortcuts,
/// Spotlight, Action Button, Control Center). Reads the current state, asks `SiriPlanner`, then acts.
@MainActor
public struct SiriControls {
    private let kicks: KickCoordinator
    private let contractions: ContractionCoordinator
    private let defaults: UserDefaults

    public init(kicks: KickCoordinator, contractions: ContractionCoordinator, defaults: UserDefaults) {
        self.kicks = kicks
        self.contractions = contractions
        self.defaults = defaults
    }

    @discardableResult
    public func run(_ command: SiriCommand) async -> SiriResult {
        let mode = AppMode.load(from: defaults)
        let onboarded = defaults.bool(forKey: SettingsKey.hasCompletedOnboarding)
        // The intent may launch the app in the background: read the stores first.
        if mode == .pregnant, onboarded {
            switch command {
            case .recordKick: await kicks.load()
            case .timeContraction, .stopContractions: await contractions.load()
            }
        }
        let state = SiriState(
            mode: mode,
            onboarded: onboarded,
            contractionRunning: contractions.running != nil,
            contractionEpisodeActive: contractions.isTrackingEpisode,
            pregnancyEnded: PregnancyEndState.load(from: defaults) != nil
        )
        switch SiriPlanner.plan(command, state) {
        case .needsPregnancyMode:
            return .needsPregnancyMode
        case .trackingCycle:
            return .trackingCycle
        case .recordKick:
            switch await kicks.recordKick() {
            // A debounced tap means a kick was recorded a moment ago.
            case .added, .completed, .ignoredDebounce: return .kickRecorded
            case .ignoredInactive: return .failed
            }
        case .toggleContraction:
            switch await contractions.toggle() {
            case .started: return .contractionStarted
            case .stopped: return .contractionStopped
            case .discarded: return .contractionDiscarded
            case nil: return .failed
            }
        case .endContractionTracking:
            return await contractions.endEpisode() ? .trackingEnded : .failed
        case .nothingToEnd:
            return .nothingToEnd
        }
    }
}
