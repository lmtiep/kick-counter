import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// 1.1 item 4 (spec §4.5, §4.6): the gentle check-ins after a pregnancy ends.
struct CareCheckInTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    private let endDay = date("2026-09-01T00:00:00+07:00")
    private var end: PregnancyEndState { PregnancyEndState(branch: .loss, endDate: endDay, calendar: calendar) }

    /// 15:00 local on the `n`-th day after the end.
    private func dayAfterEnd(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: endDay)!.addingTimeInterval(15 * 3600)
    }

    private func startOfDay(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: endDay)!
    }

    private func due(_ state: CareCheckInState = CareCheckInState(), day n: Int, end: PregnancyEndState? = nil) -> Bool {
        CareCheckInPolicy.isDue(end: end ?? self.end, state: state, now: dayAfterEnd(n), calendar: calendar)
    }

    @Test func notDueOnDay20() {
        #expect(!due(day: 20))
        #expect(!due(day: 0))
    }

    @Test func dueOnDay21() {
        #expect(due(day: 21))
    }

    @Test func notDueAgainWithin7Days() {
        let shown = CareCheckInPolicy.record(.good, state: CareCheckInState(), now: dayAfterEnd(21))
        #expect(!due(shown, day: 21))
        #expect(!due(shown, day: 27))
    }

    @Test func dueAfter7Days() {
        let shown = CareCheckInPolicy.record(.okay, state: CareCheckInState(), now: dayAfterEnd(21))
        #expect(due(shown, day: 28))
    }

    @Test func neverDueAfterDay105() {
        #expect(CareCheckInPolicy.lastDay == 105)
        #expect(due(day: 105))
        #expect(!due(day: 106))
        let shown = CareCheckInPolicy.record(.okay, state: CareCheckInState(), now: dayAfterEnd(100))
        #expect(!due(shown, day: 107))
    }

    @Test func stoppedNeverDue() {
        var state = CareCheckInState()
        state.stopped = true
        #expect(!due(state, day: 21))
    }

    @Test func disabledNeverDue() {
        var state = CareCheckInState()
        state.enabled = false
        #expect(!due(state, day: 21))
    }

    @Test func noEndStateNeverDue() {
        #expect(!CareCheckInPolicy.isDue(end: nil, state: CareCheckInState(), now: dayAfterEnd(30), calendar: calendar))
        #expect(CareCheckInPolicy.nextDate(end: nil, state: CareCheckInState(), now: dayAfterEnd(3), calendar: calendar) == nil)
    }

    @Test func skipSetsLastShownWithoutChangingStreak() {
        var state = CareCheckInState()
        state.lowStreak = 1
        let skipped = CareCheckInPolicy.record(nil, state: state, now: dayAfterEnd(21))
        #expect(skipped.lowStreak == 1)
        #expect(skipped.lastShown == dayAfterEnd(21))
    }

    @Test func twoLowInARowShowsShareLine() {
        let first = CareCheckInPolicy.record(.sad, state: CareCheckInState(), now: dayAfterEnd(21))
        #expect(!CareCheckInPolicy.showsShareLine(first))
        let second = CareCheckInPolicy.record(.heavy, state: first, now: dayAfterEnd(28))
        #expect(second.lowStreak == 2)
        #expect(CareCheckInPolicy.showsShareLine(second))
        #expect(CareFeeling.allCases.filter(\.isLow) == [.sad, .heavy])
    }

    @Test func aGoodFeelingResetsStreak() {
        var state = CareCheckInState()
        state.lowStreak = 2
        let after = CareCheckInPolicy.record(.tired, state: state, now: dayAfterEnd(28))
        #expect(after.lowStreak == 0)
        #expect(!CareCheckInPolicy.showsShareLine(after))
    }

    @Test func nextDateIsDay21ThenWeekly() {
        #expect(CareCheckInPolicy.nextDate(end: end, state: CareCheckInState(), now: dayAfterEnd(3), calendar: calendar) == startOfDay(21))
        let shown = CareCheckInPolicy.record(.good, state: CareCheckInState(), now: dayAfterEnd(21))
        #expect(CareCheckInPolicy.nextDate(end: end, state: shown, now: dayAfterEnd(21), calendar: calendar) == startOfDay(28))
        // Due but not answered yet: today.
        #expect(CareCheckInPolicy.nextDate(end: end, state: CareCheckInState(), now: dayAfterEnd(24), calendar: calendar) == startOfDay(24))
        // The last week: nothing after day 105.
        let late = CareCheckInPolicy.record(.good, state: CareCheckInState(), now: dayAfterEnd(100))
        #expect(CareCheckInPolicy.nextDate(end: end, state: late, now: dayAfterEnd(100), calendar: calendar) == nil)
    }

    @Test func nextDateNilWhenStopped() {
        var state = CareCheckInState()
        state.stopped = true
        #expect(CareCheckInPolicy.nextDate(end: end, state: state, now: dayAfterEnd(3), calendar: calendar) == nil)
        state = CareCheckInState()
        state.enabled = false
        #expect(CareCheckInPolicy.nextDate(end: end, state: state, now: dayAfterEnd(3), calendar: calendar) == nil)
    }

    @Test func stateRoundTripsAndDefaultsToOn() {
        let defaults = makeTestDefaults()
        #expect(CareCheckInState.load(from: defaults) == CareCheckInState())
        #expect(CareCheckInState().enabled && !CareCheckInState().notify)
        var state = CareCheckInState()
        state.enabled = false
        state.notify = true
        state.stopped = true
        state.lastShown = dayAfterEnd(21)
        state.lowStreak = 2
        state.save(to: defaults)
        #expect(CareCheckInState.load(from: defaults) == state)
    }

    @Test func clearRemovesKeys() {
        let defaults = makeTestDefaults()
        var state = CareCheckInState()
        state.notify = true
        state.lastShown = dayAfterEnd(21)
        state.save(to: defaults)
        CareCheckInState.clear(defaults)
        for key in CareCheckInState.keys {
            #expect(defaults.object(forKey: key) == nil, "\(key)")
        }
        #expect(CareCheckInState.load(from: defaults) == CareCheckInState())
    }

    @Test func tipIndexIsStablePerDay() {
        let morning = calendar.date(byAdding: .hour, value: 8, to: startOfDay(30))!
        let evening = calendar.date(byAdding: .hour, value: 22, to: startOfDay(30))!
        let a = CareCheckInPolicy.tipIndex(now: morning, calendar: calendar, count: 10)
        #expect(a == CareCheckInPolicy.tipIndex(now: evening, calendar: calendar, count: 10))
        #expect((0..<10).contains(a))
        let days = Set((0..<10).map { CareCheckInPolicy.tipIndex(now: dayAfterEnd($0), calendar: calendar, count: 10) })
        #expect(days.count == 10)
    }

    // MARK: - The optional notification

    @MainActor
    @Test func notificationIsOneNeutralRequestAtTen() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(center: center)
        let text = NotificationText(title: "Luna Mom", body: "Luna Mom is checking in on you")
        let scheduled = try await scheduler.scheduleCareCheckIn(on: startOfDay(28), now: dayAfterEnd(21), text: text, calendar: calendar)
        #expect(scheduled)
        let request = try #require(center.added.first)
        #expect(center.added.count == 1)
        #expect(request.identifier == "care-checkin")
        #expect(request.content.body == "Luna Mom is checking in on you")
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 10)
        #expect(trigger.dateComponents.day == calendar.component(.day, from: startOfDay(28)))

        // Rescheduling replaces it; a time already past schedules nothing.
        let past = try await scheduler.scheduleCareCheckIn(on: startOfDay(21), now: dayAfterEnd(21), text: text, calendar: calendar)
        #expect(!past)
        #expect(center.added.isEmpty)

        _ = try await scheduler.scheduleCareCheckIn(on: startOfDay(28), now: dayAfterEnd(21), text: text, calendar: calendar)
        scheduler.cancelCareCheckIn()
        #expect(center.added.isEmpty)
        #expect(center.requestCount == 0)
    }
}
