import Foundation
import Testing
@testable import KickCore

/// In-memory ContractionRepository with the same rules as ContractionStore.
@MainActor
final class FakeContractionRepository: ContractionRepository {
    struct Failed: Error {}

    private(set) var stored: [ContractionRecord] = []
    var failNextRead = false
    var failNextWrite = false

    func seed(_ records: ContractionRecord...) { stored += records }
    func eraseAll() { stored = [] }

    func contractions() throws -> [ContractionRecord] {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
        return stored.sorted { $0.startedAt < $1.startedAt }
    }

    func save(_ record: ContractionRecord) throws {
        try ContractionRules.validate(record, existing: stored)
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        if let index = stored.firstIndex(where: { $0.id == record.id }) {
            stored[index] = record
        } else {
            stored.append(record)
        }
    }

    func delete(ids: [UUID]) throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        stored.removeAll { ids.contains($0.id) }
    }
}

@MainActor
final class FakeContractionLiveActivities: ContractionLiveActivityManaging {
    var isAvailable = true
    private(set) var activeEpisode: UUID?
    private(set) var started: [(episodeID: UUID, startedAt: Date, state: ContractionActivityState, staleDate: Date)] = []
    private(set) var updates: [(episodeID: UUID, state: ContractionActivityState, staleDate: Date)] = []
    private(set) var endAllCount = 0

    /// One-shot gate: the next `start` suspends until `releaseStart()`.
    var holdStart = false
    private(set) var startPending = false
    private var startContinuations: [CheckedContinuation<Void, Never>] = []

    func hasActivity(for episodeID: UUID) -> Bool { activeEpisode == episodeID }

    func start(episodeID: UUID, startedAt: Date, state: ContractionActivityState, staleDate: Date) async {
        if holdStart {
            holdStart = false
            startPending = true
            await withCheckedContinuation { startContinuations.append($0) }
            startPending = false
        }
        activeEpisode = episodeID
        started.append((episodeID, startedAt, state, staleDate))
    }

    func releaseStart() {
        let continuations = startContinuations
        startContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    func update(episodeID: UUID, state: ContractionActivityState, staleDate: Date) async {
        guard activeEpisode == episodeID else { return }
        updates.append((episodeID, state, staleDate))
    }

    func endAll() async {
        endAllCount += 1
        activeEpisode = nil
    }
}

@MainActor
struct ContractionCoordinatorTests {
    let store = FakeContractionRepository()
    let live = FakeContractionLiveActivities()
    let defaults = makeTestDefaults()
    let clock = TestClock(date("2026-10-10T12:00:00Z"))
    let coordinator: ContractionCoordinator

    init() {
        let clock = clock
        coordinator = ContractionCoordinator(store: store, liveActivities: live, defaults: defaults, now: { clock.now })
    }

    private func makeCoordinator() -> ContractionCoordinator {
        let clock = clock
        return ContractionCoordinator(store: store, liveActivities: live, defaults: defaults, now: { clock.now })
    }

    /// Times one contraction of `duration` seconds, then rests `rest` seconds.
    private func time(_ duration: TimeInterval = 60, rest: TimeInterval = 240) async {
        await coordinator.toggle()
        clock.advance(duration)
        await coordinator.toggle()
        clock.advance(rest)
    }

    // MARK: - Toggle

    @Test func toggleStartsThenStops() async throws {
        let started = try #require(await coordinator.toggle())
        guard case .started(let record) = started else { Issue.record("expected started"); return }
        #expect(record.startedAt == clock.now)
        #expect(coordinator.running?.id == record.id)

        clock.advance(50)
        let stopped = try #require(await coordinator.toggle())
        guard case .stopped(let closed) = stopped else { Issue.record("expected stopped"); return }
        #expect(closed.endedAt == clock.now)
        #expect(coordinator.running == nil)
        #expect(store.stored == [closed])
        #expect(coordinator.contractions == [closed])
    }

