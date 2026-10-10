@preconcurrency import ActivityKit
import Foundation
import KickCore
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "contraction-live-activity")

/// ActivityKit behind `ContractionLiveActivityManaging` (phase 20 spec §4.4),
/// next to the kick one. `staleDate` is 2 hours after the last start: the system
/// marks the activity stale then, and the app ends it (immediately) on the next
/// launch or foreground, on "Kết thúc theo dõi" and on "delete all data".
@MainActor
final class SystemContractionLiveActivityManager: ContractionLiveActivityManaging {
    private var activities: [Activity<ContractionActivityAttributes>] {
        Activity<ContractionActivityAttributes>.activities
    }

    private func activity(for episodeID: UUID) -> Activity<ContractionActivityAttributes>? {
        activities.first { $0.attributes.episodeID == episodeID && ($0.activityState == .active || $0.activityState == .stale) }
    }

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func hasActivity(for episodeID: UUID) -> Bool {
        activity(for: episodeID) != nil
    }

    func start(episodeID: UUID, startedAt: Date, state: ContractionActivityState, staleDate: Date) async {
        for other in activities where other.attributes.episodeID != episodeID {
            await other.end(nil, dismissalPolicy: .immediate)
        }
        guard !hasActivity(for: episodeID) else { return }
        let attributes = ContractionActivityAttributes(episodeID: episodeID, startedAt: startedAt)
        do {
            _ = try Activity.request(attributes: attributes, content: Self.content(state, staleDate: staleDate))
        } catch {
            logger.error("Starting the contraction Live Activity failed: \(error.localizedDescription)")
        }
    }

    func update(episodeID: UUID, state: ContractionActivityState, staleDate: Date) async {
        guard let activity = activity(for: episodeID) else { return }
        await activity.update(Self.content(state, staleDate: staleDate))
    }

    func endAll() async {
        let snapshot = activities
        for activity in snapshot {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func content(_ state: ContractionActivityState, staleDate: Date) -> ActivityContent<ContractionActivityAttributes.ContentState> {
        ActivityContent(
            state: ContractionActivityAttributes.ContentState(
                runningSince: state.runningSince,
                count: state.count,
                lastInterval: state.lastInterval,
                lastDuration: state.lastDuration
            ),
            staleDate: staleDate
        )
    }
}
