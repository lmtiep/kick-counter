import Foundation
import Testing
@testable import KickCore

/// Celebration art spec §1: the baby's optional details.
struct BirthDetailsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    @Test func namesAreTrimmedAndEmptyBecomesNil() {
        #expect(BirthDetails(name: "  Minh An \n").name == "Minh An")
        #expect(BirthDetails(name: "   ").name == nil)
        #expect(BirthDetails(name: "").isEmpty)
    }

    @Test func numbersOutsideTheirRangeAreLeftOut() {
        #expect(BirthDetails(weightKg: 3.2).weightKg == 3.2)
        #expect(BirthDetails(weightKg: 0.4).weightKg == nil)
        #expect(BirthDetails(weightKg: 7.1).weightKg == nil)
        #expect(BirthDetails(weightKg: 3200).weightKg == 3.2, "grams, as often said in Vietnam")
        #expect(BirthDetails(weightKg: 499).weightKg == nil)
        #expect(BirthDetails(weightKg: 7001).weightKg == nil)
        #expect(BirthDetails(lengthCm: 50).lengthCm == 50)
        #expect(BirthDetails(lengthCm: 24).lengthCm == nil)
        #expect(BirthDetails(lengthCm: 66).lengthCm == nil)
    }

    @Test func emptyOnlyWithNothingSet() {
        #expect(BirthDetails().isEmpty)
        #expect(BirthDetails(time: date("2026-11-08T06:42:00+07:00")).isEmpty == false)
        #expect(BirthDetails(lengthCm: 50).isEmpty == false)
    }

    @Test func decimalsParseWithACommaOrADot() {
        #expect(BirthDetails.parseDecimal("3,2") == 3.2)
        #expect(BirthDetails.parseDecimal(" 3.2 ") == 3.2)
        #expect(BirthDetails.parseDecimal("50") == 50)
        #expect(BirthDetails.parseDecimal("") == nil)
        #expect(BirthDetails.parseDecimal("abc") == nil)
        #expect(BirthDetails.parseDecimal("3,2,1") == nil)
    }

    @Test func contentWithoutBabyStillDecodes() throws {
        let content = PregnancyMemoryContent(
            branch: .birth, start: nil, end: date("2026-11-08T00:00:00+07:00"), furthestWeek: 39
        )
        var json = try JSONSerialization.jsonObject(
            with: PregnancyMemoryContent.encoder.encode(content)
        ) as! [String: Any]
        json.removeValue(forKey: "baby")
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try PregnancyMemoryContent.decoder.decode(PregnancyMemoryContent.self, from: old)
        #expect(decoded.baby == nil)
        #expect(decoded.furthestWeek == 39)
    }

    @Test func contentKeepsTheBabyThroughJSON() throws {
        let baby = BirthDetails(
            name: "Minh An", time: date("2026-11-08T06:42:00+07:00"), weightKg: 3.2, lengthCm: 50
        )
        let content = PregnancyMemoryContent(
            branch: .birth, start: nil, end: date("2026-11-08T00:00:00+07:00"), furthestWeek: 39, baby: baby
        )
        let data = try PregnancyMemoryContent.encoder.encode(content)
        let decoded = try PregnancyMemoryContent.decoder.decode(PregnancyMemoryContent.self, from: data)
        #expect(decoded.baby == baby)
    }

    @Test func builderKeepsTheBabyOnlyForABirthWithDetails() {
        let profile = PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil)
        func make(_ branch: PregnancyEndBranch, _ baby: BirthDetails?) -> PregnancyMemoryContent {
            PregnancyMemoryBuilder.make(
                branch: branch, profile: profile, endDate: date("2026-11-08T00:00:00+07:00"),
                sessions: [], contractions: [], appointments: [], weights: [], logs: [],
                calendar: calendar, baby: baby
            )
        }
        let baby = BirthDetails(name: "Minh An")
        #expect(make(.birth, baby).baby == baby)
        #expect(make(.loss, baby).baby == nil)
        #expect(make(.birth, BirthDetails(name: " ")).baby == nil)
        #expect(make(.birth, nil).baby == nil)
    }

    @Test func recapCarriesTheBaby() {
        let baby = BirthDetails(name: "Minh An", weightKg: 3.2)
        let content = PregnancyMemoryContent(
            branch: .birth, start: nil, end: date("2026-11-08T00:00:00+07:00"), furthestWeek: 39, baby: baby
        )
        #expect(PregnancyRecap.make(content: content, calendar: calendar).baby == baby)
    }
}
