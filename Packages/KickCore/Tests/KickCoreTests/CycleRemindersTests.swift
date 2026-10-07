import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct CycleRemindersTests {
    let center = FakeNotificationCenter()
    let texts = CycleReminderTexts(
        fertile: NotificationText(title: "Fertile window soon", body: "Starts in 2 days"),
        period: NotificationText(title: "Period tomorrow", body: "Your period is due tomorrow"),
        late: NotificationText(title: "Period is late", body: "Consider a pregnancy test")
    )
    var scheduler: NotificationScheduler { NotificationScheduler(center: center) }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Regular 28-day cycles; current period 2026-09-03 → window 09-12…09-18, next period 10-01.
    private func regularForecast() throws -> CycleForecast {
        let periods = ["2026-07-09", "2026-08-06", "2026-09-03"].map {
            PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0)))
        }
        return try #require(CyclePredictor.forecast(
            periods: periods, logs: [], settings: CycleSettings(), now: date("2026-09-05T12:00:00Z"), calendar: utcCalendar
        ))
    }

    private func components(_ id: String) -> [Int?] {
        let trigger = center.added.first { $0.identifier == id }?.trigger as? UNCalendarNotificationTrigger
        let c = trigger?.dateComponents
        return [c?.year, c?.month, c?.day, c?.hour, c?.minute]
    }

    @Test func fireDatesAre9OClockAroundTheForecast() throws {
        let dates = NotificationScheduler.cycleReminderFireDates(for: try regularForecast(), calendar: utcCalendar)
        #expect(dates[.fertile] == date("2026-09-10T09:00:00Z"))
        #expect(dates[.period] == date("2026-09-30T09:00:00Z"))
        #expect(dates[.late] == date("2026-10-04T09:00:00Z"))
    }

    @Test func schedulesAllThreeWithTheirTexts() async throws {
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar
        )
        #expect(scheduled == [.fertile, .period, .late])
        #expect(Set(center.added.map(\.identifier)) == ["cycle-fertile", "cycle-period", "cycle-late"])
        #expect(components("cycle-fertile") == [2026, 9, 10, 9, 0])
        #expect(components("cycle-period") == [2026, 9, 30, 9, 0])
        #expect(components("cycle-late") == [2026, 10, 4, 9, 0])
        let fertile = try #require(center.added.first { $0.identifier == "cycle-fertile" })
        #expect(fertile.content.title == "Fertile window soon")
        #expect((fertile.trigger as? UNCalendarNotificationTrigger)?.repeats == false)
        #expect(center.added.first { $0.identifier == "cycle-late" }?.content.body == "Consider a pregnancy test")
    }

    /// Phase 9: tracking schedules only the kinds it asks for; the others are cancelled.
    @Test func onlyTheRequestedKindsAreScheduled() async throws {
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, kinds: [.period, .late], calendar: utcCalendar
        )
        #expect(scheduled == [.period, .late])
        #expect(Set(center.added.map(\.identifier)) == ["cycle-period", "cycle-late"])
    }

    @Test func remindersWhoseTimeHasPassedAreSkipped() async throws {
        // 2026-09-10 at 09:00 exactly: the fertile reminder is not in the future.
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-09-10T09:00:00Z"), texts: texts, calendar: utcCalendar
        )
        #expect(scheduled == [.period, .late])
        #expect(center.added.map(\.identifier).contains("cycle-fertile") == false)
    }

    @Test func onlyTheLateReminderRemainsOnceThePeriodIsDue() async throws {
        let scheduled = try await scheduler.scheduleCycleReminders(
            for: try regularForecast(), now: date("2026-10-02T12:00:00Z"), texts: texts, calendar: utcCalendar
        )
        #expect(scheduled == [.late])
    }

    @Test func reschedulingReplacesEarlierReminders() async throws {
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        #expect(center.added.count == 3)
    }

    @Test func cancelRemovesEveryCycleReminderOnly() async throws {
        try await scheduler.scheduleCycleReminders(for: try regularForecast(), now: date("2026-09-05T12:00:00Z"), texts: texts, calendar: utcCalendar)
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: texts.period)
        scheduler.cancelCycleReminders()
        #expect(center.added.map(\.identifier) == [NotificationScheduler.dailyReminderID])
        #expect(Set(center.removed).isSuperset(of: ["cycle-fertile", "cycle-period", "cycle-late"]))
    }
}
