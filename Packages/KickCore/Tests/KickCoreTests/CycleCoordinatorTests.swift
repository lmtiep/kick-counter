import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct CycleCoordinatorTests {
    let repository: FakeCycleRepository
    let center: FakeNotificationCenter
    let clock: TestClock
    let defaults: UserDefaults
    let coordinator: CycleCoordinator

    init() {
        let repository = FakeCycleRepository()
        let center = FakeNotificationCenter()
        let clock = TestClock(date("2026-09-05T12:00:00Z"))
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        self.repository = repository
        self.center = center
        self.clock = clock
        self.defaults = defaults
        coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "Fertile window soon", body: "In 2 days"),
                period: NotificationText(title: "Period tomorrow", body: "Due tomorrow"),
                late: NotificationText(title: "Period is late", body: "Consider a test")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Regular 28-day cycles; current period 2026-09-03 → window 09-12…09-18, next period 10-01.
    private func seedRegularCycles() {
        repository.seed(periods: ["2026-07-09", "2026-08-06", "2026-09-03"].map {
            PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0)))
        })
    }

    private func reminderDay(_ kind: CycleReminderKind) -> Int? {
        (center.added.first { $0.identifier == kind.identifier }?.trigger as? UNCalendarNotificationTrigger)?.dateComponents.day
    }

    private var reminderIDs: Set<String> { Set(center.added.map(\.identifier)) }

    // MARK: - Loading

    @Test func loadComputesTheForecastAndSchedulesReminders() async throws {
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.periods.count == 3)
        let forecast = try #require(coordinator.forecast)
        #expect(forecast.cycleDay == 3)
        #expect(forecast.nextPeriodStart == day("2026-10-01"))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
        #expect(reminderDay(.fertile) == 10)
    }

    @Test func loadNeverPromptsForPermission() async {
        seedRegularCycles()
        center.status = .notDetermined
        await coordinator.load()
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied == false)
    }

    @Test func loadInPregnancyModeCancelsCycleReminders() async {
        seedRegularCycles()
        AppMode.save(.pregnant, to: defaults)
        await coordinator.load()
        #expect(coordinator.forecast != nil)
        #expect(center.added.isEmpty)
        #expect(center.removed.contains("cycle-fertile"))
    }

    @Test func loadWithNoDataHasNoForecastOrReminders() async {
        await coordinator.load()
        #expect(coordinator.forecast == nil)
        #expect(center.added.isEmpty)
    }

    @Test func failedLoadReportsLoadFailure() async {
        repository.failNextRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func concurrentLoadsShareOneRefresh() async throws {
        seedRegularCycles()
        center.holdAuthorizationStatus = true
        async let first: Void = coordinator.load() // suspends in isAuthorized()
        defer { center.releaseAuthorizationStatus() }
        try await waitUntil(center.authorizationStatusPending)
        async let second: Void = coordinator.load()
        await Task.yield()
        center.releaseAuthorizationStatus()
        _ = await (first, second)
        #expect(repository.periodReads == 1)
    }

    @Test func failedLogsReadLeavesTheLoadedDataUntouched() async {
        seedRegularCycles()
        repository.failNextLogsRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
        #expect(coordinator.periods.isEmpty)
        #expect(coordinator.forecast == nil)
    }

    @Test func writeWhoseReloadFailsLeavesRemindersAlone() async {
        seedRegularCycles()
        center.status = .notDetermined
        await coordinator.load()
        repository.failNextRead = true
        #expect(await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .creamy)) == nil)
        #expect(repository.storedLogs.count == 1)
        #expect(coordinator.failure == .loadFailed)
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
    }

    // MARK: - Periods

    @Test func startingAPeriodSavesItAndPromptsOnce() async throws {
        center.status = .notDetermined
        let failure = await coordinator.startPeriod(on: date("2026-09-05T08:00:00Z"))
        #expect(failure == nil)
        #expect(repository.storedPeriods == [PeriodRecord(id: try #require(coordinator.periods.first?.id), startDate: day("2026-09-05"))])
        #expect(coordinator.forecast?.cycleDay == 1)
        #expect(center.requestCount == 1)
        // One period: 28-day default → next period 10-03, window 09-14…09-20.
        #expect(reminderDay(.fertile) == 12)
        #expect(reminderDay(.period) == 2)
    }

    /// Undo on Today deletes exactly the record that was created, by id.
    @Test func startingAPeriodReturnsTheNewRecordsID() async throws {
        let stale = PeriodRecord(startDate: day("2026-08-01"))
        repository.seed(periods: [stale], logs: [])
        await coordinator.load()

        let id = try await coordinator.startPeriodReturningID(on: day("2026-09-05")).get()
        let created = try #require(repository.storedPeriods.first { $0.id == id })
        #expect(created.startDate == day("2026-09-05"))
        #expect(id != stale.id)

        #expect(await coordinator.deletePeriod(id: id) == nil)
        #expect(repository.storedPeriods.map(\.id) == [stale.id])
    }

    @Test func aCycleFailureErrorIsKept() {
        #expect(CycleFailure(CycleFailure.overlapsExistingPeriod as Error) == .overlapsExistingPeriod)
    }

    @Test func startingAPeriodReturnsTheFailure() async {
        let result = await coordinator.startPeriodReturningID(on: day("2026-09-06"))
        #expect(throws: CycleFailure.futureDate) { try result.get() }
        #expect(repository.storedPeriods.isEmpty)
    }

    /// A period left open for weeks (never ended) must not block the next one:
    /// it is closed at the typical length and the new period starts today.
    @Test func startingAPeriodClosesAStaleOpenPeriod() async throws {
        let stale = PeriodRecord(startDate: day("2026-08-01"))
        repository.seed(periods: [stale], logs: [])
        await coordinator.load()
        #expect(coordinator.forecast?.isLongOpenPeriod == true)

        #expect(await coordinator.startPeriod(on: day("2026-09-05")) == nil)
        let stored = repository.storedPeriods.sorted { $0.startDate < $1.startDate }
        #expect(stored.count == 2)
        #expect(stored.first?.id == stale.id)
        #expect(stored.first?.endDate == day("2026-08-05")) // typical length 5
        #expect(stored.last?.startDate == day("2026-09-05"))
        #expect(stored.last?.isOpen == true)
        #expect(coordinator.forecast?.cycleDay == 1)
    }

    /// An open period that is still plausible is left alone; the overlap rule applies.
    @Test func startingAPeriodKeepsARecentOpenPeriod() async {
        repository.seed(periods: [PeriodRecord(startDate: day("2026-09-02"))], logs: [])
        await coordinator.load()
        #expect(await coordinator.startPeriod(on: day("2026-09-05")) == .overlapsExistingPeriod)
        #expect(repository.storedPeriods.first?.endDate == nil)
    }

    @Test func lastPeriodFromItsFirstDayUsesTheTypicalLength() async {
        await coordinator.updateSettings(CycleSettings(typicalPeriodLength: 4))
        #expect(await coordinator.logLastPeriod(startingOn: day("2026-08-20")) == nil)
        #expect(coordinator.periods.first?.endDate == day("2026-08-23"))
        #expect(coordinator.forecast?.cycleDay == 17)
    }

    @Test func futurePeriodIsRefusedWithoutAnAlert() async {
        let failure = await coordinator.startPeriod(on: day("2026-09-06"))
        #expect(failure == .futureDate)
        #expect(coordinator.failure == nil)
        #expect(repository.storedPeriods.isEmpty)
    }

    @Test func overlappingPeriodIsRefused() async {
        seedRegularCycles()
        await coordinator.load()
        let failure = await coordinator.startPeriod(on: day("2026-09-05"))
        #expect(failure == .overlapsExistingPeriod)
        #expect(coordinator.periods.count == 3)
    }

    @Test func endingThePeriodStoresTheEndDay() async throws {
        await coordinator.startPeriod(on: day("2026-09-01"))
        let id = try #require(coordinator.periods.first?.id)
        let failure = await coordinator.endPeriod(id: id, on: date("2026-09-04T20:00:00Z"))
        #expect(failure == nil)
        #expect(coordinator.periods.first?.endDate == day("2026-09-04"))
        #expect(coordinator.forecast?.openPeriod == nil)
    }

    @Test func endBeforeStartIsRefused() async throws {
        await coordinator.startPeriod(on: day("2026-09-03"))
        let id = try #require(coordinator.periods.first?.id)
        #expect(await coordinator.endPeriod(id: id, on: day("2026-09-01")) == .endBeforeStart)
        #expect(coordinator.periods.first?.endDate == nil)
    }

    @Test func endingAnUnknownPeriodIsASaveFailure() async {
        #expect(await coordinator.endPeriod(id: UUID(), on: day("2026-09-04")) == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
    }

    @Test func deletingThePeriodRemovesTheForecastAndReminders() async throws {
        await coordinator.startPeriod(on: day("2026-09-05"))
        let id = try #require(coordinator.periods.first?.id)
        #expect(await coordinator.deletePeriod(id: id) == nil)
        #expect(coordinator.forecast == nil)
        #expect(center.added.isEmpty)
    }

    @Test func failedWriteReportsSaveFailureAndSchedulesNothing() async {
        repository.failNextWrite = true
        #expect(await coordinator.startPeriod(on: day("2026-09-05")) == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.periods.isEmpty)
        #expect(center.added.isEmpty)
    }

    @Test func periodLookupFindsTheCoveringPeriod() async {
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.period(on: date("2026-09-06T15:00:00Z"))?.startDate == day("2026-09-03"))
        #expect(coordinator.period(on: day("2026-09-08")) == nil)
    }

    // MARK: - Day logs

    @Test func positiveLHTestMovesOvulationAndTheFertileReminder() async throws {
        seedRegularCycles()
        clock.now = date("2026-09-09T07:00:00Z")
        await coordinator.load()
        #expect(coordinator.forecast?.ovulationDate == day("2026-09-17"))
        #expect(reminderDay(.fertile) == 10)

        let failure = await coordinator.saveLog(CycleLogRecord(day: clock.now, lh: .positive, note: " Strong line "))
        #expect(failure == nil)
        #expect(coordinator.log(on: day("2026-09-09"))?.note == "Strong line")
        #expect(coordinator.forecast?.ovulationDate == day("2026-09-10"))
        #expect(coordinator.forecast?.ovulationSource == .lhTest)
        // Window 09-05…09-11 → the fertile reminder (09-03) has passed.
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func implausibleTemperatureIsRefused() async {
        let failure = await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), bbtCelsius: 39.2))
        #expect(failure == .invalidTemperature)
        #expect(coordinator.failure == nil)
        #expect(repository.storedLogs.isEmpty)
    }

    @Test func emptyLogRemovesTheDay() async {
        await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .creamy))
        #expect(coordinator.logs.count == 1)
        await coordinator.saveLog(CycleLogRecord(day: day("2026-09-05")))
        #expect(coordinator.logs.isEmpty)
        #expect(coordinator.log(on: day("2026-09-05")) == nil)
    }

    // MARK: - Settings

    @Test func typicalCycleLengthDrivesASinglePeriodForecast() async {
        await coordinator.startPeriod(on: day("2026-09-01"))
        #expect(coordinator.forecast?.nextPeriodStart == day("2026-09-29"))
        await coordinator.updateSettings(CycleSettings(typicalCycleLength: 32, typicalPeriodLength: 4))
        #expect(coordinator.settings.typicalCycleLength == 32)
        #expect(defaults.integer(forKey: SettingsKey.typicalCycleLength) == 32)
        #expect(coordinator.forecast?.nextPeriodStart == day("2026-10-03"))
        #expect(reminderDay(.period) == 2)
    }

    @Test func turningRemindersOffCancelsThemAndOnSchedulesAgain() async {
        seedRegularCycles()
        await coordinator.load()
        await coordinator.updateSettings(CycleSettings(remindersEnabled: false))
        #expect(center.added.isEmpty)
        #expect(defaults.bool(forKey: SettingsKey.cycleRemindersEnabled) == false)
        await coordinator.updateSettings(CycleSettings(remindersEnabled: true))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func deniedNotificationsStillSaveAndRaiseTheHint() async {
        center.status = .denied
        #expect(await coordinator.startPeriod(on: day("2026-09-05")) == nil)
        #expect(coordinator.periods.count == 1)
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied)
    }

    // MARK: - Mode

    @Test func imPregnantStoresTheLastPeriodSwitchesModeAndCancelsReminders() async throws {
        seedRegularCycles()
        await coordinator.load()
        #expect(center.added.count == 3)
        let lastPeriod = try #require(coordinator.forecast?.currentPeriodStart)

        coordinator.switchToPregnant(source: .lmp, date: lastPeriod)

        #expect(coordinator.mode == .pregnant)
        #expect(AppMode.load(from: defaults) == .pregnant)
        let profile = PregnancyProfile.load(from: defaults)
        #expect(profile.source == .lmp)
        #expect(profile.lmpDate == day("2026-09-03"))
        #expect(profile.dueDate == day("2027-06-10"))
        #expect(center.added.isEmpty)
        #expect(repository.storedPeriods.count == 3)
        // A later load in pregnancy mode keeps them cancelled.
        await coordinator.load()
        #expect(center.added.isEmpty)
    }

    @Test func switchingToTryingToConceiveKeepsPregnancyDataAndSchedulesReminders() async {
        AppMode.save(.pregnant, to: defaults)
        PregnancyProfile.saveDueDate(date("2027-01-19T12:00:00Z"), to: defaults)
        seedRegularCycles()
        await coordinator.load()
        #expect(center.added.isEmpty)

        await coordinator.activateTryingToConceive()

        #expect(coordinator.mode == .tryingToConceive)
        #expect(PregnancyProfile.load(from: defaults).dueDate == date("2027-01-19T12:00:00Z"))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    // MARK: - Re-entrancy

    @Test func imPregnantWhileThePermissionPromptIsOpenLeavesNoReminders() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let starting = coordinator.startPeriod(on: day("2026-09-05")) // suspends on the prompt
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)

        coordinator.switchToPregnant(source: .lmp, date: day("2026-09-05"))
        center.releaseRequestAuthorization()
        _ = await starting

        #expect(center.added.isEmpty)
        #expect(coordinator.mode == .pregnant)
    }

    @Test func changeDuringThePromptIsScheduledOnceGranted() async throws {
        seedRegularCycles()
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let saving = coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .sticky))
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)

        // A second change while the prompt is still open (status is still "not determined").
        _ = await coordinator.updateSettings(CycleSettings(typicalCycleLength: 30))
        center.releaseRequestAuthorization()
        _ = await saving

        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func imPregnantWhileSchedulingIsInFlightRemovesTheReminders() async throws {
        seedRegularCycles()
        await coordinator.load()
        center.holdAdd = true

        async let saving = coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .creamy)) // suspends in center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)

        coordinator.switchToPregnant(source: .lmp, date: day("2026-09-03"))
        center.releaseAdd()
        _ = await saving

        #expect(center.added.isEmpty)
    }

    @Test func newestForecastWinsWhenAnOlderScheduleLandsLast() async throws {
        seedRegularCycles()
        clock.now = date("2026-09-09T07:00:00Z")
        await coordinator.load()
        center.holdAdd = true

        async let first = coordinator.saveLog(CycleLogRecord(day: day("2026-09-08"), mucus: .creamy)) // suspends in center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)

        // LH positive today: ovulation 09-10, window 09-05…09-11 → no fertile reminder.
        await coordinator.saveLog(CycleLogRecord(day: day("2026-09-09"), lh: .positive))
        center.releaseAdd()
        _ = await first

        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func loadWhileSchedulingIsInFlightWins() async throws {
        seedRegularCycles()
        clock.now = date("2026-09-09T07:00:00Z")
        await coordinator.load()
        center.holdAdd = true

        async let saving = coordinator.saveLog(CycleLogRecord(day: day("2026-09-08"), mucus: .creamy)) // suspends in center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)

        // iCloud brings a positive LH test for today: window 09-05…09-11 → no fertile reminder.
        repository.seed(logs: [CycleLogRecord(day: day("2026-09-09"), lh: .positive)])
        await coordinator.load()
        center.releaseAdd()
        _ = await saving

        #expect(coordinator.forecast?.ovulationSource == .lhTest)
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func changeThatCannotScheduleItselfIsAppliedOncePermissionIsGranted() async throws {
        seedRegularCycles()
        clock.now = date("2026-09-09T07:00:00Z")
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let saving = coordinator.saveLog(CycleLogRecord(day: day("2026-09-08"), mucus: .creamy)) // suspends on the prompt
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)

        // The reload never prompts and permission is still undecided, so it schedules nothing itself.
        repository.seed(logs: [CycleLogRecord(day: day("2026-09-09"), lh: .positive)])
        await coordinator.load()
        #expect(center.added.isEmpty)
        center.releaseRequestAuthorization()
        _ = await saving

        #expect(center.requestCount == 1)
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func imPregnantWhileAFailingScheduleIsInFlightLeavesNoReminders() async throws {
        seedRegularCycles()
        await coordinator.load()
        center.holdAdd = true

        async let saving = coordinator.saveLog(CycleLogRecord(day: day("2026-09-05"), mucus: .creamy)) // suspends in the first center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)

        coordinator.switchToPregnant(source: .lmp, date: day("2026-09-03"))
        center.failNextAdd = true // the held fertile reminder lands, the next request fails
        center.releaseAdd()
        _ = await saving

        #expect(center.added.isEmpty)
    }
}
