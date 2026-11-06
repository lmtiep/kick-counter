import Foundation
import Testing
@testable import KickCore

/// 1.1 item 4 (spec §4.3): the backup gains an optional `pregnancyMemories`
/// array, still version 1, following `pillDoses` / `contractions`.
struct PregnancyMemoryBackupTests {
    private let record = PregnancyMemoryRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
        createdAt: date("2026-11-01T10:00:00Z"),
        title: "Bông",
        content: PregnancyMemoryContent(
            branch: .loss,
            start: date("2026-07-01T00:00:00Z"),
            end: date("2026-10-01T00:00:00Z"),
            furthestWeek: 13,
            kickDays: [KickDay(day: date("2026-09-20T00:00:00Z"), sessionCount: 1, totalKicks: 10, bestDuration: 1200)],
            appointments: [MemoryAppointment(date: date("2026-08-10T09:00:00Z"), title: "Siêu âm", note: "Nghe tim")],
            notes: [MemoryNote(day: date("2026-08-01T00:00:00Z"), text: "Lần đầu", moods: ["happy"], pregnancySymptoms: [])]
        )
    )

    private var memory: StoredPregnancyMemory { try! StoredPregnancyMemory(record) }

    private func document(_ records: [StoredPregnancyMemory]) -> BackupDocument {
        var document = BackupCodecTests.sampleDocument()
        document.pregnancyMemories = records.map(PregnancyMemoryDTO.init)
        return document
    }

    @Test func backupRoundTripWithMemories() throws {
        let original = document([memory])
        let decoded = try BackupCodec.decode(BackupCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.version == 1)
        #expect(decoded.records.pregnancyMemories == [memory])
    }

    @Test func backupWithoutKeyDecodesEmpty() throws {
        let data = try BackupCodec.encode(BackupCodecTests.sampleDocument())
        #expect(try BackupCodec.decode(data).pregnancyMemories.isEmpty)
    }

    @Test func emptyMemoriesNotWritten() throws {
        let data = try BackupCodec.encode(BackupCodecTests.sampleDocument())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["pregnancyMemories"] == nil, "an empty list is not written, so the file stays as before")
        let withOne = try #require(try JSONSerialization.jsonObject(with: BackupCodec.encode(document([memory]))) as? [String: Any])
        #expect((withOne["pregnancyMemories"] as? [Any])?.count == 1)
    }

    @Test func recordsCarryTheMemories() {
        var records = BackupCodecTests.sampleDocument().records
        records.pregnancyMemories = [memory]
        let document = BackupDocument(createdAt: BackupCodecTests.created, appVersion: "1.1", records: records, settings: [:])
        #expect(document.pregnancyMemories == [PregnancyMemoryDTO(memory)])
        #expect(document.records.pregnancyMemories == [memory])
    }

    @Test func summaryCountsTheMemories() {
        var file = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.1",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [], settings: [:]
        )
        #expect(file.summary.isEmpty)
        file.pregnancyMemories = [PregnancyMemoryDTO(memory)]
        #expect(file.summary.pregnancyMemories == 1)
        #expect(!file.summary.isEmpty)
    }

    @Test func validationDropsDuplicateMemories() {
        var file = document([memory])
        file.pregnancyMemories.append(PregnancyMemoryDTO(memory))
        let (cleaned, skipped) = BackupValidation.clean(file, now: date("2026-11-05T00:00:00Z"), calendar: utcCalendar)
        #expect(cleaned.pregnancyMemories == [PregnancyMemoryDTO(memory)])
        #expect(skipped == 1)
    }

    @Test func storedMemoryDecodesBackToTheRecord() {
        #expect(memory.record == record)
        #expect(memory.branchRaw == "loss")
    }

    /// Review fix 6: a payload this build cannot read still survives export and restore, byte for byte.
    @Test func anUnreadablePayloadRoundTripsLosslessly() throws {
        let unreadable = StoredPregnancyMemory(
            id: UUID(), createdAt: date("2026-11-01T10:00:00Z"), title: "Future", branchRaw: "birth",
            payload: Data(#"{"version":9,"somethingNew":[1,2,3]}"#.utf8)
        )
        #expect(unreadable.record == nil)
        let decoded = try BackupCodec.decode(BackupCodec.encode(document([unreadable, memory])))
        #expect(decoded.records.pregnancyMemories == [unreadable, memory])
    }
}
