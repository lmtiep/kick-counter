import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// 1.1 item 4: the store written by 1.0 (every model except `PregnancyMemory`)
/// opens with the new schema through lightweight migration, keeping its rows.
@MainActor
struct MigrationTests {
    /// The 1.0 schema: everything before `PregnancyMemory`.
    static let schema1_0 = Schema([
        KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self, WeightEntry.self, PillDose.self, Contraction.self,
    ])

    @Test func migrationFrom1_0Store() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MigrationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("Kick.store")
        let day = date("2026-09-01T00:00:00Z")

        // 1. A 1.0 store on disk, with data, and without the new entity.
        do {
            #expect(!Self.schema1_0.entities.map(\.name).contains("PregnancyMemory"))
            let old = try ModelContainer(
                for: Self.schema1_0,
                configurations: ModelConfiguration(schema: Self.schema1_0, url: url, cloudKitDatabase: .none)
            )
            let context = old.mainContext
            let session = KickSession(startedAt: day)
            context.insert(session)
            let kick = Kick(timestamp: day.addingTimeInterval(60))
            context.insert(kick)
            kick.session = session
            context.insert(Appointment(record: AppointmentRecord(date: day, title: "Khám thai")))
            context.insert(PeriodEntry(record: PeriodRecord(startDate: day)))
            context.insert(CycleLog(record: CycleLogRecord(day: day, note: "ghi chú")))
            context.insert(WeightEntry(record: WeightRecord(day: day, kg: 55)))
            context.insert(Contraction(record: ContractionRecord(startedAt: day, endedAt: day.addingTimeInterval(60))))
            try context.save()
        }
        #expect(FileManager.default.fileExists(atPath: url.path))

        // 2. Reopened with the app's configuration and the new schema.
        let container = try KickPersistence.makeContainer(url: url)
        #expect(container.schema.entities.map(\.name).contains("PregnancyMemory"))
        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<KickSession>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Kick>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Appointment>()).map(\.title) == ["Khám thai"])
        #expect(try context.fetchCount(FetchDescriptor<PeriodEntry>()) == 1)
        #expect(try context.fetch(FetchDescriptor<CycleLog>()).map(\.note) == ["ghi chú"])
        #expect(try context.fetch(FetchDescriptor<WeightEntry>()).map(\.kg) == [55])
        #expect(try context.fetchCount(FetchDescriptor<Contraction>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PregnancyMemory>()) == 0)

        // 3. A memory can be archived into the migrated store, and survives a reopen.
        let store = PregnancyMemoryStore(context: context)
        try store.archive(
            memory: PregnancyMemoryContent(branch: .birth, start: nil, end: day, furthestWeek: nil),
            title: "Bé Na", deleteAllSessions: true, deleteAllContractions: true, appointmentIDs: [], weightIDs: []
        )
        let reopened = try KickPersistence.makeContainer(url: url)
        #expect(try PregnancyMemoryStore(context: reopened.mainContext).all().map(\.title) == ["Bé Na"])
        #expect(try reopened.mainContext.fetchCount(FetchDescriptor<KickSession>()) == 0)
        #expect(try reopened.mainContext.fetchCount(FetchDescriptor<CycleLog>()) == 1)
    }
}
