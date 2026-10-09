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
