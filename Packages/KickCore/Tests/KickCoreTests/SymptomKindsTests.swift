import Foundation
import Testing
@testable import KickCore

struct SymptomKindsTests {
    @Test func rawListsDecodeInEnumOrderAndEncodeBack() {
        let decoded: (known: [Mood], unknown: [String]) = RawList.decode("tired,happy")
        #expect(decoded.known == [.happy, .tired])
        #expect(decoded.unknown.isEmpty)
        #expect(RawList.encode(decoded.known, unknown: decoded.unknown) == "happy,tired")
    }

    @Test func unknownRawValuesAreKeptOnceInTheOrderFound() {
        let decoded: (known: [Mood], unknown: [String]) = RawList.decode(" excited ,happy,,calm,excited,bored")
        #expect(decoded.known == [.happy, .calm])
        #expect(decoded.unknown == ["excited", "bored"])
        #expect(RawList.encode(decoded.known, unknown: decoded.unknown) == "happy,calm,excited,bored")
    }

    @Test func emptyListsAreStoredAsNil() {
        let decoded: (known: [Symptom], unknown: [String]) = RawList.decode(nil)
        #expect(decoded.known.isEmpty && decoded.unknown.isEmpty)
        #expect(RawList.encode([Symptom](), unknown: []) == nil)
        #expect(RawList.ordered([Symptom.nausea, .cramps, .nausea]) == [.cramps, .nausea])
    }

    @Test func symptomsBelongToOneMode() {
        #expect(Symptom.cases(for: .tryingToConceive) == [.cramps, .headache, .tenderBreasts, .acne, .bloating, .cravings])
        #expect(Symptom.cases(for: .pregnant) == [.nausea, .heartburn, .swollenFeet, .backPain, .legCramps, .insomnia, .contractions])
        #expect(Symptom.allCases.count == 13)
    }

    @Test func flowIsOrderedFromNoneToHeavyAndStoresNone() {
        #expect(MenstrualFlow.allCases.sorted() == [.noFlow, .light, .medium, .heavy])
        #expect([MenstrualFlow.light, .heavy, .noFlow].max() == .heavy)
        #expect(MenstrualFlow.noFlow.rawValue == "none")
        #expect(MenstrualFlow(rawValue: "none") == .noFlow)
    }

    @Test func onlyContractionsAndSwollenFeetShowTheSafetyCard() {
        #expect(Symptom.allCases.filter(\.needsSafetyNote) == [.swollenFeet, .contractions])
        #expect(Symptom.needsSafetyNote([.nausea, .contractions]))
        #expect(Symptom.needsSafetyNote([.swollenFeet]))
        #expect(!Symptom.needsSafetyNote([.nausea, .backPain]))
        #expect(!Symptom.needsSafetyNote([]))
    }

    @Test func settingOneModesSymptomsKeepsTheOthers() {
        var log = CycleLogRecord(day: date("2026-10-02T00:00:00Z"), symptoms: [.cramps, .nausea])
        log.setSymptoms([.contractions, .headache], for: .pregnant)
        #expect(log.symptoms == [.cramps, .contractions])
        #expect(log.symptoms(for: .pregnant) == [.contractions])
        log.setSymptoms([], for: .tryingToConceive)
        #expect(log.symptoms == [.contractions])
    }
}
