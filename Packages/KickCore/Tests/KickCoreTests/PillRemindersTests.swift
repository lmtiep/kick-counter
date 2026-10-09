import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Phase 17 spec §4.2: which pill notifications are pending.
struct PillReminderPlanTests {
    private let start = date("2026-10-01T00:00:00Z")

    private func day(_ offset: Int) -> Date {
        utcCalendar.date(byAdding: .day, value: offset, to: start)!
    }

    private func plan(
        _ type: PillPackType,
        now: Date,
        taken: Set<Date> = [],
        hour: Int = 21,
        minute: Int = 0
    ) -> [PillReminderRequest] {
        PillReminderPlan.requests(
            pack: PillPack(type: type, start: start, calendar: utcCalendar),
            hour: hour, minute: minute, now: now, takenDays: taken, calendar: utcCalendar
        )
    }

    @Test func identifiersUseTheLocalDay() {
        #expect(PillReminderPlan.identifier(for: date("2026-10-09T23:00:00Z"), calendar: utcCalendar) == "pill-20261009")
        #expect(PillReminderPlan.followUpIdentifier(for: date("2026-10-09T05:00:00Z"), calendar: utcCalendar) == "pill-20261009-followup")
        #expect(PillReminderPlan.day(fromIdentifier: "pill-20261009-followup", calendar: utcCalendar) == date("2026-10-09T00:00:00Z"))
        #expect(PillReminderPlan.day(fromIdentifier: "pill-20261009", calendar: utcCalendar) == date("2026-10-09T00:00:00Z"))
        #expect(PillReminderPlan.day(fromIdentifier: "cycle-late", calendar: utcCalendar) == nil)
    }

    @Test func fourteenPillDaysWithAFollowUpTwoHoursLater() {
        let requests = plan(.continuous, now: day(0).addingTimeInterval(8 * 3600))
        #expect(requests.count == 28)
        let mains = requests.filter { $0.kind == .reminder }
        let followUps = requests.filter { $0.kind == .followUp }
        #expect(mains.count == 14)
        #expect(followUps.count == 14)
        #expect(mains.first?.identifier == "pill-20261001")
        #expect(mains.first?.fireDate == day(0).addingTimeInterval(21 * 3600))
        #expect(mains.first?.pillNumber == 1)
        #expect(mains.first?.pillCount == 28)
        #expect(followUps.first?.identifier == "pill-20261001-followup")
        #expect(followUps.first?.fireDate == day(0).addingTimeInterval(23 * 3600))
        #expect(mains.last?.day == day(13))
        #expect(Set(requests.map(\.identifier)).count == requests.count)
    }

    @Test func neverMoreThan28Requests() {
        for type in PillPackType.allCases {
            for offset in 0..<56 {
                for hour in [0, 9, 21, 23] {
                    let requests = plan(type, now: day(offset).addingTimeInterval(3600), hour: hour)
                    #expect(requests.count <= PillReminderPlan.maxRequests)
                }
            }
        }
        #expect(PillReminderPlan.maxRequests == 28)
    }

    /// The other fixed reminders (daily kick, one overdue alert, three cycle
    /// reminders) leave room for appointments under iOS's 64 pending requests.
    @Test func theBudgetLeavesRoomUnderTheSystemLimit() {
        let fixed = 1 + 1 + CycleReminderKind.allCases.count
        #expect(PillReminderPlan.maxRequests + fixed <= 64 - 20)
    }

    @Test func nothingIsScheduledOnBreakDays() {
        let pack = PillPack(type: .withBreak, start: start, calendar: utcCalendar)
        for offset in 0..<56 {
            let requests = plan(.withBreak, now: day(offset))
            for request in requests {
                #expect(pack.isPillDay(on: request.day), "\(request.identifier) is a break day")
                #expect(pack.isPillDay(on: request.fireDate.addingTimeInterval(request.kind == .followUp ? -7200 : 0)))
            }
        }
        // Inside the break: the first request is pill 1 of the next pack.
        let inBreak = plan(.withBreak, now: day(22))
        #expect(inBreak.first?.day == day(28))
        #expect(inBreak.first?.pillNumber == 1)
        #expect(inBreak.first?.pillCount == 21)
        #expect(!inBreak.contains { (21..<28).map(day).contains($0.day) })
    }

