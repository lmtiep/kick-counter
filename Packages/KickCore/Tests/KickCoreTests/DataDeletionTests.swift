import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Phase 12: "Delete all data" empties the store underneath the coordinators; the
/// app then calls `resetAfterDataDeletion()` (kicks) and `load()` on each of them.
/// None may keep showing what was deleted.
@MainActor
struct KickCoordinatorDataDeletionTests {
    let repository = FakeSessionRepository()
    let center = FakeNotificationCenter()
    let live = FakeLiveActivities()
    let clock = TestClock(date("2026-09-01T20:00:00Z"))
    let coordinator: KickCoordinator

    init() {
        let clock = clock
        coordinator = KickCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            liveActivities: live,
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { clock.now }
        )
    }

    private func kick(times: Int) async {
        for _ in 0..<times {
            await coordinator.recordKick()
            clock.advance(60)
        }
    }

    @Test func runningSessionRepositoryEmptiedLoadForgetsIt() async throws {
        await kick(times: 3)
        #expect(coordinator.activeSessionID != nil)
        repository.eraseAll()

        await coordinator.load()

        #expect(coordinator.activeSession == nil)
        #expect(coordinator.activeSessionID == nil)
        #expect(live.activeIDs.isEmpty)
        #expect(center.added.isEmpty)
    }

    @Test func resetAfterDeletionForgetsTheSessionTheCompletionAndAFailure() async throws {
        await kick(times: 10)
        #expect(coordinator.completedSession != nil)
        await kick(times: 2) // a new session after the completed one
        repository.failNextWrite = true
        await coordinator.recordKick()
        #expect(coordinator.failure == .saveFailed)
        center.added.append(UNNotificationRequest(identifier: NotificationScheduler.dailyReminderID, content: .init(), trigger: nil))
        repository.eraseAll()

        await coordinator.resetAfterDataDeletion()
        await coordinator.load()

        #expect(coordinator.activeSession == nil)
        #expect(coordinator.activeSessionID == nil)
        #expect(coordinator.completedSession == nil)
        #expect(coordinator.failure == nil)
        #expect(live.activeIDs.isEmpty)
        #expect(center.added.isEmpty)
    }

    @Test func aSessionStartedAfterTheResetWorks() async throws {
        await kick(times: 4)
        repository.eraseAll()
        await coordinator.resetAfterDataDeletion()
        await coordinator.load()
        clock.advance(60)

        #expect(await coordinator.recordKick() == .added(count: 1))
        let id = try #require(coordinator.activeSessionID)
        #expect(coordinator.activeSession?.count == 1)
        #expect(live.activeIDs == [id])
        #expect(center.added.map(\.identifier) == [NotificationScheduler.overdueID(for: id)])
    }
}

@MainActor
struct AppointmentCoordinatorDataDeletionTests {
    let repository = FakeAppointmentRepository()
    let center = FakeNotificationCenter()
    let clock = TestClock(date("2026-10-02T12:00:00Z"))
    let coordinator: AppointmentCoordinator

    init() {
        let clock = clock
        coordinator = AppointmentCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderText: NotificationText(title: "Check-up tomorrow", body: "Bring your records"),
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    @Test func emptiedRepositoryLoadClearsTheListsAndReminders() async throws {
        _ = try #require(await coordinator.add(date: date("2026-10-20T14:30:00Z"), title: "Scan"))
        repository.seed(AppointmentRecord(date: date("2026-09-20T09:00:00Z"), title: "Old"))
        await coordinator.load()
        #expect(!coordinator.upcoming.isEmpty && !coordinator.past.isEmpty)
        #expect(!center.added.isEmpty)
        repository.eraseAll()

        await coordinator.load()

        #expect(coordinator.upcoming.isEmpty)
        #expect(coordinator.past.isEmpty)
        #expect(coordinator.nextAppointment == nil)
        #expect(center.added.isEmpty)
    }
}

@MainActor
struct CycleCoordinatorDataDeletionTests {
    let repository = FakeCycleRepository()
    let center = FakeNotificationCenter()
    let clock = TestClock(date("2026-09-05T12:00:00Z"))
    let defaults = makeTestDefaults()
    let coordinator: CycleCoordinator

    init() {
        let clock = clock
        AppMode.save(.tryingToConceive, to: defaults)
        coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "Fertile", body: "Soon"),
                period: NotificationText(title: "Period", body: "Tomorrow"),
                late: NotificationText(title: "Late", body: "Test")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func emptiedRepositoryAndDefaultsLoadClearsPeriodsLogsForecastAndSettings() async {
        repository.seed(
            periods: ["2026-07-09", "2026-08-06", "2026-09-03"].map { PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0))) },
            logs: [CycleLogRecord(day: day("2026-09-04"), note: "cramps")]
        )
        CycleSettings(typicalCycleLength: 32, typicalPeriodLength: 6).save(to: defaults)
        await coordinator.load()
        #expect(!coordinator.periods.isEmpty && !coordinator.logs.isEmpty)
        #expect(coordinator.forecast?.currentPeriodStart != nil)
        repository.eraseAll()
        AppDataReset.clearDefaults(defaults)

        await coordinator.load()

        #expect(coordinator.periods.isEmpty)
        #expect(coordinator.logs.isEmpty)
        #expect(coordinator.forecast?.currentPeriodStart == nil)
        #expect(coordinator.settings == CycleSettings.load(from: makeTestDefaults()))
        #expect(coordinator.preferences == CyclePreferences.load(from: makeTestDefaults()))
        // The stored mode is gone (pregnant by default): no cycle reminder is left.
        #expect(center.added.isEmpty)
    }
}

@MainActor
struct WeightCoordinatorDataDeletionTests {
    let repository = FakeWeightRepository()
    let clock = TestClock(date("2026-10-02T12:00:00Z"))
    let defaults = makeTestDefaults()
    let coordinator: WeightCoordinator

    init() {
        let clock = clock
        coordinator = WeightCoordinator(store: repository, defaults: defaults, calendar: utcCalendar, now: { clock.now })
    }

    @Test func emptiedRepositoryAndDefaultsLoadClearsEntriesAndProfile() async throws {
        repository.seed(WeightRecord(day: date("2026-09-29T00:00:00Z"), kg: 57.6))
        try MaternalProfile(preWeightKg: 52, heightCm: 160).save(to: defaults)
        await coordinator.load()
        #expect(coordinator.latest != nil)
        repository.eraseAll()
        AppDataReset.clearDefaults(defaults)

        await coordinator.load()

        #expect(coordinator.entries.isEmpty)
        #expect(coordinator.latest == nil)
        #expect(coordinator.profile == MaternalProfile.load(from: makeTestDefaults()))
    }
}
