import Foundation
import Testing
@testable import KickCore

struct CycleLogSummaryTests {
    let day = date("2026-10-02T00:00:00Z")

    @Test func flowMoodsSymptomsThenTheSignalsInOrder() {
        let log = CycleLogRecord(
            day: day, lh: .positive, bbtCelsius: 36.4, mucus: .eggWhite, note: "x",
            flow: .light, moods: [.happy, .tired], symptoms: [.cramps, .nausea]
        )
        #expect(log.summaryItems(mode: .tryingToConceive) == [
            .flow(.light), .mood(.happy), .mood(.tired), .symptom(.cramps), .symptom(.nausea),
            .temperature(36.4), .lh(.positive), .mucus(.eggWhite), .note,
        ])
        #expect(log.summaryItems(mode: .pregnant).contains(.symptom(.nausea)))
        #expect(!log.summaryItems(mode: .pregnant).contains(.symptom(.cramps)))
    }

    @Test func theNewKindsTakeTheirPlaces() {
        let log = CycleLogRecord(
            day: day, flow: .light, moods: [.sad], spotting: true,
            sex: .protected, sexDrive: .high, pregnancyTest: .positive
        )
        #expect(log.summaryItems(mode: .tryingToConceive) == [
            .flow(.light), .spotting, .mood(.sad), .pregnancyTest(.positive), .sex(.protected), .sexDrive(.high),
        ])
    }

    @Test func unknownValuesAndBlankNotesAreLeftOut() {
        let log = CycleLogRecord(day: day, note: "  ", unknownMoodsRaw: ["excited"])
        #expect(log.summaryItems(mode: .tryingToConceive).isEmpty)
    }
}