    @Test func theEveOfANewPackStillRemindsOnItsFirstDay() {
        let requests = plan(.withBreak, now: day(27).addingTimeInterval(20 * 3600))
        #expect(requests.first?.identifier == "pill-20261029")
        #expect(requests.first?.fireDate == day(28).addingTimeInterval(21 * 3600))
    }

    @Test func pastTimesAreSkippedButTodaysFollowUpStays() {
        let requests = plan(.continuous, now: day(0).addingTimeInterval(22 * 3600))
        #expect(requests.first?.identifier == "pill-20261001-followup")
        #expect(!requests.contains { $0.identifier == "pill-20261001" })
        // Today still counts as one of the 14 days: 13 more reminders, 27 requests.
        #expect(requests.filter { $0.kind == .reminder }.count == 13)
        #expect(requests.count == 27)
        #expect(requests.allSatisfy { $0.fireDate > day(0).addingTimeInterval(22 * 3600) })
    }

    @Test func aMarkedDayHasNoReminderAndNoFollowUp() {
        let requests = plan(.continuous, now: day(0).addingTimeInterval(21.5 * 3600), taken: [day(0)])
        #expect(!requests.contains { $0.day == day(0) })
        #expect(requests.first?.identifier == "pill-20261002")
    }

    @Test func aFollowUpAfterMidnightKeepsItsDay() {
        let requests = plan(.continuous, now: day(0), hour: 23, minute: 30)
        let followUp = requests.first { $0.kind == .followUp }
        #expect(followUp?.identifier == "pill-20261001-followup")
        #expect(followUp?.fireDate == day(1).addingTimeInterval(1.5 * 3600))
    }
}

@MainActor
struct PillNotificationSchedulerTests {
    private let texts = PillReminderTexts(
        reminder: { NotificationText(title: "Đến giờ uống thuốc", body: "Viên \($0)/\($1) hôm nay.") },
        followUp: { NotificationText(title: "Bạn đã uống thuốc hôm nay chưa?", body: "Viên \($0)/\($1).") }
    )

    @Test func schedulesWithTheCategoryAndTheDay() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let start = date("2026-10-01T00:00:00Z")
        let requests = PillReminderPlan.requests(
            pack: PillPack(type: .withBreak, start: start, calendar: utcCalendar),
            hour: 21, minute: 0, now: date("2026-10-12T08:00:00Z"), takenDays: [], calendar: utcCalendar
        )
        try await scheduler.schedulePillReminders(requests, texts: texts, calendar: utcCalendar)

        #expect(center.added.count == requests.count)
        let first = try #require(center.added.first)
        #expect(first.identifier == "pill-20261012")
        #expect(first.content.title == "Đến giờ uống thuốc")
        #expect(first.content.body == "Viên 12/21 hôm nay.")
        #expect(first.content.categoryIdentifier == PillReminderPlan.categoryIdentifier)
        #expect(first.content.userInfo[PillReminderPlan.dayUserInfoKey] as? Double == date("2026-10-12T00:00:00Z").timeIntervalSince1970)
        let trigger = try #require(first.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents.day == 12 && trigger.dateComponents.hour == 21)
        let followUp = try #require(center.added.first { $0.identifier == "pill-20261012-followup" })
        #expect(followUp.content.title == "Bạn đã uống thuốc hôm nay chưa?")
        #expect(followUp.content.categoryIdentifier == PillReminderPlan.categoryIdentifier)
    }

    @Test func reschedulingReplacesEveryOldPillRequestAndLeavesOthers() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        try await scheduler.scheduleDailyReminder(hour: 20, minute: 0, text: NotificationText(title: "t", body: "b"))
        let old = PillReminderRequest(
            identifier: "pill-20260901", kind: .reminder, day: date("2026-09-01T00:00:00Z"),
            fireDate: date("2026-09-01T21:00:00Z"), pillNumber: 1, pillCount: 21
        )
        try await scheduler.schedulePillReminders([old], texts: texts, calendar: utcCalendar)
        let new = PillReminderRequest(
            identifier: "pill-20261001", kind: .reminder, day: date("2026-10-01T00:00:00Z"),
            fireDate: date("2026-10-01T21:00:00Z"), pillNumber: 1, pillCount: 21
        )
        try await scheduler.schedulePillReminders([new], texts: texts, calendar: utcCalendar)
        #expect(Set(center.added.map(\.identifier)) == [NotificationScheduler.dailyReminderID, "pill-20261001"])

        await scheduler.cancelPillReminders()
        #expect(center.added.map(\.identifier) == [NotificationScheduler.dailyReminderID])
    }
}
