import Foundation
import OSLog
@preconcurrency import UserNotifications

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "notifications")

public struct NotificationText: Equatable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    func makeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }
}

/// Seam over UNUserNotificationCenter so scheduling can be unit tested.
@MainActor
public protocol NotificationCenterClient: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func removePending(ids: [String])
    func removeDelivered(ids: [String])
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func pendingRequestIDs() async -> [String]
}

@MainActor
public final class SystemNotificationCenter: NotificationCenterClient {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    public func removePending(ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    public func removeDelivered(ids: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    public func pendingRequestIDs() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }
}

@MainActor
public final class NotificationScheduler {
    public static let dailyReminderID = "daily-reminder"

    public static func overdueID(for sessionID: UUID) -> String {
        "overdue-\(sessionID.uuidString)"
    }

    let center: NotificationCenterClient

    public init(center: NotificationCenterClient) {
        self.center = center
    }

    public func isAuthorized() async -> Bool {
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    /// True only when the user has explicitly turned notifications off
    /// (not when they have never been asked).
    public func isDenied() async -> Bool {
        await center.authorizationStatus() == .denied
    }

    /// Prompts only if the user has never been asked; otherwise reports the current status.
    public func requestAuthorizationIfNeeded() async -> Bool {
        guard await center.authorizationStatus() == .notDetermined else { return await isAuthorized() }
        do {
            return try await center.requestAuthorization()
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    public func scheduleDailyReminder(hour: Int, minute: Int, text: NotificationText) async throws {
        center.removePending(ids: [Self.dailyReminderID])
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try await center.add(UNNotificationRequest(identifier: Self.dailyReminderID, content: text.makeContent(), trigger: trigger))
    }

    public func cancelDailyReminder() {
        center.removePending(ids: [Self.dailyReminderID])
    }

    public func scheduleOverdueAlert(sessionID: UUID, startedAt: Date, now: Date, text: NotificationText) async throws {
        let fireIn = startedAt.addingTimeInterval(SessionRules.overdueThreshold).timeIntervalSince(now)
        guard fireIn > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
        try await center.add(UNNotificationRequest(identifier: Self.overdueID(for: sessionID), content: text.makeContent(), trigger: trigger))
    }

    public func cancelOverdueAlert(sessionID: UUID) {
        center.removePending(ids: [Self.overdueID(for: sessionID)])
    }

    /// Removes every pending overdue alert other than the one for `sessionID`
    /// (or all of them, when `sessionID` is nil). Cleans up alerts orphaned by
    /// a killed app or a session that changed without going through this scheduler.
    public func cancelOverdueAlerts(except sessionID: UUID?) async {
        let keepID = sessionID.map(Self.overdueID(for:))
        let staleIDs = await center.pendingRequestIDs().filter { $0.hasPrefix("overdue-") && $0 != keepID }
        guard !staleIDs.isEmpty else { return }
        center.removePending(ids: staleIDs)
    }
}
