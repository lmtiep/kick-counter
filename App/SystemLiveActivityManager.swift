@preconcurrency import ActivityKit
import Foundation
import KickCore
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "live-activity")

private extension ActivityState {
    /// `.active` is the common case; ActivityKit moves an activity to `.stale`
    /// once its `staleDate` (our overdue threshold) passes, but it is still
    /// live — updatable and endable — until dismissed/ended.
    var isLive: Bool {
        self == .active || self == .stale
    }
}

@MainActor
final class SystemLiveActivityManager: LiveActivityManaging {
    private var activities: [Activity<KickActivityAttributes>] {
        Activity<KickActivityAttributes>.activities
    }

    private func activity(for sessionID: UUID) -> Activity<KickActivityAttributes>? {
        activities.first { $0.attributes.sessionID == sessionID && $0.activityState.isLive }
    }

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func hasActivity(for sessionID: UUID) -> Bool {
        activity(for: sessionID) != nil
    }

    func start(sessionID: UUID, startedAt: Date, count: Int) async {
        for other in activities where other.attributes.sessionID != sessionID {
            await other.end(nil, dismissalPolicy: .immediate)
        }
        guard !hasActivity(for: sessionID) else { return }
        let attributes = KickActivityAttributes(sessionID: sessionID, startedAt: startedAt)
        let content = ActivityContent(
            state: KickActivityAttributes.ContentState(count: count, completedAt: nil),
            staleDate: startedAt.addingTimeInterval(SessionRules.overdueThreshold)
        )
        do {
            _ = try Activity.request(attributes: attributes, content: content)
        } catch {
            logger.error("Starting Live Activity failed: \(error.localizedDescription)")
        }
    }

    func update(sessionID: UUID, count: Int, completedAt: Date?) async {
        guard let activity = activity(for: sessionID) else { return }
        let staleDate = completedAt == nil
            ? activity.attributes.startedAt.addingTimeInterval(SessionRules.overdueThreshold)
            : nil
        await activity.update(ActivityContent(
            state: KickActivityAttributes.ContentState(count: count, completedAt: completedAt),
            staleDate: staleDate
        ))
    }

    func end(sessionID: UUID, dismissAfter: TimeInterval) async {
        guard let activity = activity(for: sessionID) else { return }
        let policy: ActivityUIDismissalPolicy = dismissAfter <= 0
            ? .immediate
            : .after(Date.now.addingTimeInterval(dismissAfter))
        await activity.end(activity.content, dismissalPolicy: policy)
    }

    func endAll(force: Bool) async {
        let snapshot = activities
        for activity in snapshot where force || activity.content.state.completedAt == nil {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
