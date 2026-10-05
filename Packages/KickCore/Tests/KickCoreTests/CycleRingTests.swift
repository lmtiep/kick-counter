import Foundation
import Testing
@testable import KickCore

struct CycleRingTests {
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Regular 28-day cycles, 5-day periods; the current one started 2026-09-03.
    /// Next period 10-01, ovulation 09-17, fertile window 09-12…09-18.
    private func forecast(on iso: String, periods: [String] = ["2026-07-09", "2026-08-06", "2026-09-03"]) throws -> CycleForecast {
        let records = periods.map { PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0))) }
        return try #require(CyclePredictor.forecast(
            periods: records, logs: [], settings: CycleSettings(), now: date("\(iso)T12:00:00Z"), calendar: utcCalendar
        ))
    }

    @Test func segmentsFollowTheDayStatuses() throws {
        let segments = CycleRingGeometry.segments(for: try forecast(on: "2026-09-05"), calendar: utcCalendar)
        let expected: [(CycleRingKind, Int, Int)] = [
            (.period, 0, 5), (.base, 5, 9), (.fertile, 9, 13), (.ovulation, 13, 15), (.fertile, 15, 16), (.base, 16, 28),
        ]
        #expect(segments == expected.map { CycleRingSegment(kind: $0.0, start: Double($0.1) / 28, end: Double($0.2) / 28) })
    }

    @Test func segmentsCoverTheWholeRing() throws {
        let segments = CycleRingGeometry.segments(for: try forecast(on: "2026-09-20"), calendar: utcCalendar)
        #expect(segments.first?.start == 0)
        #expect(segments.last?.end == 1)
        for (previous, next) in zip(segments, segments.dropFirst()) {
            #expect(previous.end == next.start)
            #expect(previous.kind != next.kind)
        }
    }

    @Test func aLateCycleStretchesTheRing() throws {
        let late = try forecast(on: "2026-10-05")
        #expect(late.cycleDay == 33)
        #expect(CycleRingGeometry.length(of: late) == 33)
        #expect(CycleRingGeometry.segments(for: late, calendar: utcCalendar).last == CycleRingSegment(kind: .base, start: 16.0 / 33, end: 1))
    }

    @Test func markerSitsInTheMiddleOfToday() throws {
        let angle = CycleRingGeometry.markerAngle(for: try forecast(on: "2026-09-05"))
        #expect(abs(angle - 2 * Double.pi * 2.5 / 28) < 1e-9)
        let top = CycleRingGeometry.markerOffset(angle: 0, radius: 125)
        #expect(abs(top.x) < 1e-9 && abs(top.y + 125) < 1e-9)
        let right = CycleRingGeometry.markerOffset(angle: Double.pi / 2, radius: 125)
        #expect(abs(right.x - 125) < 1e-9 && abs(right.y) < 1e-9)
    }

    @Test func headlineDuringAPeriodIsTheCycleDay() throws {
        #expect(CycleRingHeadline(forecast: try forecast(on: "2026-09-05")) == .periodDay(3))
    }

    @Test func headlineCountsDownToTheNextPeriod() throws {
        #expect(CycleRingHeadline(forecast: try forecast(on: "2026-09-20")) == .daysUntilNextPeriod(11))
        #expect(CycleRingHeadline(forecast: try forecast(on: "2026-10-01")) == .nextPeriodToday)
    }

    @Test func headlineWhenLate() throws {
        #expect(CycleRingHeadline(forecast: try forecast(on: "2026-10-05")) == .late(days: 4))
    }

    @Test func cycleDayOfAnyDate() throws {
        let forecast = try forecast(on: "2026-09-20")
        #expect(forecast.cycleDay(on: day("2026-09-20")) == 18)
        #expect(forecast.cycleDay(on: day("2026-08-10")) == 5) // previous cycle (from 08-06)
        #expect(forecast.cycleDay(on: day("2026-07-01")) == nil) // before the first period
        #expect(forecast.cycleDay(on: day("2026-10-01")) == 1) // predicted next cycle
        #expect(forecast.cycleDay(on: day("2026-10-05")) == 5)
    }

    @Test func cycleDayKeepsCountingWhenLate() throws {
        #expect(try forecast(on: "2026-10-05").cycleDay(on: day("2026-10-07")) == 35)
    }
    @Test func regularNeedsTwoSimilarCycles() throws {
        #expect(try forecast(on: "2026-09-20").isRegular)
        #expect(try forecast(on: "2026-09-20", periods: ["2026-09-03"]).isRegular == false)
        #expect(try forecast(on: "2026-09-20", periods: ["2026-05-20", "2026-06-13", "2026-07-18", "2026-08-13", "2026-09-03"]).isRegular == false)
    }
}
