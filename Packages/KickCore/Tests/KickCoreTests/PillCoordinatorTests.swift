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

    func markTaken(on day: Date, at time: Date) throws {
        let record = try PillDoseRules.dose(on: day, takenAt: time, calendar: calendar)
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        guard !stored.contains(where: { $0.day == record.day }) else { return }
        stored.append(record)
    }

    func unmark(on day: Date) throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        let start = calendar.startOfDay(for: day)
        stored.removeAll { $0.day == start }
    }
}

@MainActor
struct PillCoordinatorTests {
    let center = FakeNotificationCenter()
    let store = FakePillDoseRepository()
    let defaults = makeTestDefaults()
    let start = date("2026-10-01T00:00:00Z")
    let now = date("2026-10-12T08:00:00Z")

    static let texts = PillReminderTexts(
        reminder: { NotificationText(title: "Đến giờ uống thuốc", body: "Viên \($0)/\($1) hôm nay.") },
        followUp: { NotificationText(title: "Bạn đã uống thuốc hôm nay chưa?", body: "Viên \($0)/\($1).") }
    )

    init() {
        AppMode.save(.tryingToConceive, to: defaults)
        CyclePreferences(goal: .tracking, contraception: .pill).save(to: defaults)
    }

    private func makeCoordinator(at time: Date? = nil) -> PillCoordinator {
        let fixed = time ?? now
        return PillCoordinator(
            store: store,
            notifications: NotificationScheduler(center: center),
            texts: Self.texts,
            defaults: defaults,
            calendar: utcCalendar,
            now: { fixed }
        )
    }

    private var onSettings: PillReminderSettings {
        PillReminderSettings(enabled: true, packType: .withBreak, packStart: start, hour: 21, minute: 0)
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
        #expect(pendingIDs.count <= 28)
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
        #expect(PillReminderSettings.load(from: defaults).packStart == start)
    }

    @Test func markingTodayRemovesItsRemindersAndUndoBringsThemBack() async {
        let pill = makeCoordinator()
        await pill.update(onSettings)
        #expect(pill.today == .pillDay(number: 12, count: 21, taken: nil))

        #expect(await pill.markTaken(on: now) == nil)
        #expect(!pendingIDs.contains("pill-20261012"))
        #expect(!pendingIDs.contains("pill-20261012-followup"))
        #expect(pendingIDs.contains("pill-20261013"))
        guard case .pillDay(12, 21, let taken?) = pill.today else {
            Issue.record("expected a taken pill day, got \(String(describing: pill.today))")
            return
        }
        #expect(taken.takenAt == now)

        #expect(await pill.undo(on: now) == nil)
        #expect(pill.today == .pillDay(number: 12, count: 21, taken: nil))
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
        #expect(store.stored.map(\.day) == [date("2026-10-11T00:00:00Z")])
    }

    @Test func breakWeekShowsTheNextPackAndSchedulesNothingInIt() async {
        // Day 24 of a 21+7 pack.
        let pill = makeCoordinator(at: date("2026-10-24T08:00:00Z"))
        await pill.update(onSettings)
        #expect(pill.today == .breakWeek(nextPackStart: date("2026-10-29T00:00:00Z")))
        let pack = PillPack(type: .withBreak, start: start, calendar: utcCalendar)
        for request in center.added {
            let day = PillReminderPlan.day(fromIdentifier: request.identifier, calendar: utcCalendar)
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
        settings.packStart = nil
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
            followUp: { NotificationText(title: "Taken?", body: "\($0)/\($1)") }
        ))
        #expect(center.added.first { $0.identifier == "pill-20261012" }?.content.body == "Pill 12 of 21 today.")
    }

    @Test func thePackStartIsStoredAtStartOfDay() async {
        let pill = makeCoordinator()
        var settings = onSettings
        settings.packStart = date("2026-10-01T15:20:00Z")
        await pill.update(settings)
        #expect(PillReminderSettings.load(from: defaults).packStart == start)
    }
}
