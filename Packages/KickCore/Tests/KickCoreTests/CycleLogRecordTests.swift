import Foundation
import Testing
@testable import KickCore

struct CycleLogRecordTests {
    let day = date("2026-10-02T00:00:00Z")

    @Test(arguments: [
        CycleLogRecord(day: date("2026-10-02T00:00:00Z"), spotting: true),
        CycleLogRecord(day: date("2026-10-02T00:00:00Z"), sex: .unprotected),
        CycleLogRecord(day: date("2026-10-02T00:00:00Z"), sexDrive: .low),
        CycleLogRecord(day: date("2026-10-02T00:00:00Z"), pregnancyTest: .negative),
    ])
    func eachNewKindAloneIsSomethingLogged(log: CycleLogRecord) {
        #expect(!log.isEmpty)
        #expect(log.hasContent)
    }

    @Test func nothingIsStillEmpty() {
        #expect(CycleLogRecord(day: day).isEmpty)
    }

    @Test func withIDKeepsTheNewKinds() {
        let log = CycleLogRecord(day: day, spotting: true, sex: .protected, sexDrive: .normal, pregnancyTest: .positive)
        let copy = log.withID(UUID())
        #expect(copy.spotting && copy.sex == .protected && copy.sexDrive == .normal && copy.pregnancyTest == .positive)
    }

    @Test func clearingASharedSymptomInCycleModeKeepsPregnancyOnes() {
        var log = CycleLogRecord(day: day, symptoms: [.nausea, .heartburn])
        log.setSymptoms([], for: .tryingToConceive)
        #expect(log.symptoms == [.heartburn])
        log.setSymptoms([.diarrhea], for: .tryingToConceive)
        #expect(log.symptoms == [.heartburn, .diarrhea])
        #expect(log.symptoms(for: .tryingToConceive) == [.diarrhea])
    }

    @Test func aSharedSymptomShowsInBothModes() {
        let log = CycleLogRecord(day: day, symptoms: [.backPain])
        #expect(log.symptoms(for: .tryingToConceive) == [.backPain])
        #expect(log.symptoms(for: .pregnant) == [.backPain])
        #expect(log.hasContent)
    }
}