    @Test func aStopUnderThreeSecondsDropsTheMisTap() async throws {
        await coordinator.toggle()
        clock.advance(2.9)
        let result = try #require(await coordinator.toggle())
        guard case .discarded = result else { Issue.record("expected discarded"); return }
        #expect(store.stored.isEmpty)
        #expect(coordinator.contractions.isEmpty)
    }

    @Test func aStopAtThreeSecondsKeepsIt() async {
        await coordinator.toggle()
        clock.advance(3)
        await coordinator.toggle()
        #expect(store.stored.count == 1)
        #expect(store.stored.first?.endedAt == clock.now)
    }

    /// After 5 minutes the screen shows "Bắt đầu" (the stats close the forgotten
    /// one), so the tap closes it at 5:00 and starts the contraction she meant.
    @Test func aTapAfterFiveMinutesClosesItAtFiveMinutesAndStartsANewOne() async throws {
        await coordinator.toggle()
        let start = clock.now
        clock.advance(420)
        let result = try #require(await coordinator.toggle())
        guard case .started(let record) = result else { Issue.record("expected started"); return }
        #expect(record.startedAt == clock.now)
        #expect(store.stored.count == 2)
        #expect(store.stored.first?.endedAt == start.addingTimeInterval(300))
        #expect(coordinator.running?.id == record.id)
        #expect(coordinator.stats(week: nil).running?.id == record.id)
    }

    @Test func undoAfterAForgottenTapDeletesOnlyTheNewContraction() async {
        await coordinator.toggle()
        let start = clock.now
        clock.advance(420)
        await coordinator.toggle()
        #expect(await coordinator.undoLast())
        #expect(store.stored.count == 1)
        #expect(store.stored.first?.startedAt == start)
        #expect(store.stored.first?.endedAt == start.addingTimeInterval(300))
        #expect(coordinator.running == nil)
    }

    /// The Lock Screen still showed "Hết cơn" (its timer stops at 5:00): a stop.
    @Test func aStopActionAfterFiveMinutesOnlyClosesIt() async throws {
        await coordinator.toggle()
        let start = clock.now
        clock.advance(420)
        let result = try #require(await coordinator.toggle(.stop))
        guard case .stopped(let closed) = result else { Issue.record("expected stopped"); return }
        #expect(closed.endedAt == start.addingTimeInterval(300))
        #expect(coordinator.running == nil)
    }

    @Test func aStartActionAfterFiveMinutesClosesItAndStartsANewOne() async throws {
        await coordinator.toggle()
        clock.advance(420)
        let result = try #require(await coordinator.toggle(.start))
        guard case .started = result else { Issue.record("expected started"); return }
        #expect(store.stored.count == 2)
        #expect(coordinator.running?.startedAt == clock.now)
    }

    /// A Lock Screen button pressed on an out-of-date state does nothing.
    @Test func anActionThatDoesNotMatchTheStateIsANoOp() async {
        #expect(await coordinator.toggle(.stop) == nil)
        #expect(store.stored.isEmpty)
        #expect(coordinator.lastToggle == nil)

        await coordinator.toggle(.start)
        let running = coordinator.running
        clock.advance(30)
        #expect(await coordinator.toggle(.start) == nil)
        #expect(coordinator.running == running)
        #expect(coordinator.failure == nil)
        clock.advance(30)
        #expect(await coordinator.toggle(.stop) != nil)
        #expect(coordinator.running == nil)
    }

    /// The clock moved backwards between the taps: never an end before the start.
    @Test func aStopWithTheClockMovedBackwardsEndsNoEarlierThanTheStart() async {
        await coordinator.toggle()
        let start = clock.now
        clock.advance(-10)
        let result = await coordinator.toggle()
        #expect(result != nil)
        #expect(coordinator.failure == nil)
        #expect(store.stored.allSatisfy { ($0.endedAt ?? start) >= $0.startedAt })
        #expect(coordinator.running == nil)
    }

    @Test func loadClosesAForgottenContraction() async {
        let start = clock.now.addingTimeInterval(-600)
        store.seed(ContractionRecord(startedAt: start))
        await coordinator.load()
        #expect(store.stored.first?.endedAt == start.addingTimeInterval(300))
        #expect(coordinator.running == nil)
    }

