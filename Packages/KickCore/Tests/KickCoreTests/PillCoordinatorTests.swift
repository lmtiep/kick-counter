import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// In-memory PillDoseRepository with the same rules as PillDoseStore.
@MainActor
final class FakePillDoseRepository: PillDoseRepository {
    struct Failed: Error {}

    private(set) var stored: [PillDoseRecord] = []
    var calendar = utcCalendar
    var failNextRead = false
    var failNextWrite = false

    func doses() throws -> [PillDoseRecord] {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
        return stored.sorted { $0.day < $1.day }
    }

    func markTaken(on day: CalendarDay, at time: Date) throws {
        let record = try PillDoseRules.dose(on: day, takenAt: time, calendar: calendar)
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        guard !stored.contains(where: { $0.day == record.day }) else { return }
        stored.append(record)
    }

    func unmark(on day: CalendarDay) throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        stored.removeAll { $0.day == day }
    }

    func seed(_ dose: PillDoseRecord) { stored.append(dose) }
}

@MainActor
struct PillCoordinatorTests {
    let center = FakeNotificationCenter()
    let store = FakePillDoseRepository()
    let defaults = makeTestDefaults()
    let start = date("2026-10-01T00:00:00Z")
    let startDay = CalendarDay(year: 2026, month: 10, day: 1)
    let day12 = CalendarDay(year: 2026, month: 10, day: 12)
    let now = date("2026-10-12T08:00:00Z")

    static let texts = PillReminderTexts(
        reminder: { NotificationText(title: "Đến giờ uống thuốc", body: "Viên \($0)/\($1) hôm nay.") },
        followUp: { NotificationText(title: "Bạn đã uống viên thuốc chưa?", body: "Viên \($0)/\($1).") },
        renew: NotificationText(title: "Đến giờ uống thuốc", body: "Mở Luna Mom để tiếp tục nhắc uống thuốc.")
    )

    init() {
        AppMode.save(.tryingToConceive, to: defaults)
        CyclePreferences(goal: .tracking, contraception: .pill).save(to: defaults)
    }

    private func makeCoordinator(at time: Date? = nil, calendar: Calendar = utcCalendar) -> PillCoordinator {
        let fixed = time ?? now
        return PillCoordinator(
            store: store,
            notifications: NotificationScheduler(center: center),
            texts: Self.texts,
            defaults: defaults,
            calendar: calendar,
            now: { fixed }
        )
    }

    private var onSettings: PillReminderSettings {
        PillReminderSettings(enabled: true, packType: .withBreak, packStartDay: startDay, hour: 21, minute: 0)
    }

    private var pendingIDs: Set<String> { Set(center.added.map(\.identifier)) }

    @Test func turningOnAsksForPermissionAndSchedules() async {
        center.status = .notDetermined
        let pill = makeCoordinator()
        let authorized = await pill.update(onSettings)
        #expect(authorized)
        #expect(center.requestCount == 1)
        #expect(PillReminderSettings.load(from: defaults) == onSettings)
        #expect(pendingIDs.contains("pill-20261012"))
        #expect(pendingIDs.contains("pill-20261012-followup"))
        #expect(pendingIDs.count <= PillReminderPlan.maxRequests)
    }

    @Test func deniedKeepsTheSettingAndShowsTheHint() async {
        center.status = .notDetermined
        center.grantOnRequest = false
        let pill = makeCoordinator()
        let authorized = await pill.update(onSettings)
        #expect(!authorized)
        #expect(pill.notificationsDenied)
        #expect(pill.settings.enabled)
        #expect(center.added.isEmpty)
    }

    @Test func loadNeverPrompts() async {
        onSettings.save(to: defaults)
        center.status = .notDetermined
        let pill = makeCoordinator()
        await pill.load()
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
    }

