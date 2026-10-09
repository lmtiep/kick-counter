import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// Phase 15 spec §4.2: the store half of a restore is all or nothing.
@MainActor
struct BackupStoreTests {
    let container: ModelContainer

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
    }

    private struct InjectedFailure: Error {}

    private func seedOldData() throws {
        let context = container.mainContext
        let day = date("2026-09-01T00:00:00Z")
        let session = KickSession(startedAt: day)
        context.insert(session)
        let kick = Kick(timestamp: day)
        context.insert(kick)
        kick.session = session
        context.insert(Appointment(record: AppointmentRecord(date: day, title: "Cũ")))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: day)))
        context.insert(CycleLog(record: CycleLogRecord(day: day, note: "cũ")))
        context.insert(WeightEntry(record: WeightRecord(day: day, kg: 50)))
        context.insert(PillDose(record: PillDoseRecord(day: CalendarDay(year: 2026, month: 9, day: 1), takenAt: day.addingTimeInterval(75_600))))
        try context.save()
    }

    private func newRecords() -> BackupRecords {
        let start = date("2026-10-08T20:00:00Z")
        return BackupRecords(
            sessions: [
                SessionRecord(id: UUID(), state: SessionState(
                    startedAt: start,
                    kicks: [start.addingTimeInterval(60), start.addingTimeInterval(120)],
                    status: .cancelled,
                    endedAt: start.addingTimeInterval(600)
                )),
                SessionRecord(id: UUID(), state: SessionState(startedAt: start.addingTimeInterval(3600))),
            ],
            appointments: [AppointmentRecord(date: date("2026-10-20T08:00:00Z"), title: "Mới", milestoneID: "nt")],
            periods: [
                PeriodRecord(startDate: date("2026-09-10T00:00:00Z"), endDate: date("2026-09-14T00:00:00Z")),
                PeriodRecord(startDate: date("2026-10-07T00:00:00Z")),
            ],
            logs: [CycleLogDTO(CycleLogRecord(
                day: date("2026-10-02T00:00:00Z"), lh: .positive, note: "mới", moods: [.happy],
                unknownMoodsRaw: ["dreamy"], unknownSymptomsRaw: ["futureSymptom"]
            ))],
            weights: [WeightRecord(day: date("2026-10-03T00:00:00Z"), kg: 56.2)],
            pillDoses: [
                PillDoseRecord(day: CalendarDay(year: 2026, month: 10, day: 7), takenAt: date("2026-10-07T21:04:00Z")),
                PillDoseRecord(day: CalendarDay(year: 2026, month: 10, day: 8), takenAt: date("2026-10-08T21:10:00Z")),
            ]
        )
    }

    private func sorted(_ records: BackupRecords) -> BackupRecords {
        BackupRecords(
            sessions: records.sessions.sorted { $0.state.startedAt < $1.state.startedAt },
            appointments: records.appointments.sorted { $0.date < $1.date },
            periods: records.periods.sorted { $0.startDate < $1.startDate },
            logs: records.logs.sorted { $0.day < $1.day },
            weights: records.weights.sorted { $0.day < $1.day },
            pillDoses: records.pillDoses.sorted { $0.day < $1.day }
        )
    }

    @Test func exportReadsEveryRecord() throws {
        try seedOldData()
        let exported = try BackupStore.export(from: container)
        #expect(exported.sessions.count == 1)
        #expect(exported.sessions.first?.state.kicks.count == 1)
        #expect(exported.appointments.map(\.title) == ["Cũ"])
        #expect(exported.periods.count == 1)
        #expect(exported.logs.map(\.note) == ["cũ"])
        #expect(exported.weights.map(\.kg) == [50])
        #expect(exported.pillDoses.map(\.day) == [CalendarDay(year: 2026, month: 9, day: 1)])
    }

    @Test func replaceAllSwapsEverythingForTheFileRecords() throws {
        try seedOldData()
        let records = newRecords()

        try BackupStore.replaceAll(in: container, with: records)

        #expect(sorted(try BackupStore.export(from: container)) == sorted(records))
        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<Kick>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<KickSession>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<PillDose>()) == 2)
    }

    @Test func replaceAllThenExportRoundTripsThroughTheCodec() throws {
        let records = newRecords()
        try BackupStore.replaceAll(in: container, with: records)
        let exported = try BackupStore.export(from: container)
        let document = BackupDocument(
            createdAt: date("2026-10-09T09:00:00Z"), appVersion: "test", records: exported, settings: [:]
        )
        let decoded = try BackupCodec.decode(BackupCodec.encode(document))
        #expect(decoded == document)
        #expect(decoded.cycleLogs.first?.record.unknownMoodsRaw == ["dreamy"])
        #expect(decoded.records.pillDoses.count == 2)
    }

    /// The safety proof: a save that fails leaves every old record in place and
    /// none of the new ones.
    @Test func aFailedSaveLeavesTheOldDataUntouched() throws {
        try seedOldData()
        let before = sorted(try BackupStore.export(from: container))

        #expect(throws: InjectedFailure.self) {
            try BackupStore.replaceAll(in: container, with: newRecords()) { _ in throw InjectedFailure() }
        }

        #expect(sorted(try BackupStore.export(from: container)) == before)
        let context = container.mainContext
        #expect(try context.fetchCount(FetchDescriptor<Kick>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<KickSession>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PillDose>()) == 1)
        #expect(!context.hasChanges)
        // A later save does not resurrect the abandoned replace.
        try context.save()
        #expect(sorted(try BackupStore.export(from: container)) == before)
    }

    @Test func replaceAllWithNothingEmptiesTheStore() throws {
        try seedOldData()
        try BackupStore.replaceAll(in: container, with: BackupRecords(sessions: [], appointments: [], periods: [], logs: [], weights: []))
        let exported = try BackupStore.export(from: container)
        #expect(exported.sessions.isEmpty && exported.appointments.isEmpty && exported.periods.isEmpty)
        #expect(exported.logs.isEmpty && exported.weights.isEmpty && exported.pillDoses.isEmpty)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Kick>()) == 0)
    }

    @Test func restoredRecordsWorkWithTheStores() throws {
        try BackupStore.replaceAll(in: container, with: newRecords())
        let kickStore = KickStore(context: container.mainContext)
        #expect(try kickStore.activeSession()?.state.startedAt == date("2026-10-08T21:00:00Z"))
        let cycleStore = CycleStore(context: container.mainContext)
        #expect(try cycleStore.periods().count == 2)
        #expect(try cycleStore.logs().first?.unknownSymptomsRaw == ["futureSymptom"])
    }

    /// LH, mucus and flow values this build cannot read survive export and restore.
    @Test func unknownRawLogValuesSurviveExportAndRestore() throws {
        let context = container.mainContext
        let log = CycleLog(record: CycleLogRecord(day: date("2026-10-02T00:00:00Z")))
        log.lhRaw = "faint"
        log.mucusRaw = "watery"
        log.flowRaw = "spotting"
        context.insert(log)
        try context.save()

        let exported = try BackupStore.export(from: container)
        let dto = try #require(exported.logs.first)
        #expect(dto.lh == "faint" && dto.mucus == "watery" && dto.flow == "spotting")

        try BackupStore.replaceAll(in: container, with: exported)
        let stored = try #require(try context.fetch(FetchDescriptor<CycleLog>()).first)
        #expect(stored.lhRaw == "faint" && stored.mucusRaw == "watery" && stored.flowRaw == "spotting")
    }
}
