import Foundation
import Testing
@testable import KickCore

@MainActor
final class FakeLabourMarkerRepository: LabourMarkerRepository {
    struct Failed: Error {}

    private(set) var stored: [LabourMarkerRecord] = []
    var failNextWrite = false

    func markers() throws -> [LabourMarkerRecord] { stored.sorted { $0.at < $1.at } }

    func save(_ record: LabourMarkerRecord) throws {
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

/// Edit spec 2026-11-06: update, add a missed contraction, the water-broke
/// marker, and what each does to the stats, the Live Activity and the alert.
@MainActor
struct ContractionEditCoordinatorTests {
    let store = FakeContractionRepository()
    let markerStore = FakeLabourMarkerRepository()
    let live = FakeContractionLiveActivities()
    let defaults = makeTestDefaults()
    let center = FakeNotificationCenter()
    let clock = TestClock(date("2026-11-06T12:00:00Z"))
    let term = GestationalWeek(weeks: 38, days: 0)

    private func makeCoordinator() -> ContractionCoordinator {
        let clock = clock
        let term = term
        return ContractionCoordinator(
            store: store,
            markers: markerStore,
            liveActivities: live,
            notifications: NotificationScheduler(center: center),
            alertText: { alert in NotificationText(title: "alert", body: "\(alert)") },
            defaults: defaults,
            week: { term },
            now: { clock.now }
        )
    }

    private func at(_ secondsAgo: TimeInterval) -> Date { clock.now.addingTimeInterval(-secondsAgo) }

    private func done(_ startAgo: TimeInterval, lasting duration: TimeInterval = 60) -> ContractionRecord {
        ContractionRecord(startedAt: at(startAgo), endedAt: at(startAgo).addingTimeInterval(duration))
    }

    /// Three 60 s contractions 5 minutes apart, loaded.
    private func threeLoaded() async -> (ContractionCoordinator, [ContractionRecord]) {
        let records = [done(900), done(600), done(300)]
        store.seed(records[0], records[1], records[2])
        let coordinator = makeCoordinator()
        await coordinator.load()
        return (coordinator, records)
    }

    /// 13 contractions `every` seconds apart, `lasting` long, the newest starting 120 s ago:
    /// 5-1-1 (span 60:00) when `every` is 300 and `lasting` 60.
    private func seedRun(lasting duration: TimeInterval = 60) -> [ContractionRecord] {
        let records = (0..<13).map { done(120 + Double(12 - $0) * 300, lasting: duration) }
        for record in records { store.seed(record) }
        return records
    }

    // MARK: - update

    @Test func updateChangesTheTimesAndRecomputesTheStats() async throws {
        let (coordinator, records) = await threeLoaded()
        let outcome = await coordinator.update(id: records[1].id, start: at(620), end: at(540))
        #expect(outcome == .saved)
        let stored = try #require(store.stored.first { $0.id == records[1].id })
        #expect(stored.startedAt == at(620))
        #expect(stored.endedAt == at(540))
        let episode = try #require(coordinator.stats(week: term).currentEpisode)
        #expect(episode.entries.map(\.duration) == [60, 80, 60])
        #expect(episode.entries.map(\.interval) == [nil, 280, 320])
        #expect(coordinator.stats(week: term).lastHour.count == 3)
    }

    @Test func updateRefusesAnOverlapAndChangesNothing() async {
        let (coordinator, records) = await threeLoaded()
        let before = store.stored
        let outcome = await coordinator.update(id: records[1].id, start: at(870), end: at(800))
        #expect(outcome == .invalid(.overlapsNeighbour))
        #expect(store.stored == before)
        #expect(coordinator.failure == nil)
    }

    @Test func updateOfARunningContractionIsNotEditable() async {
        let running = ContractionRecord(startedAt: at(30))
        store.seed(running)
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(await coordinator.update(id: running.id, start: at(100), end: at(50)) == .invalid(.notEditable))
        #expect(await coordinator.update(id: UUID(), start: at(100), end: at(50)) == .invalid(.notEditable))
    }

    @Test func updateRefusesAFutureEnd() async {
        let (coordinator, records) = await threeLoaded()
        let outcome = await coordinator.update(id: records[2].id, start: at(300), end: clock.now.addingTimeInterval(5))
        #expect(outcome == .invalid(.endInFuture))
    }

    @Test func updateMovesAContractionIntoAnotherEpisode() async throws {
        let early = done(18_000), middle = done(17_700), late = done(600)
        store.seed(early, middle, late)
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(coordinator.stats(week: term).episodes.map(\.count) == [2, 1])

        #expect(await coordinator.update(id: middle.id, start: at(1200), end: at(1140)) == .saved)

        let episodes = coordinator.stats(week: term).episodes
        #expect(episodes.map(\.count) == [1, 2])
        #expect(episodes[1].entries.map(\.id) == [middle.id, late.id])
        #expect(coordinator.stats(week: term).currentEpisode?.id == middle.id)
    }

    @Test func updateSyncsTheLiveActivity() async {
        let (coordinator, records) = await threeLoaded()
        #expect(live.started.count == 1)
        #expect(await coordinator.update(id: records[2].id, start: at(300), end: at(210)) == .saved)
        #expect(live.updates.last?.state.lastDuration == 90)
    }

    @Test func updateReportsAStoreFailure() async {
        let (coordinator, records) = await threeLoaded()
        store.failNextWrite = true
        #expect(await coordinator.update(id: records[0].id, start: at(900), end: at(840)) == .failed)
        #expect(coordinator.failure == .saveFailed)
    }

    @Test func updateClearsTheUndoOfTheLastTap() async {
        let coordinator = makeCoordinator()
        await coordinator.toggle()
        clock.advance(60)
        await coordinator.toggle()
        let record = coordinator.contractions[0]
        #expect(coordinator.lastToggle != nil)
        _ = await coordinator.update(id: record.id, start: record.startedAt, end: record.startedAt.addingTimeInterval(50))
        #expect(coordinator.lastToggle == nil)
    }

    // MARK: - addMissed

    @Test func addMissedJoinsTheEpisodeByTime() async throws {
        let (coordinator, records) = await threeLoaded()
        let outcome = await coordinator.addMissed(start: at(750), duration: 60)
        #expect(outcome == .saved)
        let episode = try #require(coordinator.stats(week: term).currentEpisode)
        #expect(episode.count == 4)
        #expect(episode.entries[1].startedAt == at(750))
        #expect(episode.entries.map(\.id).contains(records[0].id))
        #expect(store.stored.count == 4)
    }

    @Test func addMissedRefusesTheFuture() async {
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(await coordinator.addMissed(start: clock.now.addingTimeInterval(10), duration: 60) == .invalid(.startInFuture))
        #expect(await coordinator.addMissed(start: at(30), duration: 60) == .invalid(.endInFuture))
        #expect(store.stored.isEmpty)
    }

    @Test func addMissedRefusesAnOverlapAndBadLengths() async {
        let (coordinator, _) = await threeLoaded()
        #expect(await coordinator.addMissed(start: at(630), duration: 60) == .invalid(.overlapsNeighbour))
        #expect(await coordinator.addMissed(start: at(750), duration: 2) == .invalid(.tooShort))
        #expect(await coordinator.addMissed(start: at(750), duration: 301) == .invalid(.tooLong))
        #expect(store.stored.count == 3)
    }

    @Test func addMissedRefusesAnOverlapWithARunningContraction() async {
        let running = ContractionRecord(startedAt: at(90))
        store.seed(running)
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(await coordinator.addMissed(start: at(120), duration: 60) == .invalid(.overlapsNeighbour))
        #expect(await coordinator.addMissed(start: at(240), duration: 60) == .saved)
        #expect(coordinator.running?.id == running.id)
    }

    @Test func addMissedSyncsTheLiveActivity() async {
        let (coordinator, _) = await threeLoaded()
        #expect(await coordinator.addMissed(start: at(750), duration: 60) == .saved)
        #expect(live.updates.last?.state.count == 4)
    }

    // MARK: - water broke

    @Test func markWaterBrokeStoresTheMarkerAndShowsItInTheStats() async throws {
        let (coordinator, _) = await threeLoaded()
        #expect(await coordinator.markWaterBroke(at: at(400)) == .saved)
        let marker = try #require(markerStore.stored.first)
        #expect(marker.kind == "waterBroke")
        #expect(marker.at == at(400))
        #expect(coordinator.markers == [marker])
        #expect(coordinator.stats(week: term).currentMarkers == [marker])
        #expect(coordinator.stats(week: term).currentEpisode?.markers == [marker])
    }

    @Test func markWaterBrokeRefusesTheFutureAndReportsAFailure() async {
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(await coordinator.markWaterBroke(at: clock.now.addingTimeInterval(1)) == .invalid(.startInFuture))
        markerStore.failNextWrite = true
        #expect(await coordinator.markWaterBroke(at: at(10)) == .failed)
        #expect(coordinator.failure == .saveFailed)
        #expect(markerStore.stored.isEmpty)
    }

    @Test func updateMarkerAndDeleteMarker() async throws {
        let coordinator = makeCoordinator()
        await coordinator.load()
        await coordinator.markWaterBroke(at: at(600))
        let id = try #require(markerStore.stored.first?.id)
        #expect(await coordinator.updateMarker(id: id, at: at(300)) == .saved)
        #expect(markerStore.stored.first?.at == at(300))
        #expect(await coordinator.updateMarker(id: id, at: clock.now.addingTimeInterval(5)) == .invalid(.startInFuture))
        #expect(await coordinator.updateMarker(id: UUID(), at: at(10)) == .invalid(.notEditable))
        await coordinator.deleteMarker(id: id)
        #expect(markerStore.stored.isEmpty)
        #expect(coordinator.markers.isEmpty)
    }

    @Test func loadReadsTheMarkersAndDataDeletionForgetsThem() async {
        markerStore.seedForTest(LabourMarkerRecord(at: at(100)))
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(coordinator.markers.count == 1)
        await coordinator.resetAfterDataDeletion()
        #expect(coordinator.markers.isEmpty)
    }

    // MARK: - Alert notifications

    @Test func anEditThatCrossesAThresholdNotifiesOnce() async throws {
        // 13 contractions of 40 s: the average length is under 45 s, no alert.
        let records = seedRun(lasting: 40)
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(coordinator.stats(week: term).alert == .none)
        #expect(center.addCount == 0)

        // The newest, made longer: the average passes 45 s.
        let newest = try #require(records.last)
        #expect(await coordinator.update(id: newest.id, start: newest.startedAt, end: newest.startedAt.addingTimeInterval(115)) == .saved)
        #expect(coordinator.stats(week: term).alert == .fiveOneOne)
        #expect(center.addCount == 1)
        #expect(center.added.first?.content.body == "fiveOneOne")
    }

    @Test func anEditThatFallsBelowAThresholdNeverNotifies() async throws {
        let records = seedRun()
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(coordinator.stats(week: term).alert == .fiveOneOne)

        // The first contraction moved later: the run spans under an hour.
        let first = try #require(records.first)
        #expect(await coordinator.update(id: first.id, start: first.startedAt.addingTimeInterval(240), end: first.startedAt.addingTimeInterval(290)) == .saved)
        #expect(coordinator.stats(week: term).alert == .none)
        #expect(center.addCount == 0)
    }

    @Test func anAddThatCrossesAThresholdNotifies() async {
        // 12 contractions: the run spans 55 minutes.
        for index in 0..<12 { store.seed(done(120 + Double(11 - index) * 300)) }
        let coordinator = makeCoordinator()
        await coordinator.load()
        #expect(coordinator.stats(week: term).alert == .none)
        #expect(await coordinator.addMissed(start: at(120 + 11 * 300 + 300), duration: 60) == .saved)
        #expect(coordinator.stats(week: term).alert == .fiveOneOne)
        #expect(center.addCount == 1)
    }

    @Test func anEditThatLeavesTheAlertOnDoesNotNotifyAgain() async throws {
        let records = seedRun()
        let coordinator = makeCoordinator()
        await coordinator.load()
        let newest = try #require(records.last)
        #expect(await coordinator.update(id: newest.id, start: newest.startedAt, end: newest.startedAt.addingTimeInterval(70)) == .saved)
        #expect(center.addCount == 0, "the alert was already on: nothing newly crossed")
    }

    @Test func goingBelowAndBackAboveInTheSameRunDoesNotNotifyTwice() async throws {
        for index in 0..<12 { store.seed(done(120 + Double(11 - index) * 300)) }
        let coordinator = makeCoordinator()
        await coordinator.load()
        let extra = at(120 + 11 * 300 + 300)
        #expect(await coordinator.addMissed(start: extra, duration: 60) == .saved)
        #expect(center.addCount == 1)
        let added = try #require(coordinator.contractions.first)
        // Move it later (the alert goes off), then back (it comes on again): same run, no second notification.
        #expect(await coordinator.update(id: added.id, start: extra.addingTimeInterval(240), end: extra.addingTimeInterval(290)) == .saved)
        #expect(coordinator.stats(week: term).alert == .none)
        #expect(await coordinator.update(id: added.id, start: extra, end: extra.addingTimeInterval(60)) == .saved)
        #expect(coordinator.stats(week: term).alert == .fiveOneOne)
        #expect(center.addCount == 1)
    }
}

extension FakeLabourMarkerRepository {
    func seedForTest(_ record: LabourMarkerRecord) { try? save(record) }
}
