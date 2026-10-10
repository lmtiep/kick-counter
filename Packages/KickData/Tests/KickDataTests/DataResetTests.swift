import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct DataResetTests {
    let container: ModelContainer

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
    }

    private func counts() throws -> [String: Int] {
        let context = container.mainContext
        return [
            "KickSession": try context.fetchCount(FetchDescriptor<KickSession>()),
            "Kick": try context.fetchCount(FetchDescriptor<Kick>()),
            "Appointment": try context.fetchCount(FetchDescriptor<Appointment>()),
            "PeriodEntry": try context.fetchCount(FetchDescriptor<PeriodEntry>()),
            "CycleLog": try context.fetchCount(FetchDescriptor<CycleLog>()),
            "WeightEntry": try context.fetchCount(FetchDescriptor<WeightEntry>()),
            "PillDose": try context.fetchCount(FetchDescriptor<PillDose>()),
            "Contraction": try context.fetchCount(FetchDescriptor<Contraction>()),
        ]
    }

    @Test func deleteAllEmptiesEveryModel() throws {
        let context = container.mainContext
        let day = date("2026-10-01T00:00:00Z")
        let session = KickSession(startedAt: day)
        context.insert(session)
        let kick = Kick(timestamp: day)
        context.insert(kick)
        kick.session = session
        context.insert(Appointment(record: AppointmentRecord(date: day, title: "Khám thai")))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day)))
        context.insert(CycleLog(record: CycleLogRecord(day: day, note: "ghi chú")))
        context.insert(WeightEntry(record: WeightRecord(day: day, kg: 55)))
        context.insert(PillDose(record: PillDoseRecord(day: CalendarDay(year: 2026, month: 10, day: 1), takenAt: day.addingTimeInterval(75_600))))
        context.insert(Contraction(record: ContractionRecord(startedAt: day, endedAt: day.addingTimeInterval(60))))
        try context.save()
        #expect(try counts().values.allSatisfy { $0 == 1 })

        try DataReset.deleteAll(in: container)

        let after = try counts()
        #expect(after.values.allSatisfy { $0 == 0 }, "\(after)")
    }

    @Test func deleteAllCoversEverySchemaEntity() {
        #expect(Set(KickPersistence.schema.entities.map(\.name)) == [
            "KickSession", "Kick", "Appointment", "PeriodEntry", "CycleLog", "WeightEntry", "PillDose", "Contraction",
        ])
    }

    @Test func deleteAllOnAnEmptyStoreSucceeds() throws {
        try DataReset.deleteAll(in: container)
        #expect(try counts().values.allSatisfy { $0 == 0 })
    }
}
