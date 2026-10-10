import ActivityKit
import Foundation
import KickCore

/// The contraction Live Activity (phase 20 spec §4.4), one per episode; it runs
/// alongside the kick one (`KickActivityAttributes`).
struct ContractionActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        /// Start of the running contraction; nil while resting.
        var runningSince: Date?
        /// Contractions in the episode, the running one included.
        var count: Int
        /// The newest contraction's interval; nil for the first of the episode.
        var lastInterval: TimeInterval?
        /// The newest completed contraction's length.
        var lastDuration: TimeInterval?
        /// The timer screen's alert for the real week: a short urgent line on
        /// the Lock Screen for a mother who never opens the app.
        var alert: ContractionAlert
    }

    var episodeID: UUID
    var startedAt: Date
}
