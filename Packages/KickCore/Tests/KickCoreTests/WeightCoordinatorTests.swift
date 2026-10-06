import Foundation
import Testing
@testable import KickCore

@MainActor
struct WeightCoordinatorTests {
    let repository = FakeWeightRepository()
    let clock = TestClock(date("2026-10-02T12:00:00Z"))
    let defaults = makeTestDefaults()
    let coordinator: WeightCoordinator

    init() {
        let clock = clock
        coordinator = WeightCoordinator(store: repository, defaults: defaults, calendar: utcCalendar, now: { clock.now })
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func loadReadsTheEntriesAndTheProfile() async throws {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6), WeightRecord(day: day("2026-09-01"), kg: 56.0))
        try MaternalProfile(preWeightKg: 52, heightCm: 160).save(to: defaults)
        await coordinator.load()
        #expect(coordinator.entries.map(\.kg) == [56.0, 57.6])
        #expect(coordinator.latest?.kg == 57.6)
        #expect(coordinator.profile.category == .normal)
        #expect(coordinator.failure == nil)
    }

    @Test func savingTheSameDayTwiceKeepsOneEntryAndItsID() async {
        await coordinator.load()
        #expect(coordinator.save(kg: 57.95, on: date("2026-10-02T08:00:00Z")) == nil)
        let first = coordinator.entries.first?.id
        #expect(coordinator.save(kg: 58.2, on: day("2026-10-02")) == nil)
        #expect(coordinator.entries.count == 1)
        #expect(coordinator.entries.first?.id == first)
        #expect(coordinator.entry(on: date("2026-10-02T20:00:00Z"))?.kg == 58.2)
    }

    @Test func validationErrorsAreReturnedNotShown() async {
        await coordinator.load()
        #expect(coordinator.save(kg: 25, on: day("2026-10-02")) == .outOfRange)
        #expect(coordinator.save(kg: 58, on: day("2026-10-03")) == .futureDate)
        #expect(coordinator.failure == nil)
        #expect(coordinator.entries.isEmpty)
    }

    @Test func storeErrorsAreShownAndKeepTheEntries() async {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6))
        await coordinator.load()
        repository.failNextWrite = true
        #expect(coordinator.save(kg: 58, on: day("2026-10-02")) == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.entries.map(\.kg) == [57.6])
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func failedLoadKeepsWhatWasLoaded() async {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6))
        await coordinator.load()
        repository.failNextRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
        #expect(coordinator.entries.count == 1)
    }

    @Test func deleteRemovesTheEntry() async throws {
        repository.seed(WeightRecord(day: day("2026-09-29"), kg: 57.6))
        await coordinator.load()
        let id = try #require(coordinator.entries.first?.id)
        #expect(coordinator.delete(id: id) == nil)
        #expect(coordinator.entries.isEmpty)
        repository.failNextWrite = true
        #expect(coordinator.delete(id: UUID()) == .saveFailed)
    }

    @Test func profileUpdatesAreValidated() {
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 52, heightCm: 160)) == nil)
        #expect(coordinator.profile.bmi == 20.3)
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 52, heightCm: 99)) == .invalidHeight)
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 12, heightCm: 160)) == .outOfRange)
        #expect(coordinator.profile == MaternalProfile(preWeightKg: 52, heightCm: 160))
        #expect(coordinator.updateProfile(MaternalProfile(preWeightKg: 52)) == nil)
        #expect(coordinator.profile.category == nil)
        #expect(coordinator.failure == nil)
    }

    @Test func profileChangedElsewhereIsPickedUpOnLoad() async throws {
        try MaternalProfile(preWeightKg: 60).save(to: defaults)
        await coordinator.load()
        #expect(coordinator.profile.preWeightKg == 60)
    }
}
