import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// Edit spec 2026-11-06: the labour marker store, delete-all, and a store from
/// before the model existed.
@MainActor
struct LabourMarkerStoreTests {
    let container: ModelContainer
    let store: LabourMarkerStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = LabourMarkerStore(context: container.mainContext)
    }

    private struct InjectedFailure: Error {}

    @Test func savesAndReadsOldestFirst() throws {
        let later = LabourMarkerRecord(at: date("2026-11-06T10:10:00Z"))
        let earlier = LabourMarkerRecord(at: date("2026-11-06T10:00:00Z"))
        try store.save(later)
        try store.save(earlier)
        #expect(try store.markers() == [earlier, later])
    }

    @Test func savingTheSameIdReplaces() throws {
        var record = LabourMarkerRecord(at: date("2026-11-06T10:00:00Z"))
        try store.save(record)
        record.at = date("2026-11-06T10:30:00Z")
        try store.save(record)
        #expect(try store.markers() == [record])
        #expect(try container.mainContext.fetchCount(FetchDescriptor<LabourMarker>()) == 1)
    }

    @Test func aKindThisBuildDoesNotKnowIsKept() throws {
        let odd = LabourMarkerRecord(kind: "somethingNew", at: date("2026-11-06T10:00:00Z"))
        try store.save(odd)
        #expect(try store.markers() == [odd])
    }

    @Test func deleteIgnoresUnknownIds() throws {
        let a = LabourMarkerRecord(at: date("2026-11-06T10:00:00Z"))
        let b = LabourMarkerRecord(at: date("2026-11-06T11:00:00Z"))
        try store.save(a)
        try store.save(b)
        try store.delete(ids: [a.id, UUID()])
        #expect(try store.markers() == [b])
        try store.delete(ids: [])
        #expect(try store.markers() == [b])
    }

    @Test func aFailedSaveRollsBack() throws {
        let failing = LabourMarkerStore(context: container.mainContext) { _ in throw InjectedFailure() }
        #expect(throws: InjectedFailure.self) {
            try failing.save(LabourMarkerRecord(at: date("2026-11-06T10:00:00Z")))
        }
        #expect(try store.markers().isEmpty)
        #expect(!container.mainContext.hasChanges)
    }

    @Test func aFailedDeleteRollsBack() throws {
        let record = LabourMarkerRecord(at: date("2026-11-06T10:00:00Z"))
        try store.save(record)
        let failing = LabourMarkerStore(context: container.mainContext) { _ in throw InjectedFailure() }
        #expect(throws: InjectedFailure.self) { try failing.delete(ids: [record.id]) }
        #expect(try store.markers() == [record])
    }

    /// A store written by the build before this model existed (its schema without `LabourMarker`)
    /// opens with the new schema, keeps every row and starts with no markers.
    @Test func aStoreCreatedWithoutLabourMarkersOpensAndKeepsItsRows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("before-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        let day = date("2026-11-01T00:00:00Z")
        do {
            let oldSchema = Schema([
                KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self,
                WeightEntry.self, PillDose.self, Contraction.self,
            ])
            let old = try ModelContainer(
                for: oldSchema, configurations: ModelConfiguration(schema: oldSchema, url: url, cloudKitDatabase: .none)
            )
            let context = old.mainContext
            context.insert(Contraction(record: ContractionRecord(startedAt: day, endedAt: day.addingTimeInterval(60))))
            context.insert(WeightEntry(record: WeightRecord(day: day, kg: 55)))
            try context.save()
        }

        let reopened = try KickPersistence.makeContainer(url: url)
        let context = reopened.mainContext
        #expect(try context.fetchCount(FetchDescriptor<Contraction>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WeightEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<LabourMarker>()) == 0)

        let markers = LabourMarkerStore(context: context)
        try markers.save(LabourMarkerRecord(at: day))
        #expect(try markers.markers().count == 1)
    }
}
