import Foundation
import Testing
@testable import KickCore

/// Edit spec 2026-11-06: the backup gains an optional `labourMarkers` array,
/// still version 1 (the `contractions` precedent).
struct LabourMarkerBackupTests {
    private let water = LabourMarkerRecord(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!, at: date("2026-10-08T21:30:00Z")
    )

    private func document(_ records: [LabourMarkerRecord]) -> BackupDocument {
        var document = BackupCodecTests.sampleDocument()
        document.labourMarkers = records.map(LabourMarkerDTO.init)
        return document
    }

    @Test func roundTripKeepsMarkers() throws {
        let original = document([water])
        let decoded = try BackupCodec.decode(BackupCodec.encode(original))
        #expect(decoded == original)
        #expect(decoded.version == 1)
        #expect(decoded.records.labourMarkers == [water])
    }

    @Test func aFileWithoutMarkersDecodesAsEmpty() throws {
        let data = try BackupCodec.encode(BackupCodecTests.sampleDocument())
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["labourMarkers"] == nil, "an empty list is not written, so the file stays as before")
        #expect(try BackupCodec.decode(data).labourMarkers.isEmpty)
    }

    @Test func aKindThisBuildDoesNotKnowTravelsUnchanged() throws {
        let odd = LabourMarkerRecord(kind: "somethingNew", at: date("2026-10-08T21:40:00Z"))
        let decoded = try BackupCodec.decode(BackupCodec.encode(document([odd])))
        #expect(decoded.records.labourMarkers == [odd])
    }

    @Test func recordsCarryTheMarkers() {
        var records = BackupCodecTests.sampleDocument().records
        records.labourMarkers = [water]
        let document = BackupDocument(createdAt: BackupCodecTests.created, appVersion: "1.1", records: records, settings: [:])
        #expect(document.labourMarkers == [LabourMarkerDTO(water)])
        #expect(document.records.labourMarkers == [water])
    }

    @Test func aMarkersOnlyBackupIsNotEmpty() {
        let empty = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.1",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [], settings: [:]
        )
        #expect(empty.summary.isEmpty)
        var withOne = empty
        withOne.labourMarkers = [LabourMarkerDTO(water)]
        #expect(!withOne.summary.isEmpty)
        #expect(withOne.summary.dateRange == water.at...water.at)
    }

    @Test func validationSkipsAFutureMarkerAndADuplicateId() {
        let now = date("2026-10-09T12:00:00Z")
        let future = LabourMarkerRecord(at: now.addingTimeInterval(60))
        var file = document([water, future])
        file.labourMarkers.append(LabourMarkerDTO(water))
        let (cleaned, skipped) = BackupValidation.clean(file, now: now, calendar: utcCalendar)
        #expect(cleaned.labourMarkers == [LabourMarkerDTO(water)])
        #expect(skipped == 2)
    }
}
