import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Spec §2.2: changing the app language reschedules every pending reminder with the new text.
@MainActor
struct ReminderTextUpdateTests {
    private let vietnamese = NotificationText(title: "Đã hơn 2 giờ", body: "Hãy liên hệ bác sĩ")

    @Test func activeSessionsOverdueAlertGetsTheNewText() async throws {
        let center = FakeNotificationCenter()
        let clock = TestClock(date("2026-09-01T20:00:00Z"))
        let coordinator = KickCoordinator(
            store: FakeSessionRepository(),
            notifications: NotificationScheduler(center: center),
            liveActivities: FakeLiveActivities(),
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { clock.now }
        )
        await coordinator.recordKick()
        let id = try #require(coordinator.activeSessionID)
        clock.advance(600)

        await coordinator.updateOverdueText(vietnamese)

        let alert = try #require(center.added.first { $0.identifier == NotificationScheduler.overdueID(for: id) })
        #expect(alert.content.title == "Đã hơn 2 giờ")
        #expect(center.added.count == 1)
        // Still fires 2 hours after the session started.
        let trigger = try #require(alert.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 2 * 60 * 60 - 600)
    }

    @Test func overdueTextIsUsedForTheNextSessionWithoutSchedulingAnythingNow() async throws {
        let center = FakeNotificationCenter()
        let coordinator = KickCoordinator(
            store: FakeSessionRepository(),
            notifications: NotificationScheduler(center: center),
            liveActivities: FakeLiveActivities(),
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { date("2026-09-01T20:00:00Z") }
        )
        await coordinator.updateOverdueText(vietnamese)
        #expect(center.added.isEmpty)
        await coordinator.recordKick()
        #expect(center.added.first?.content.title == "Đã hơn 2 giờ")
    }

    @Test func overdueTextUpdateNeverPrompts() async {
        let center = FakeNotificationCenter()
        let coordinator = KickCoordinator(
            store: FakeSessionRepository(),
            notifications: NotificationScheduler(center: center),
            liveActivities: FakeLiveActivities(),
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { date("2026-09-01T20:00:00Z") }
        )
        center.status = .notDetermined
        center.grantOnRequest = false
        await coordinator.recordKick() // asks once, denied
        #expect(center.added.isEmpty)
        center.status = .notDetermined
        let asked = center.requestCount
        await coordinator.updateOverdueText(vietnamese)
        #expect(center.requestCount == asked)
        #expect(center.added.isEmpty)
    }

    @Test func cycleRemindersGetTheNewTexts() async throws {
        let center = FakeNotificationCenter()
        let repository = FakeCycleRepository()
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        let coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "Fertile window soon", body: "In 2 days"),
                period: NotificationText(title: "Period tomorrow", body: "Due tomorrow"),
                late: NotificationText(title: "Period is late", body: "Consider a test")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { date("2026-09-05T12:00:00Z") }
        )
        repository.seed(periods: ["2026-07-09", "2026-08-06", "2026-09-03"].map {
            let start = date("\($0)T00:00:00Z")
            return PeriodRecord(startDate: start, endDate: utcCalendar.date(byAdding: .day, value: 4, to: start))
        })
        await coordinator.load()
        #expect(center.added.count == 3)

        await coordinator.updateReminderTexts(CycleReminderTexts(
            fertile: NotificationText(title: "Sắp vào cửa sổ thụ thai", body: "2 ngày nữa"),
            period: NotificationText(title: "Ngày mai có kinh", body: "Dự kiến"),
            late: NotificationText(title: "Trễ kinh", body: "Thử thai")
        ))

        let titles = Dictionary(uniqueKeysWithValues: center.added.map { ($0.identifier, $0.content.title) })
        #expect(titles == [
            "cycle-fertile": "Sắp vào cửa sổ thụ thai",
            "cycle-period": "Ngày mai có kinh",
            "cycle-late": "Trễ kinh",
        ])
    }

    @Test func cycleTextUpdateInPregnancyModeSchedulesNothing() async {
        let center = FakeNotificationCenter()
        let defaults = makeTestDefaults()
        AppMode.save(.pregnant, to: defaults)
        let coordinator = CycleCoordinator(
            store: FakeCycleRepository(),
            notifications: NotificationScheduler(center: center),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "a", body: "a"),
                period: NotificationText(title: "b", body: "b"),
                late: NotificationText(title: "c", body: "c")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { date("2026-09-05T12:00:00Z") }
        )
        await coordinator.updateReminderTexts(CycleReminderTexts(
            fertile: NotificationText(title: "x", body: "x"),
            period: NotificationText(title: "y", body: "y"),
            late: NotificationText(title: "z", body: "z")
        ))
        #expect(center.added.isEmpty)
        #expect(center.requestCount == 0)
    }

    @Test func appointmentRemindersGetTheNewText() async throws {
        let center = FakeNotificationCenter()
        let repository = FakeAppointmentRepository()
        let coordinator = AppointmentCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderText: NotificationText(title: "Check-up tomorrow", body: "Bring your records"),
            calendar: utcCalendar,
            now: { date("2026-10-02T12:00:00Z") }
        )
        let upcoming = AppointmentRecord(date: date("2026-10-20T14:30:00Z"), title: "Anomaly scan")
        let done = AppointmentRecord(date: date("2026-10-22T09:00:00Z"), title: "Glucose", isDone: true)
        repository.seed(upcoming, done)
        await coordinator.load()
        #expect(center.added.count == 1)

        await coordinator.updateReminderText(NotificationText(title: "Ngày mai mẹ có lịch khám", body: "Mang sổ khám"))

        let request = try #require(center.added.first)
        #expect(center.added.count == 1)
        #expect(request.identifier == NotificationScheduler.appointmentReminderID(for: upcoming.id))
        #expect(request.content.title == "Ngày mai mẹ có lịch khám")
        #expect(request.content.subtitle == "Anomaly scan")
    }
}
