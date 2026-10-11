import Foundation
import KickCore
@preconcurrency import UserNotifications

/// Used with -uiTesting so no system permission prompt interrupts UI tests.
@MainActor
final class DisabledNotificationCenter: NotificationCenterClient {
    func add(_ request: UNNotificationRequest) async throws {}
    func removePending(ids: [String]) {}
    func removeDelivered(ids: [String]) {}
    func requestAuthorization() async throws -> Bool { false }
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func pendingRequestIDs() async -> [String] { [] }
}

@MainActor
final class NoopLiveActivityManager: LiveActivityManaging {
    var isAvailable: Bool { false }
    func hasActivity(for sessionID: UUID) -> Bool { false }
    func start(sessionID: UUID, startedAt: Date, count: Int) async {}
    func update(sessionID: UUID, count: Int, completedAt: Date?) async {}
    func end(sessionID: UUID, dismissAfter: TimeInterval) async {}
    func endAll() async {}
}

/// The contraction Live Activity in UI tests: no system prompt or activity.
/// Reported as allowed, so the timer screen's "turn on Live Activities" hint
/// shows only with `-contractionLiveActivitiesOff`.
@MainActor
final class NoopContractionLiveActivityManager: ContractionLiveActivityManaging {
    let isAvailable: Bool
    init(isAvailable: Bool) { self.isAvailable = isAvailable }
    func hasActivity(for episodeID: UUID) -> Bool { false }
    func start(episodeID: UUID, startedAt: Date, state: ContractionActivityState, staleDate: Date) async {}
    func update(episodeID: UUID, state: ContractionActivityState, staleDate: Date) async {}
    func endAll() async {}
}
