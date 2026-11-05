import Foundation

extension ContractionCoordinator {
    /// A contraction runs, or the last one started after "Kết thúc theo dõi" (or none was ended yet).
    /// Read-only, for `SiriControls`.
    public var isTrackingEpisode: Bool {
        guard let last = contractions.last else { return false }
        if last.isRunning { return true }
        guard let ended = episodeEndedAt else { return true }
        return last.startedAt > ended
    }
}