    @Test func turningOffCancelsEverything() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        var off = onSettings
        off.enabled = false
        await pill.update(off)
        #expect(pendingIDs.isEmpty)
        #expect(PillReminderSettings.load(from: defaults).packStartDay == startDay)
    }

    @Test func markingTodayRemovesItsRemindersAndUndoBringsThemBack() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        #expect(pill.today == .pillDay(number: 12, count: 21, day: day12, isYesterday: false, taken: nil))

        #expect(await pill.markTaken(on: now) == nil)
        #expect(!pendingIDs.contains("pill-20261012"))
        #expect(!pendingIDs.contains("pill-20261012-followup"))
        #expect(pendingIDs.contains("pill-20261013"))
        guard case .pillDay(12, 21, _, false, let taken?) = pill.today else {
            Issue.record("expected a taken pill day, got \(String(describing: pill.today))")
            return
        }
        #expect(taken.takenAt == now)

        #expect(await pill.undo(on: now) == nil)
        #expect(pill.today == .pillDay(number: 12, count: 21, day: day12, isYesterday: false, taken: nil))
        #expect(pendingIDs.contains("pill-20261012"))
    }

    @Test func markingTwiceKeepsTheFirstTime() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        await pill.markTaken(on: now)
        await pill.markTaken(on: now.addingTimeInterval(600))
        #expect(store.stored.count == 1)
        #expect(store.stored.first?.takenAt == now)
    }

    @Test func aFutureDayCannotBeMarked() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        #expect(await pill.markTaken(on: now.addingTimeInterval(2 * 86400)) == .futureDate)
        #expect(store.stored.isEmpty)
    }

    @Test func markingYesterdayFromALateFollowUpWorks() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        #expect(await pill.markTaken(on: date("2026-10-11T00:00:00Z")) == nil)
        #expect(store.stored.map(\.day) == [CalendarDay(year: 2026, month: 10, day: 11)])
    }

    @Test func breakWeekShowsTheNextPackAndSchedulesNothingInIt() async {
        // Day 24 of a 21+7 pack.
        let pill = makeCoordinator(at: date("2026-10-24T08:00:00Z"))
        await pill.update(onSettings)
        #expect(pill.today == .breakWeek(nextPackStart: date("2026-10-29T00:00:00Z")))
        let pack = PillPack(type: .withBreak, start: start, calendar: utcCalendar)
        for request in center.added where request.identifier != PillReminderPlan.renewIdentifier {
            let day = PillReminderPlan.day(fromIdentifier: request.identifier)
            #expect(day.map(pack.isPillDay(on:)) == true, "\(request.identifier)")
        }
        #expect(pendingIDs.contains("pill-20261029"))
        #expect(!pendingIDs.contains("pill-20261024"))
    }

    @Test func leavingThePillCancelsButKeepsTheSettings() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        #expect(pill.isActive)
        CyclePreferences(goal: .tracking, contraception: .condom).save(to: defaults)
        await pill.contraceptionChanged()
        #expect(!pill.isAvailable)
        #expect(!pill.isActive)
        #expect(pill.today == nil)
        #expect(pendingIDs.isEmpty)
        #expect(PillReminderSettings.load(from: defaults) == onSettings)

        CyclePreferences(goal: .tracking, contraception: .pill).save(to: defaults)
        await pill.contraceptionChanged()
        #expect(pendingIDs.contains("pill-20261012"))
    }

    @Test func tryingToConceiveIgnoresTheStoredPill() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        CyclePreferences(goal: .conceiving, contraception: .pill).save(to: defaults)
        await pill.contraceptionChanged()
        #expect(!pill.isAvailable)
        #expect(pendingIDs.isEmpty)
    }

    @Test func pregnancyModeHidesAndCancels() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        AppMode.save(.pregnant, to: defaults)
        await pill.load()
        #expect(!pill.isAvailable)
        #expect(pendingIDs.isEmpty)
    }

    @Test func withoutAStartNothingIsScheduled() async {
        let pill = makeCoordinator()
        var settings = onSettings
        settings.packStartDay = nil
        await pill.update(settings)
        #expect(!pill.isActive)
        #expect(pendingIDs.isEmpty)
    }

    @Test func aStoreFailureIsReported() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        store.failNextWrite = true
        #expect(await pill.markTaken(on: now) == .saveFailed)
        #expect(pill.failure == .saveFailed)
        store.failNextRead = true
        await pill.load()
        #expect(pill.failure == .loadFailed)
    }

    @Test func newTextsReschedule() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        await pill.updateTexts(PillReminderTexts(
            reminder: { NotificationText(title: "Pill time", body: "Pill \($0) of \($1) today.") },
            followUp: { NotificationText(title: "Taken?", body: "\($0)/\($1)") },
            renew: NotificationText(title: "Pill time", body: "Open Luna Mom to keep your pill reminders going.")
        ))
        #expect(center.added.first { $0.identifier == "pill-20261012" }?.content.body == "Pill 12 of 21 today.")
    }

    @Test func markingRemovesTheDaysDeliveredNotifications() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        await pill.markTaken(on: now)
        #expect(center.removedDelivered.contains("pill-20261012"))
        #expect(center.removedDelivered.contains("pill-20261012-followup"))
    }

    // MARK: - After midnight (review finding 2)

    /// 23:00 reminder, 01:00 follow-up: at 00:30 yesterday's pill is still the
    /// one to mark, and tonight's reminders stay.
    @Test func afterMidnightTheCardMarksYesterdaysPill() async {
        let late = PillReminderSettings(enabled: true, packType: .withBreak, packStartDay: startDay, hour: 23, minute: 0)
        let pill = makeCoordinator(at: date("2026-10-13T00:30:00Z"))
        await pill.update(late)
        #expect(pill.today == .pillDay(number: 12, count: 21, day: day12, isYesterday: true, taken: nil))

        await pill.markTaken(on: day12)
        #expect(store.stored.map(\.day) == [day12])
        #expect(pill.today == .pillDay(number: 13, count: 21, day: CalendarDay(year: 2026, month: 10, day: 13), isYesterday: false, taken: nil))
        #expect(pendingIDs.contains("pill-20261013"))
        #expect(pendingIDs.contains("pill-20261013-followup"))
        #expect(!pendingIDs.contains("pill-20261012-followup"))
    }

    @Test func afterTheFollowUpTimeTheCardIsToday() async {
        let late = PillReminderSettings(enabled: true, packType: .withBreak, packStartDay: startDay, hour: 23, minute: 0)
        let pill = makeCoordinator(at: date("2026-10-13T01:00:00Z"))
        await pill.update(late)
        #expect(pill.today == .pillDay(number: 13, count: 21, day: CalendarDay(year: 2026, month: 10, day: 13), isYesterday: false, taken: nil))
    }

    @Test func yesterdayAlreadyMarkedShowsToday() async {
        store.seed(PillDoseRecord(day: day12, takenAt: date("2026-10-12T23:05:00Z")))
        let late = PillReminderSettings(enabled: true, packType: .withBreak, packStartDay: startDay, hour: 23, minute: 0)
        let pill = makeCoordinator(at: date("2026-10-13T00:30:00Z"))
        await pill.update(late)
        #expect(pill.today == .pillDay(number: 13, count: 21, day: CalendarDay(year: 2026, month: 10, day: 13), isYesterday: false, taken: nil))
    }

    /// The first break day just after midnight: yesterday's pill 21 is still due.
    @Test func afterMidnightOnTheFirstBreakDayYesterdaysPillIsDue() async {
        let late = PillReminderSettings(enabled: true, packType: .withBreak, packStartDay: startDay, hour: 23, minute: 30)
        let pill = makeCoordinator(at: date("2026-10-22T00:15:00Z"))
        await pill.update(late)
        #expect(pill.today == .pillDay(number: 21, count: 21, day: CalendarDay(year: 2026, month: 10, day: 21), isYesterday: true, taken: nil))
    }

    // MARK: - Time zones (review finding 1)

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func local(_ calendar: Calendar, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    /// A pack set up in Hanoi (UTC+7) keeps the same pill on each local date
    /// in New York (UTC−4) and Tokyo (UTC+9).
    @Test func aPackKeepsItsPillNumbersAcrossTimeZones() async {
        let hanoi = calendar("Asia/Ho_Chi_Minh")
        let setUp = makeCoordinator(at: local(hanoi, 1, hour: 8), calendar: hanoi)
        await setUp.update(PillReminderSettings(
            enabled: true, packType: .withBreak, packStartDay: CalendarDay(local(hanoi, 1, hour: 8), calendar: hanoi), hour: 21, minute: 0
        ))
        for zone in ["America/New_York", "Asia/Tokyo", "Asia/Ho_Chi_Minh"] {
            let traveller = calendar(zone)
            for (day, expected) in [(1, 1), (12, 12), (21, 21)] {
                for hour in [0, 12, 23] {
                    let pill = makeCoordinator(at: local(traveller, day, hour: hour), calendar: traveller)
                    await pill.load()
                    guard case .pillDay(let number, 21, _, false, _) = pill.today else {
                        Issue.record("\(zone) Oct \(day) \(hour):00: \(String(describing: pill.today))")
                        continue
                    }
                    #expect(number == expected, "\(zone) Oct \(day) \(hour):00")
                }
            }
            let inBreak = makeCoordinator(at: local(traveller, 22, hour: 23), calendar: traveller)
            await inBreak.load()
            #expect(inBreak.today == .breakWeek(nextPackStart: local(traveller, 29, hour: 0)), "\(zone)")
        }
    }

    /// A dose marked in the evening in Hanoi is the same calendar day in New York.
    @Test func aDoseKeepsItsCalendarDayAcrossTimeZones() async {
        let hanoi = calendar("Asia/Ho_Chi_Minh")
        let newYork = calendar("America/New_York")
        let settings = PillReminderSettings(enabled: true, packType: .withBreak, packStartDay: startDay, hour: 21, minute: 0)
        let marking = makeCoordinator(at: local(hanoi, 12, hour: 21), calendar: hanoi)
        await marking.update(settings)
        await marking.markTaken(on: local(hanoi, 12, hour: 21))
        #expect(store.stored.map(\.day) == [day12])

        let abroad = makeCoordinator(at: local(newYork, 12, hour: 20), calendar: newYork)
        await abroad.load()
        guard case .pillDay(12, 21, day12, false, let taken?) = abroad.today else {
            Issue.record("\(String(describing: abroad.today))")
            return
        }
        #expect(taken.day == day12)
        #expect(abroad.dose(on: local(newYork, 13, hour: 1)) == nil)
    }

    // MARK: - Renewal notice (review finding 3)

    @Test func theRenewalNoticeFollowsTheWindow() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        let renew = center.added.first { $0.identifier == PillReminderPlan.renewIdentifier }
        #expect(renew?.content.body == "Mở Luna Mom để tiếp tục nhắc uống thuốc.")
        #expect(center.added.count <= 29)
        var off = onSettings
        off.enabled = false
        await pill.update(off)
        #expect(pendingIDs.isEmpty)
    }
}
