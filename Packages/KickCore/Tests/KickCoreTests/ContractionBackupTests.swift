import Foundation
import Testing
@testable import KickCore

/// Phase 20 spec §3.1: the backup gains an optional `contractions` array, still version 1.
struct ContractionBackupTests {
    private let done = ContractionRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000061")!,
        startedAt: date("2026-10-08T21:00:00Z"),
        endedAt: date("2026-10-08T21:00:55.5Z")
    )
    private let open = ContractionRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000062")!,
        startedAt: date("2026-10-08T21:05:00Z")
    )

    private func document(_ records: [ContractionRecord]) -> BackupDocument {
        var document = BackupCodecTests.sampleDocument()
        document.contractions = records.map(ContractionDTO.init)
        return document
    }

    @Test func contractionsRoundTrip() throws {
        let original = document([done, open])
        let decoded = try BackupCodec.decode(BackupCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.version == 1)
        #expect(decoded.records.contractions == [done, open])
    }

    @Test func anOlderFileWithoutContractionsLoadsAsEmpty() throws {
        let data = try BackupCodec.encode(BackupCodecTests.sampleDocument())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["contractions"] == nil, "an empty list is not written, so the file stays as before")
        #expect(try BackupCodec.decode(data).contractions.isEmpty)
    }

    @Test func aRunningContractionIsWrittenWithoutAnEnd() throws {
        let data = try BackupCodec.encode(document([open]))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try #require(object["contractions"] as? [[String: Any]])
        #expect(rows.first?["endedAt"] == nil)
        #expect(rows.first?["startedAt"] as? String == "2026-10-08T21:05:00.000Z")
    }

    @Test func recordsCarryTheContractions() {
        var records = BackupCodecTests.sampleDocument().records
        records.contractions = [done]
        let document = BackupDocument(createdAt: BackupCodecTests.created, appVersion: "1.0", records: records, settings: [:])
        #expect(document.contractions == [ContractionDTO(done)])
        #expect(document.records.contractions == [done])
    }

    @Test func summaryCountsTheContractions() {
        let empty = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.0",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [], settings: [:]
        )
        var withOne = empty
        withOne.contractions = [ContractionDTO(done)]
        #expect(withOne.summary.contractions == 1)
        #expect(!withOne.summary.isEmpty)
        #expect(withOne.summary.dateRange == done.startedAt...done.startedAt)
    }

    @Test func validationSkipsInvalidContractions() {
        let now = date("2026-10-09T12:00:00Z")
        let future = ContractionRecord(startedAt: now.addingTimeInterval(60))
        let backwards = ContractionRecord(startedAt: date("2026-10-08T22:00:00Z"), endedAt: date("2026-10-08T21:59:00Z"))
        let misTap = ContractionRecord(startedAt: date("2026-10-08T23:00:00Z"), endedAt: date("2026-10-08T23:00:02Z"))
        var file = document([done, future, backwards, misTap])
        file.contractions.append(ContractionDTO(done))
        let (cleaned, skipped) = BackupValidation.clean(file, now: now, calendar: utcCalendar)
        #expect(cleaned.contractions == [ContractionDTO(done)])
        #expect(skipped == 4)
    }

    @Test func validationKeepsOnlyTheNewestRunning() {
        let now = date("2026-10-08T21:06:00Z")
        let stray = ContractionRecord(startedAt: date("2026-10-08T20:00:00Z"))
        let (cleaned, skipped) = BackupValidation.clean(document([stray, done, open]), now: now, calendar: utcCalendar)
        #expect(skipped == 0)
        let records = cleaned.records.contractions
        #expect(records.filter(\.isRunning).map(\.id) == [open.id])
        #expect(records.first { $0.id == stray.id }?.endedAt == stray.startedAt.addingTimeInterval(ContractionRules.maxDuration))
    }
}