    @Test func loadKeepsARunningContractionUnderFiveMinutes() async {
        store.seed(ContractionRecord(startedAt: clock.now.addingTimeInterval(-300)))
        await coordinator.load()
        #expect(store.stored.first?.endedAt == nil)
        #expect(coordinator.running != nil)
    }

    @Test func aFailedSaveIsReported() async {
        store.failNextWrite = true
        let result = await coordinator.toggle()
        #expect(result == nil)
        #expect(coordinator.failure == .saveFailed)
        #expect(store.stored.isEmpty)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func aFailedLoadIsReported() async {
        store.failNextRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
        await coordinator.load()
        #expect(coordinator.failure == nil)
    }

    // MARK: - Undo

    @Test func undoAStartRemovesIt() async {
        await coordinator.toggle()
        clock.advance(2)
        #expect(coordinator.canUndo)
        await coordinator.undoLast()
        #expect(store.stored.isEmpty)
        #expect(!coordinator.canUndo)
    }

    @Test func undoAStopResumesTheContraction() async {
        await coordinator.toggle()
        clock.advance(40)
        await coordinator.toggle()
        await coordinator.undoLast()
        #expect(store.stored.count == 1)
        #expect(store.stored.first?.endedAt == nil)
        #expect(coordinator.running != nil)
    }

    @Test func undoADiscardedMisTapRestoresItRunning() async {
        await coordinator.toggle()
        let start = clock.now
        clock.advance(1)
        await coordinator.toggle()
        await coordinator.undoLast()
        #expect(store.stored.map(\.startedAt) == [start])
        #expect(coordinator.running?.startedAt == start)
    }

    @Test func undoOnlyWithinFiveSeconds() async {
        await coordinator.toggle()
        clock.advance(5)
        #expect(coordinator.canUndo)
        clock.advance(0.1)
        #expect(!coordinator.canUndo)
        await coordinator.undoLast()
        #expect(store.stored.count == 1, "too late: nothing is undone")
    }

    @Test func undoOnlyOnce() async {
        await time(40, rest: 1)
        await coordinator.undoLast()
        await coordinator.undoLast()
        #expect(store.stored.count == 1)
        #expect(store.stored.first?.endedAt == nil)
    }

    @Test func undoReportsWhetherItReverted() async {
        await coordinator.toggle()
        #expect(await coordinator.undoLast())
        #expect(await coordinator.undoLast() == false)
        await coordinator.toggle()
        store.failNextWrite = true
        #expect(await coordinator.undoLast() == false)
        #expect(coordinator.failure == .saveFailed)
    }

    @Test func theUndoDeadlineIsFiveSecondsAfterTheTap() async {
        #expect(coordinator.undoDeadline == nil)
        await coordinator.toggle()
        #expect(coordinator.undoDeadline == clock.now.addingTimeInterval(ContractionRules.undoWindow))
        await coordinator.undoLast()
        #expect(coordinator.undoDeadline == nil)
    }

    @Test func aLongerUndoWindowForUITests() async {
        let clock = clock
        let slow = ContractionCoordinator(
            store: store, liveActivities: live, defaults: defaults, undoWindow: 30, now: { clock.now }
        )
        await slow.toggle()
        clock.advance(20)
        #expect(slow.canUndo)
        #expect(slow.undoDeadline == clock.now.addingTimeInterval(10))
        #expect(await slow.undoLast())
        #expect(store.stored.isEmpty)
    }

    @Test func undoWithNothingToUndoIsANoOp() async {
        await coordinator.undoLast()
        #expect(store.stored.isEmpty)
        #expect(coordinator.failure == nil)
    }

    // MARK: - Delete and end

    @Test func deleteRemovesOneContraction() async throws {
        await time()
        await time()
        let first = try #require(coordinator.contractions.first)
        await coordinator.delete(id: first.id)
        #expect(coordinator.contractions.count == 1)
        #expect(!coordinator.contractions.contains { $0.id == first.id })
        #expect(!coordinator.canUndo)
    }

