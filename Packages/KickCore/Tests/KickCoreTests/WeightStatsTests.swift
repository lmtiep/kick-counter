import Foundation
import Testing
@testable import KickCore

struct WeightStatsTests {
    /// 24w3d on 2026-10-02; first day of the last period 2026-04-14.
    let dueDate = date("2027-01-19T12:00:00Z")
    let profile = MaternalProfile(preWeightKg: 52, heightCm: 160)

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func pointsCarryTheWeekTheGainAndTheStatus() throws {
        let entries = [
            WeightRecord(day: day("2026-10-02"), kg: 58.0), // 24w3d
            WeightRecord(day: day("2026-07-07"), kg: 53.1), // 12w0d
        ]
        let points = WeightStats.points(entries, profile: profile, dueDate: dueDate, calendar: utcCalendar)
        #expect(points.map(\.kg) == [53.1, 58.0])
        #expect(points.map(\.week) == [GestationalWeek(weeks: 12, days: 0), GestationalWeek(weeks: 24, days: 3)])
        #expect(points.map(\.gainKg) == [1.1, 6.0])
        #expect(points.map(\.status) == [.inRange, .inRange])
        #expect(abs(try #require(points.last).exactWeek - (24 + 3.0 / 7)) < 1e-9)
    }

    @Test func noHeightMeansNoStatusAndNoPreWeightMeansNoGain() {
        let entries = [WeightRecord(day: day("2026-10-02"), kg: 58.0)]
        let noHeight = WeightStats.points(entries, profile: MaternalProfile(preWeightKg: 52), dueDate: dueDate, calendar: utcCalendar)
        #expect(noHeight.first?.gainKg == 6.0)
        #expect(noHeight.first?.status == nil)
        let nothing = WeightStats.points(entries, profile: MaternalProfile(), dueDate: dueDate, calendar: utcCalendar)
        #expect(nothing.first?.gainKg == nil)
        #expect(nothing.first?.status == nil)
    }

    @Test func entriesBeforeThePregnancyAreLeftOffTheChart() {
        let entries = [WeightRecord(day: day("2026-04-13"), kg: 52.0), WeightRecord(day: day("2026-04-14"), kg: 52.1)]
        let points = WeightStats.points(entries, profile: profile, dueDate: dueDate, calendar: utcCalendar)
        #expect(points.map(\.day) == [day("2026-04-14")])
    }

    @Test func sectionsGoNewestWeekFirstWithDaysOutsideLast() {
        let before = WeightRecord(day: day("2026-04-01"), kg: 51.8)
        let w24a = WeightRecord(day: day("2026-09-29"), kg: 57.6)
        let w24b = WeightRecord(day: day("2026-10-02"), kg: 58.0)
        let w12 = WeightRecord(day: day("2026-07-07"), kg: 53.1)
        let sections = WeightStats.sections([w12, before, w24a, w24b], dueDate: dueDate, calendar: utcCalendar)
        #expect(sections.map(\.week) == [24, 12, nil])
        #expect(sections.first?.entries == [w24b, w24a])
        #expect(sections.last?.entries == [before])
    }

    @Test func bandCoversWeeks0To40() {
        let band = WeightStats.band(category: .normal)
        #expect(band.count == 41)
        #expect(band.first == WeightBandPoint(week: 0, lowKg: 0, highKg: 0))
        #expect(band[13].lowKg == 0.5 && band[13].highKg == 2.0)
        #expect(band.last == WeightBandPoint(week: 40, lowKg: 11.5, highKg: 16.0))
    }
}
