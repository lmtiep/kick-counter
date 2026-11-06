import Foundation

extension ContractionCoordinator {
    /// A current episode exists: not ended, and within `ContractionRules.episodeGap` of the last
    /// contraction. Read-only, for `SiriControls`.
    public var isTrackingEpisode: Bool {
        stats(week: nil).currentEpisode != nil
    }
}