    @Test func deleteSeveralRemovesAWholeEpisode() async {
        await time()
        await time()
        await coordinator.delete(ids: coordinator.contractions.map(\.id))
        #expect(store.stored.isEmpty)
        #expect(live.endAllCount >= 1)
        #expect(live.activeEpisode == nil)
    }

    @Test func endEpisodeStopsTheRunningContractionAndEndsTheActivity() async {
        await time()
        await coordinator.toggle()
        clock.advance(30)
        await coordinator.endEpisode()
        #expect(coordinator.running == nil)
        #expect(store.stored.allSatisfy { $0.endedAt != nil })
        #expect(live.activeEpisode == nil)
        #expect(coordinator.episodeEndedAt == clock.now)
        #expect(coordinator.stats(week: nil).currentEpisode == nil)
    }

    @Test func endEpisodeDropsARunningMisTap() async {
        await coordinator.toggle()
        clock.advance(1)
        await coordinator.endEpisode()
        #expect(store.stored.isEmpty)
    }

    @Test func endEpisodeDoesNothingWhenTheStoreCannotBeRead() async {
        await coordinator.toggle()
        clock.advance(30)
        store.failNextRead = true
        #expect(await coordinator.endEpisode() == false)
        #expect(coordinator.episodeEndedAt == nil)
        #expect(defaults.object(forKey: SettingsKey.contractionEpisodeEndedAt) == nil)
        #expect(store.stored.first?.endedAt == nil)
    }

    @Test func endEpisodeDoesNothingWhenStoppingFails() async {
        await coordinator.toggle()
        clock.advance(30)
        store.failNextWrite = true
        #expect(await coordinator.endEpisode() == false)
        #expect(coordinator.episodeEndedAt == nil)
        #expect(coordinator.running != nil)
        #expect(live.activeEpisode != nil)
    }

    @Test func theEpisodeEndIsRemembered() async {
        await time()
        await coordinator.endEpisode()
        let reopened = makeCoordinator()
        await reopened.load()
        #expect(reopened.episodeEndedAt == clock.now)
        #expect(reopened.stats(week: nil).currentEpisode == nil)
        #expect(defaults.object(forKey: SettingsKey.contractionEpisodeEndedAt) as? Date == clock.now)
    }

    @Test func aNewContractionAfterEndingStartsANewEpisode() async throws {
        await time()
        await coordinator.endEpisode()
        clock.advance(60)
        let firstEpisode = live.started.first?.episodeID
        await time()
        let current = try #require(coordinator.stats(week: nil).currentEpisode)
        #expect(current.count == 1)
        #expect(live.started.count == 2)
        #expect(live.started.last?.episodeID != firstEpisode)
    }

    @Test func resetAfterDataDeletionForgetsEverything() async {
        await time()
        await coordinator.toggle()
        await coordinator.endEpisode()
        store.eraseAll()
        AppDataReset.clearDefaults(defaults)
        await coordinator.resetAfterDataDeletion()
        #expect(coordinator.contractions.isEmpty)
        #expect(coordinator.episodeEndedAt == nil)
        #expect(!coordinator.canUndo)
        #expect(coordinator.failure == nil)
        #expect(live.activeEpisode == nil)
    }

    // MARK: - Stats

    @Test func statsUseTheWeekAndTheClock() async {
        for _ in 0..<4 { await time(60, rest: 540) }
        #expect(coordinator.stats(week: GestationalWeek(weeks: 33, days: 0)).alert == .pretermRegular)
        #expect(coordinator.stats(week: GestationalWeek(weeks: 38, days: 0)).alert == .none)
        #expect(coordinator.stats(week: nil).lastHour.count == 4)
        #expect(coordinator.stats(week: nil, at: clock.now.addingTimeInterval(3600)).lastHour.count == 0)
    }

    // MARK: - Live Activity

