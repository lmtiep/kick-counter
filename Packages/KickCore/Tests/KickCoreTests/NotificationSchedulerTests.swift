import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct NotificationSchedulerTests {
    let center = FakeNotificationCenter()
    let text = NotificationText(title: "T", body: "B")
    var scheduler: NotificationScheduler { NotificationScheduler(center: center) }

    /// Only what the app uses: alerts and sounds, never a badge.
    @Test func permissionAsksForAlertsAndSoundsOnly() {
        #expect(SystemNotificationCenter.authorizationOptions == [.alert, .sound])
        #expect(!SystemNotificationCenter.authorizationOptions.contains(.badge))
    }

    @Test func dailyReminderRepeatsAtChosenTime() async throws {
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 30, text: text)
        let request = try #require(center.added.first)
        #expect(request.identifier == NotificationScheduler.dailyReminderID)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 20)
        #expect(trigger.dateComponents.minute == 30)
        #expect(request.content.title == "T")
        #expect(request.content.body == "B")
    }

    @Test func reschedulingDailyReminderReplacesIt() async throws {
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: text)
        try await scheduler.scheduleDailyReminder(hour: 21, minute: 0, text: text)
        #expect(center.added.count == 1)
        #expect((center.added[0].trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour == 21)
    }

    @Test func cancelDailyReminderRemovesIt() {
        scheduler.cancelDailyReminder()
        #expect(center.removed == [NotificationScheduler.dailyReminderID])
    }

    @Test func overdueAlertFiresTwoHoursAfterStart() async throws {
        let id = UUID()
        let start = date("2026-09-01T20:00:00Z")
        try await scheduler.scheduleOverdueAlert(sessionID: id, startedAt: start, now: start.addingTimeInterval(600), text: text)
        let request = try #require(center.added.first)
        #expect(request.identifier == NotificationScheduler.overdueID(for: id))
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == SessionRules.overdueThreshold - 600)
        #expect(trigger.repeats == false)
    }

    @Test func overdueAlertIsSkippedWhenAlreadyPastThreshold() async throws {
        let start = date("2026-09-01T20:00:00Z")
        try await scheduler.scheduleOverdueAlert(sessionID: UUID(), startedAt: start, now: start.addingTimeInterval(7200), text: text)
        #expect(center.added.isEmpty)
    }

    @Test func cancelOverdueAlertUsesSessionID() {
        let id = UUID()
        scheduler.cancelOverdueAlert(sessionID: id)
        #expect(center.removed == ["overdue-\(id.uuidString)"])
    }

    @Test func cancelOverdueAlertsExceptKeepsOneAndRemovesOthers() async throws {
        let keep = UUID()
        let stale1 = UUID()
        let stale2 = UUID()
        let start = date("2026-09-01T20:00:00Z")
        for id in [keep, stale1, stale2] {
            try await scheduler.scheduleOverdueAlert(sessionID: id, startedAt: start, now: start, text: text)
        }

        await scheduler.cancelOverdueAlerts(except: keep)

        #expect(center.added.map(\.identifier) == [NotificationScheduler.overdueID(for: keep)])
        #expect(Set(center.removed) == [NotificationScheduler.overdueID(for: stale1), NotificationScheduler.overdueID(for: stale2)])
    }

    @Test func cancelOverdueAlertsExceptNilRemovesAllOverdueAlerts() async throws {
        let start = date("2026-09-01T20:00:00Z")
        try await scheduler.scheduleOverdueAlert(sessionID: UUID(), startedAt: start, now: start, text: text)
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: text)

        await scheduler.cancelOverdueAlerts(except: nil)

        #expect(center.added.map(\.identifier) == [NotificationScheduler.dailyReminderID])
    }

    @Test func requestsAuthorizationOnlyWhenUndetermined() async {
        center.status = .notDetermined
        #expect(await scheduler.requestAuthorizationIfNeeded())
        #expect(await scheduler.requestAuthorizationIfNeeded())
        #expect(center.requestCount == 1)
    }

    @Test func deniedAuthorizationIsReported() async {
        center.status = .denied
        #expect(await scheduler.requestAuthorizationIfNeeded() == false)
        #expect(center.requestCount == 0)
        #expect(await scheduler.isAuthorized() == false)
    }
}
