import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

/// 1.1 item 4 (spec §4.3, §4.6): memories, and the archive that saves the
/// memory and deletes the raw pregnancy rows in one transaction.
@MainActor
struct PregnancyMemoryStoreTests {
    let container: ModelContainer

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
    }

    private struct InjectedFailure: Error {}

    private var context: ModelContext { container.mainContext }

    private let inRange = AppointmentRecord(date: date("2026-08-10T09:00:00Z"), title: "Siêu âm", note: "Nghe tim")
    private let outOfRange = AppointmentRecord(date: date("2026-01-10T09:00:00Z"), title: "Khám tổng quát")
    private let pregnancyWeight = WeightRecord(day: date("2026-08-01T00:00:00Z"), kg: 55)
    private let earlierWeight = WeightRecord(day: date("2026-01-01T00:00:00Z"), kg: 50)
    private let log = CycleLogRecord(day: date("2026-08-02T00:00:00Z"), bbtCelsius: 36.6, note: "Bé đạp")

    private func content(_ branch: PregnancyEndBranch = .loss, end: String = "2026-09-01") -> PregnancyMemoryContent {
        PregnancyMemoryContent(
            branch: branch, start: date("2026-06-01T00:00:00Z"), end: date("\(end)T00:00:00Z"), furthestWeek: 13,
            appointments: [MemoryAppointment(date: inRange.date, title: inRange.title, note: inRange.note)]
        )
    }

    /// An earlier pregnancy's session (one kick) and contraction, then this pregnancy's
    /// session with two kicks, one contraction, two appointments, two weights, a day log and a period.
    private func seedRawRows() throws {
        let earlier = date("2025-03-01T20:00:00Z")
        let earlierSession = KickSession(startedAt: earlier)
        context.insert(earlierSession)
        let earlierKick = Kick(timestamp: earlier.addingTimeInterval(60))
        context.insert(earlierKick)
        earlierKick.session = earlierSession
        context.insert(Contraction(record: ContractionRecord(startedAt: earlier, endedAt: earlier.addingTimeInterval(50))))
        let start = date("2026-08-20T20:00:00Z")
        let session = KickSession(startedAt: start)
        context.insert(session)
        for offset in [60.0, 120.0] {
            let kick = Kick(timestamp: start.addingTimeInterval(offset))
            context.insert(kick)
            kick.session = session
        }
        context.insert(Contraction(record: ContractionRecord(startedAt: start, endedAt: start.addingTimeInterval(50))))
        context.insert(Appointment(record: inRange))
        context.insert(Appointment(record: outOfRange))
        context.insert(WeightEntry(record: pregnancyWeight))
        context.insert(WeightEntry(record: earlierWeight))
        context.insert(CycleLog(record: log))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: date("2026-05-01T00:00:00Z"))))
        try context.save()
    }

    private func counts() throws -> [String: Int] {
        [
            "KickSession": try context.fetchCount(FetchDescriptor<KickSession>()),
            "Kick": try context.fetchCount(FetchDescriptor<Kick>()),
            "Contraction": try context.fetchCount(FetchDescriptor<Contraction>()),
            "Appointment": try context.fetchCount(FetchDescriptor<Appointment>()),
            "WeightEntry": try context.fetchCount(FetchDescriptor<WeightEntry>()),
            "CycleLog": try context.fetchCount(FetchDescriptor<CycleLog>()),
            "PeriodEntry": try context.fetchCount(FetchDescriptor<PeriodEntry>()),
            "PregnancyMemory": try context.fetchCount(FetchDescriptor<PregnancyMemory>()),
        ]
    }

    private static let rangeStart = date("2026-05-01T00:00:00Z")

    /// What the app deletes for this pregnancy: its in-range rows only.
    private func thisPregnancyRows() throws -> PregnancyRawRowIDs {
        let start = Self.rangeStart
        return PregnancyRawRowIDs(
            sessions: Set(try context.fetch(FetchDescriptor<KickSession>()).filter { $0.startedAt >= start }.map(\.id)),
            contractions: Set(try context.fetch(FetchDescriptor<Contraction>()).filter { $0.startedAt >= start }.map(\.id)),
            appointments: [inRange.id],
            weights: [pregnancyWeight.id]
        )
    }

    private func archive(_ store: PregnancyMemoryStore, memory: PregnancyMemoryContent?) throws {
        try store.archive(memory: memory, title: "Bông", deleting: try thisPregnancyRows())
    }

    @Test func archiveDeletesOnlyTheGivenLabourMarkers() throws {
        let thisMarker = LabourMarkerRecord(at: date("2026-09-30T21:00:00Z"))
        let earlierMarker = LabourMarkerRecord(at: date("2025-07-01T21:00:00Z"))
        context.insert(LabourMarker(record: thisMarker))
        context.insert(LabourMarker(record: earlierMarker))
        try context.save()
        try PregnancyMemoryStore(context: context).archive(
            memory: content(), title: "", deleting: PregnancyRawRowIDs(labourMarkers: [thisMarker.id])
        )
        #expect(try context.fetch(FetchDescriptor<LabourMarker>()).map(\.id) == [earlierMarker.id])
    }

    @Test func archiveSavesMemoryAndDeletesRows() throws {
        try seedRawRows()
        let store = PregnancyMemoryStore(context: context)
        try archive(store, memory: content())
        // The earlier pregnancy's session, kick and contraction stay.
        #expect(try counts() == [
            "KickSession": 1, "Kick": 1, "Contraction": 1, "Appointment": 1, "WeightEntry": 1,
            "CycleLog": 1, "PeriodEntry": 1, "PregnancyMemory": 1,
        ])
        #expect(try context.fetch(FetchDescriptor<KickSession>()).map(\.startedAt) == [date("2025-03-01T20:00:00Z")])
        let saved = try #require(try store.all().first)
        #expect(saved.title == "Bông")
        #expect(saved.content == content())
        #expect(saved.branch == .loss)
        #expect(try context.fetch(FetchDescriptor<Appointment>()).map(\.id) == [outOfRange.id])
        #expect(try context.fetch(FetchDescriptor<WeightEntry>()).map(\.id) == [earlierWeight.id])
    }

    /// The safety proof (plan Review Focus 1): a save that fails deletes nothing
    /// and keeps no memory. The first case fails any save; the second fails
    /// only a save that carries deletions, so a split into "save the memory,
    /// then delete" cannot pass.
    @Test(arguments: [false, true])
    func archiveFailureDeletesNothing(onlyWhenDeleting: Bool) throws {
        try seedRawRows()
        let before = try counts()
        let store = PregnancyMemoryStore(context: context) { context in
            if !onlyWhenDeleting || !context.deletedModelsArray.isEmpty { throw InjectedFailure() }
            try context.save()
        }
        #expect(throws: InjectedFailure.self) {
            try archive(store, memory: content())
        }
        #expect(try counts() == before)
        #expect(try counts()["PregnancyMemory"] == 0)
        #expect(!context.hasChanges)
        // A later save does not bring back the abandoned archive.
        try context.save()
        #expect(try counts() == before)
    }

    @Test func pregnancyRowsReadsEveryRawRow() throws {
        try seedRawRows()
        let rows = try PregnancyMemoryStore(context: context).pregnancyRows()
        #expect(rows.sessions.map(\.state.kicks.count) == [1, 2])
        #expect(rows.contractions.count == 2)
        #expect(rows.appointments.map(\.id) == [outOfRange.id, inRange.id])
        #expect(rows.weights.map(\.id) == [earlierWeight.id, pregnancyWeight.id])
        #expect(rows.logs.map(\.id) == [log.id])
    }

    @Test func archiveWithoutMemoryOnlyDeletes() throws {
        try seedRawRows()
        let store = PregnancyMemoryStore(context: context)
        try archive(store, memory: nil)
        let after = try counts()
        #expect(after["PregnancyMemory"] == 0)
        #expect(after["KickSession"] == 1 && after["Kick"] == 1 && after["Contraction"] == 1)
        #expect(after["Appointment"] == 1 && after["WeightEntry"] == 1)
    }

    @Test func logsAreNeverDeleted() throws {
        try seedRawRows()
        try archive(PregnancyMemoryStore(context: context), memory: content())
        let logs = try CycleStore(context: context).logs()
        #expect(logs.map(\.id) == [log.id])
        #expect(logs.first?.note == "Bé đạp")
        #expect(logs.first?.bbtCelsius == 36.6)
        #expect(try CycleStore(context: context).periods().count == 1)
    }

    /// Review fix 2: only the given rows go; an empty set deletes nothing.
    @Test func archiveDeletesOnlyTheGivenRows() throws {
        try seedRawRows()
        try PregnancyMemoryStore(context: context).archive(memory: content(), title: "", deleting: PregnancyRawRowIDs())
        let after = try counts()
        #expect(after["KickSession"] == 2 && after["Kick"] == 3 && after["Contraction"] == 2)
        #expect(after["PregnancyMemory"] == 1)
    }

    @Test func allIsNewestFirst() throws {
        let store = PregnancyMemoryStore(context: context)
        try store.archive(memory: content(.birth, end: "2025-01-01"), title: "Older", deleting: PregnancyRawRowIDs())
        try store.archive(memory: content(.loss, end: "2026-09-01"), title: "Newer", deleting: PregnancyRawRowIDs())
        #expect(try store.all().map(\.title) == ["Newer", "Older"])
    }

    @Test func renameAndDelete() throws {
        let store = PregnancyMemoryStore(context: context)
        try store.archive(memory: content(), title: "", deleting: PregnancyRawRowIDs())
        let id = try #require(try store.all().first?.id)
        try store.rename(id: id, title: "  Bông  ")
        #expect(try store.all().first?.title == "Bông")
        try store.delete(id: id)
        #expect(try store.all().isEmpty)
        // Unknown ids are a no-op.
        try store.delete(id: UUID())
        try store.rename(id: UUID(), title: "x")
    }

    @Test func aFailedDeleteKeepsTheMemory() throws {
        let store = PregnancyMemoryStore(context: context)
        try store.archive(memory: content(), title: "Bông", deleting: PregnancyRawRowIDs())
        let id = try #require(try store.all().first?.id)
        let failing = PregnancyMemoryStore(context: context) { _ in throw InjectedFailure() }
        #expect(throws: InjectedFailure.self) { try failing.delete(id: id) }
        #expect(try store.all().map(\.id) == [id])
    }

    @Test func deleteAllRemovesMemories() throws {
        try PregnancyMemoryStore(context: context).archive(
            memory: content(), title: "", deleting: PregnancyRawRowIDs()
        )
        try DataReset.deleteAll(in: container)
        #expect(try PregnancyMemoryStore(context: context).all().isEmpty)
    }
}