    @Test func theFirstContractionStartsTheActivity() async throws {
        await coordinator.toggle()
        let start = try #require(live.started.first)
        let first = try #require(coordinator.contractions.first)
        #expect(live.started.count == 1)
        #expect(start.episodeID == first.id)
        #expect(start.startedAt == first.startedAt)
        #expect(start.state == ContractionActivityState(runningSince: first.startedAt, count: 1, lastInterval: nil, lastDuration: nil))
        #expect(start.staleDate == first.startedAt.addingTimeInterval(ContractionRules.episodeGap))
    }

    @Test func everyToggleUpdatesTheActivity() async throws {
        await time(50, rest: 250)
        await coordinator.toggle()
        let latest = try #require(live.updates.last)
        let second = try #require(coordinator.running)
        #expect(live.started.count == 1)
        #expect(latest.state == ContractionActivityState(runningSince: second.startedAt, count: 2, lastInterval: 300, lastDuration: 50))
        #expect(latest.staleDate == second.startedAt.addingTimeInterval(ContractionRules.episodeGap))

        clock.advance(70)
        await coordinator.toggle()
        #expect(live.updates.last?.state == ContractionActivityState(runningSince: nil, count: 2, lastInterval: 300, lastDuration: 70))
    }

    @Test func undoUpdatesTheActivity() async {
        await time(50, rest: 250)
        await coordinator.toggle()
        await coordinator.undoLast()
        #expect(live.updates.last?.state == ContractionActivityState(runningSince: nil, count: 1, lastInterval: nil, lastDuration: 50))
    }

    @Test func undoingTheOnlyStartEndsTheActivity() async {
        await coordinator.toggle()
        await coordinator.undoLast()
        #expect(live.activeEpisode == nil)
    }

    @Test func noActivityWhenUnavailable() async {
        live.isAvailable = false
        await time()
        #expect(live.started.isEmpty)
        #expect(store.stored.count == 1)
    }

    @Test func loadEndsTheActivityAfterTwoHoursIdle() async {
        await time(60, rest: 0)
        #expect(live.activeEpisode != nil)
        clock.advance(ContractionRules.episodeGap - 60)
        await coordinator.load()
        #expect(live.activeEpisode != nil, "exactly two hours after the last start it still runs")
        clock.advance(1)
        await coordinator.load()
        #expect(live.activeEpisode == nil)
    }

    @Test func loadStartsAMissingActivityForTheCurrentEpisode() async {
        let start = clock.now.addingTimeInterval(-600)
        store.seed(ContractionRecord(startedAt: start, endedAt: start.addingTimeInterval(60)))
        await coordinator.load()
        #expect(live.started.count == 1)
        #expect(live.started.first?.state.count == 1)
    }

    @Test func aToggleWhileTheStartIsInFlightDoesNotStartTwice() async throws {
        live.holdStart = true
        let first = Task { await coordinator.toggle() }
        try await waitUntil(live.startPending)
        clock.advance(30)
        let second = Task { await coordinator.toggle() }
        await Task.yield()
        live.releaseStart()
        _ = await first.value
        _ = await second.value
        #expect(live.started.count == 1)
        #expect(live.updates.last?.state.runningSince == nil, "the activity ends on the latest state")
        #expect(live.updates.last?.state.lastDuration == 30)
    }

    // MARK: - Alerts on the Lock Screen and as a notification

    private func alertingCoordinator(
        _ center: FakeNotificationCenter, week: GestationalWeek? = GestationalWeek(weeks: 38, days: 0)
    ) -> ContractionCoordinator {
        let clock = clock
        return ContractionCoordinator(
            store: store,
            liveActivities: live,
            notifications: NotificationScheduler(center: center),
            alertText: { alert in NotificationText(title: "alert", body: "\(alert)") },
            defaults: defaults,
            week: { week },
            now: { clock.now }
        )
    }

    /// 13 contractions of 1:00 every 5:00: 5-1-1 from the 13th stop (span 60:00).
    private func timeFiveOneOne(_ coordinator: ContractionCoordinator, count: Int = 13) async {
        for index in 0..<count {
            await coordinator.toggle()
            clock.advance(60)
            await coordinator.toggle()
            if index < count - 1 { clock.advance(240) }
        }
    }

