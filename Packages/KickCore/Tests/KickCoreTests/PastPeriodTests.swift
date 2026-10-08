import Foundation
import Testing
@testable import KickCore

/// Phase 13: a period started on a long-past day is closed at the typical
/// length, and "add a past period" back-fills the history.
@MainActor
struct PastPeriodTests {
    let repository: FakeCycleRepository
    let clock: TestClock
    let coordinator: CycleCoordinator

    init() {
        let repository = FakeCycleRepository()
        let clock = TestClock(date("2026-09-05T12:00:00Z"))
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        self.repository = repository
        self.clock = clock
        coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: FakeNotificationCenter()),
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

    // MARK: - Starting a period on a past day

    @Test func startOnALongPastDayIsClosedAtTypicalLength() async throws {
        await coordinator.load()
        let id = try await coordinator.startPeriodReturningID(on: day("2026-08-16")).get() // 20 days ago
        let stored = try #require(repository.storedPeriods.first { $0.id == id })
        #expect(stored.startDate == day("2026-08-16"))
        #expect(stored.endDate == day("2026-08-20")) // typical 5
    }

    @Test func startTodayStaysOpen() async throws {
        await coordinator.load()
        let id = try await coordinator.startPeriodReturningID(on: day("2026-09-05")).get()
        #expect(repository.storedPeriods.first { $0.id == id }?.isOpen == true)
    }

    @Test func startTwoDaysAgoWithTypicalFiveStaysOpen() async throws {
        await coordinator.load()
        let id = try await coordinator.startPeriodReturningID(on: day("2026-09-03")).get()
        #expect(repository.storedPeriods.first { $0.id == id }?.isOpen == true)
    }

    @Test func newPeriodFollowsTheTypicalLength() async {
        await coordinator.updateSettings(CycleSettings(typicalPeriodLength: 3))
        #expect(coordinator.newPeriod(startingOn: day("2026-08-01")).endDate == day("2026-08-03"))
        #expect(coordinator.newPeriod(startingOn: day("2026-09-04")).endDate == nil)
    }

    // MARK: - Adding a past period

    @Test func addPastPeriodClosed() async throws {
        await coordinator.load()
        #expect(await coordinator.addPastPeriod(start: day("2026-07-01"), length: 6) == nil)
        let stored = try #require(repository.storedPeriods.first)
        #expect(stored.startDate == day("2026-07-01"))
        #expect(stored.endDate == day("2026-07-06"))
        #expect(coordinator.periods.count == 1)
    }

    @Test func addPastPeriodClampsTheLength() async throws {
        await coordinator.load()
        #expect(await coordinator.addPastPeriod(start: day("2026-06-01"), length: 30) == nil)
        #expect(await coordinator.addPastPeriod(start: day("2026-07-01"), length: 0) == nil)
        let stored = repository.storedPeriods.sorted { $0.startDate < $1.startDate }
        #expect(stored.map(\.endDate) == [day("2026-06-10"), day("2026-07-02")])
    }

    @Test func addPastPeriodEndingAfterTodayIsOpen() async throws {
        await coordinator.load()
        #expect(await coordinator.addPastPeriod(start: day("2026-09-03"), length: 5) == nil)
        let stored = try #require(repository.storedPeriods.first)
        #expect(stored.startDate == day("2026-09-03"))
        #expect(stored.isOpen)
    }

    @Test func addPastPeriodEndingTodayIsClosed() async throws {
        await coordinator.load()
        #expect(await coordinator.addPastPeriod(start: day("2026-09-01"), length: 5) == nil)
        #expect(repository.storedPeriods.first?.endDate == day("2026-09-05"))
    }

    @Test func addPastPeriodOverlapFails() async {
        repository.seed(periods: [PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10"))])
        await coordinator.load()
        #expect(await coordinator.addPastPeriod(start: day("2026-08-04"), length: 4) == .overlapsExistingPeriod)
        #expect(repository.storedPeriods.count == 1)
        #expect(coordinator.periods.count == 1)
        #expect(coordinator.failure == nil)
    }

    @Test func addPastPeriodFutureFails() async {
        await coordinator.load()
        #expect(await coordinator.addPastPeriod(start: day("2026-09-07"), length: 5) == .futureDate)
        #expect(repository.storedPeriods.isEmpty)
        #expect(coordinator.failure == nil)
    }

    @Test func addPastPeriodSaveFailureIsReported() async {
        await coordinator.load()
        repository.failNextWrite = true
        #expect(await coordinator.addPastPeriod(start: day("2026-07-01"), length: 5) == .saveFailed)
        #expect(repository.storedPeriods.isEmpty)
    }

    @Test func addingPastPeriodsFeedsTheAverage() async {
        repository.seed(periods: [PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-05"))])
        await coordinator.load()
        func summary() -> CycleHistorySummary {
            CycleHistory.make(periods: coordinator.periods, logs: [], now: clock.now, calendar: utcCalendar)
        }
        #expect(summary().averageCycleLength == nil)

        #expect(await coordinator.addPastPeriod(start: day("2026-08-03"), length: 5) == nil)
        #expect(summary().averageCycleLength == 29)
        #expect(await coordinator.addPastPeriod(start: day("2026-07-07"), length: 5) == nil)
        #expect(summary().averageCycleLength == 28) // (27 + 29) / 2
        #expect(summary().cycles.count == 3)
    }
}
