import Foundation
import Testing
@testable import KickCore

struct CycleRecordsMergeNewKindsTests {
    @Test func sameDayLogsKeepTheCautiousReadingOfTheNewKinds() {
        let day = date("2026-10-01T00:00:00Z")
        let a = CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day,
            sex: .protected, sexDrive: .low, pregnancyTest: .negative
        )
        let b = CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: day,
            spotting: true, sex: .unprotected, sexDrive: .high, pregnancyTest: .positive
        )
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let merged = CycleRules.mergingDuplicates([b, a], calendar: utc).logs
        #expect(merged.count == 1)
        #expect(merged.first?.id == a.id)
        #expect(merged.first?.spotting == true)
        #expect(merged.first?.sex == .unprotected)
        #expect(merged.first?.sexDrive == .low)
        #expect(merged.first?.pregnancyTest == .positive)
    }
}
