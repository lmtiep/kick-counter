import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// Adding `ChecklistItem` (1.1) is a lightweight migration: a store made before it opens
/// with its rows intact and the new table empty.
@MainActor
struct SchemaUpgradeTests {
    /// The schema list as it was before `ChecklistItem`.
    private static let schemaWithoutChecklist = Schema([
        KickSession.self, Kick.self, Appointment.self, PeriodEntry.self, CycleLog.self, WeightEntry.self, PillDose.self, Contraction.self,
    ])

    @Test func aStoreCreatedWithoutChecklistItemOpensWithItsRows() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("luna-schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")
        let appointmentID = UUID()
        let day = date("2026-10-01T09:00:00Z")

        do {
            let old = ModelConfiguration(schema: Self.schemaWithoutChecklist, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: Self.schemaWithoutChecklist, configurations: old)
            let context = container.mainContext
            context.insert(Appointment(record: AppointmentRecord(id: appointmentID, date: day, title: "Khám thai")))
            context.insert(WeightEntry(record: WeightRecord(day: day, kg: 55)))
            context.insert(Contraction(record: ContractionRecord(startedAt: day, endedAt: day.addingTimeInterval(60))))
            let session = KickSession(startedAt: day)
            context.insert(session)
            try context.save()
        }

        let container = try KickPersistence.makeContainer(url: url)
        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 1)
        #expect(try context.fetch(FetchDescriptor<Appointment>()).first?.id == appointmentID)
        #expect(try context.fetchCount(FetchDescriptor<WeightEntry>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Contraction>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<KickSession>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ChecklistItem>()) == 0)

        let store = ChecklistStore(context: context)
        _ = try store.addQuestion("Câu hỏi đầu tiên", appointmentID: appointmentID, now: day)
        #expect(try store.items().count == 1)
    }

    /// 1.2 adds spotting, sex, sex drive and pregnancy test to `CycleLog`: a store made by
    /// the 1.1 model (the fixture) opens with its logs intact and the new fields empty.
    @Test func aStoreFrom11OpensWithItsCycleLogsIntact() throws {
        let fixture = try #require(Bundle.module.url(forResource: "store-1.1", withExtension: "sqlite", subdirectory: "Fixtures"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("luna-schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")
        try FileManager.default.copyItem(at: fixture, to: url)

        let container = try KickPersistence.makeContainer(url: url)
        let store = CycleStore(context: container.mainContext, calendar: utcCalendar)
        let log = try #require(try store.logs().first)
        #expect(log.id == UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(log.day == date("2026-10-05T00:00:00Z"))
        #expect(log.flow == .light && log.moods == [.tired] && log.symptoms == [.cramps] && log.note == "x")
        #expect(!log.spotting && log.sex == nil && log.sexDrive == nil && log.pregnancyTest == nil)
        #expect(try store.periods().count == 1)

        var edited = log
        edited.spotting = true
        edited.sex = .protected
        try store.saveLog(edited, today: date("2026-11-09T12:00:00Z"))
        #expect(try store.logs().first?.sex == .protected)
    }
}
