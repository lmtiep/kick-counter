import Foundation
import Testing
@testable import KickCore

/// Phase 17 spec §3.2: the backup gains an optional `pillDoses` array, still version 1.
struct PillBackupTests {
    private let dose = PillDoseRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000051")!,
        day: date("2026-10-08T00:00:00Z"),
        takenAt: date("2026-10-08T21:04:00Z")
    )

    private func document(doses: [PillDoseRecord]) -> BackupDocument {
        var document = BackupCodecTests.sampleDocument()
        document.pillDoses = doses.map(PillDoseDTO.init)
        return document
    }

    @Test func pillDosesRoundTrip() throws {
        let original = document(doses: [dose])
        let decoded = try BackupCodec.decode(BackupCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.version == 1)
        #expect(decoded.records.pillDoses == [dose])
    }

    @Test func anOlderFileWithoutPillDosesLoadsAsEmpty() throws {
        let data = try BackupCodec.encode(BackupCodecTests.sampleDocument())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["pillDoses"] == nil, "an empty list is not written, so the file stays as before")
        let decoded = try BackupCodec.decode(data)
        #expect(decoded.pillDoses.isEmpty)
    }

    @Test func recordsCarryThePillDoses() {
        var records = BackupCodecTests.sampleDocument().records
        records.pillDoses = [dose]
        let document = BackupDocument(createdAt: BackupCodecTests.created, appVersion: "1.0", records: records, settings: [:])
        #expect(document.pillDoses == [PillDoseDTO(dose)])
        #expect(document.records.pillDoses == [dose])
    }

    @Test func summaryCountsThePillDoses() {
        let empty = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.0",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [], settings: [:]
        )
        #expect(empty.summary.isEmpty)
        var withDose = empty
        withDose.pillDoses = [PillDoseDTO(dose)]
        #expect(withDose.summary.pillDoses == 1)
        #expect(!withDose.summary.isEmpty)
        #expect(withDose.summary.dateRange == dose.day...dose.day)
    }

    @Test func validationSkipsFutureAndDuplicateDays() {
        var document = document(doses: [
            dose,
            PillDoseRecord(day: date("2026-10-08T00:00:00Z"), takenAt: date("2026-10-08T22:00:00Z")),
            PillDoseRecord(day: date("2026-10-20T00:00:00Z"), takenAt: date("2026-10-20T21:00:00Z")),
        ])
        document.pillDoses.append(PillDoseDTO(dose))
        let (cleaned, skipped) = BackupValidation.clean(document, now: date("2026-10-09T12:00:00Z"), calendar: utcCalendar)
        #expect(cleaned.pillDoses.count == 1)
        #expect(cleaned.pillDoses.first?.day == date("2026-10-08T00:00:00Z"))
        #expect(skipped == 3)
    }
}
