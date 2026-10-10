import Foundation

/// What the contraction Live Activity shows (phase 20 spec §4.4); the app maps
/// it to `ContractionActivityAttributes.ContentState`.
public struct ContractionActivityState: Equatable, Sendable {
    /// Start of the running contraction; nil while resting.
    public var runningSince: Date?
    /// Contractions in the episode, the running one included.
    public var count: Int
    /// The newest contraction's interval; nil for the first of the episode.
    public var lastInterval: TimeInterval?
    /// The newest completed contraction's duration.
    public var lastDuration: TimeInterval?

    public init(runningSince: Date?, count: Int, lastInterval: TimeInterval?, lastDuration: TimeInterval?) {
        self.runningSince = runningSince
        self.count = count
        self.lastInterval = lastInterval
        self.lastDuration = lastDuration
    }
}

/// Seam over ActivityKit for the contraction Live Activity, separate from the
/// kick one (`LiveActivityManaging`) so both can run together. The real
/// implementation lives in the app target. One activity per episode, keyed by
/// the episode's id (`ContractionEpisode.id`).
@MainActor
public protocol ContractionLiveActivityManaging: AnyObject {
    /// False when the user has turned Live Activities off in Settings.
    var isAvailable: Bool { get }
    func hasActivity(for episodeID: UUID) -> Bool
    /// Starts an activity for the episode, ending any other contraction activity.
    /// `staleDate` is 2 hours after the last start (`ContractionRules.episodeGap`).
    func start(episodeID: UUID, startedAt: Date, state: ContractionActivityState, staleDate: Date) async
    /// No-op when that episode has no activity.
    func update(episodeID: UUID, state: ContractionActivityState, staleDate: Date) async
    /// Ends every contraction activity immediately.
    func endAll() async
}