    @Test func theActivityCarriesTheAlertForTheRealWeek() async {
        let center = FakeNotificationCenter()
        let coordinator = alertingCoordinator(center)
        await timeFiveOneOne(coordinator, count: 12)
        #expect(live.updates.last?.state.alert == ContractionAlert.none)
        clock.advance(240)
        await coordinator.toggle()
        clock.advance(60)
        await coordinator.toggle()
        #expect(live.updates.last?.state.alert == .fiveOneOne)
    }

    @Test func thePretermAlertUsesTheWeekProvider() async {
        let center = FakeNotificationCenter()
        let coordinator = alertingCoordinator(center, week: GestationalWeek(weeks: 33, days: 0))
        for _ in 0..<4 {
            await coordinator.toggle()
            clock.advance(60)
            await coordinator.toggle()
            clock.advance(540)
        }
        #expect(live.updates.last?.state.alert == .pretermRegular)
        #expect(center.addCount == 1)
        #expect(center.added.first?.identifier.hasPrefix("contraction-alert-") == true)
        #expect(center.added.first?.trigger == nil, "delivered right away")
    }

    @Test func oneNotificationWhenTheAlertStarts() async throws {
        let center = FakeNotificationCenter()
        let coordinator = alertingCoordinator(center)
        await timeFiveOneOne(coordinator, count: 12)
        #expect(center.addCount == 0)
        clock.advance(240)
        await coordinator.toggle()
        clock.advance(60)
        await coordinator.toggle()
        #expect(center.addCount == 1)
        let first = try #require(coordinator.contractions.first)
        #expect(center.added.first?.identifier == "contraction-alert-\(first.id.uuidString)")
        #expect(center.added.first?.content.body == "fiveOneOne")

        // More contractions with the alert on: no new notification.
        clock.advance(240)
        await coordinator.toggle()
        clock.advance(60)
        await coordinator.toggle()
        #expect(center.addCount == 1)
    }

    @Test func theSameAlertIsNotPostedAgainInTheSameRun() async {
        let center = FakeNotificationCenter()
        let coordinator = alertingCoordinator(center)
        await timeFiveOneOne(coordinator)
        #expect(center.addCount == 1)
        // Undo the stop (the alert goes off), stop again (it comes back): not again.
        await coordinator.undoLast()
        await coordinator.toggle()
        #expect(coordinator.stats(week: GestationalWeek(weeks: 38, days: 0)).alert == .fiveOneOne)
        #expect(center.addCount == 1)
        // Nor after a relaunch.
        let relaunched = alertingCoordinator(center)
        await relaunched.load()
        clock.advance(240)
        await relaunched.toggle()
        clock.advance(60)
        await relaunched.toggle()
        #expect(center.addCount == 1)
    }

    @Test func aStopActionFromTheLockScreenAlsoNotifies() async {
        let center = FakeNotificationCenter()
        let coordinator = alertingCoordinator(center)
        await timeFiveOneOne(coordinator, count: 12)
        clock.advance(240)
        await coordinator.toggle(.start)
        clock.advance(60)
        await coordinator.toggle(.stop)
        #expect(center.addCount == 1)
    }

    @Test func noNotificationWithoutPermissionAndNoPrompt() async {
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        let coordinator = alertingCoordinator(center)
        await timeFiveOneOne(coordinator)
        #expect(center.addCount == 0)
        #expect(center.requestCount == 0)
        #expect(live.updates.last?.state.alert == .fiveOneOne, "the Lock Screen still shows it")
    }

    @Test func endLiveActivityEndsItWithoutTouchingTheData() async {
        await time()
        #expect(live.activeEpisode != nil)
        await coordinator.endLiveActivity()
        #expect(live.activeEpisode == nil)
        #expect(store.stored.count == 1)
        #expect(coordinator.episodeEndedAt == nil)
    }
}
