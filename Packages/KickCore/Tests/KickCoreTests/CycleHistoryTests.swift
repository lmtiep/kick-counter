import Foundation
import Testing
@testable import KickCore

struct CycleHistoryTests {
    let calendar = utcCalendar

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }
    private func noon(_ iso: String) -> Date { date("\(iso)T12:00:00Z") }

    /// Closed 5-day periods starting on each day (any order).
    private func periods(_ starts: String...) -> [PeriodRecord] {
        starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
    }

    private func history(_ periods: [PeriodRecord], logs: [CycleLogRecord] = [], now: String) -> CycleHistorySummary {
        CycleHistory.make(periods: periods, logs: logs, now: noon(now), calendar: calendar)
    }

    @Test func noPeriodsGivesAnEmptyHistory() {
        let result = history([], now: "2026-10-02")
        #expect(result.cycles.isEmpty)
        #expect(result.averageCycleLength == nil)
        #expect(result.cycleLengthRange == nil)
        #expect(result.averagePeriodLength == nil)
    }

    @Test func onePeriodIsTheCurrentCycleOnly() throws {
        let result = history(periods("2026-09-20"), now: "2026-10-02")
        let only = try #require(result.cycles.first)
        #expect(result.cycles.count == 1)
        #expect(only.isCurrent)
        #expect(only.length == nil)
        #expect(only.cycleDay == 13)
        #expect(only.countsTowardAverage == false)
        #expect(only.periodLength == 5)
        #expect(result.averageCycleLength == nil)
        #expect(result.cycleLengthRange == nil)
        #expect(result.averagePeriodLength == 5)
    }

    @Test func cyclesAreNewestFirstWithLengths() {
        let result = history(periods("2026-07-26", "2026-06-28", "2026-09-20", "2026-08-23"), now: "2026-10-02")
        #expect(result.cycles.map(\.start) == [day("2026-09-20"), day("2026-08-23"), day("2026-07-26"), day("2026-06-28")])
        #expect(result.cycles.map(\.length) == [nil, 28, 28, 28])
        #expect(result.cycles.map(\.isCurrent) == [true, false, false, false])
        #expect(result.cycles.map(\.cycleDay) == [13, nil, nil, nil])
        #expect(result.averageCycleLength == 28)
        #expect(result.cycleLengthRange == 28...28)
    }

    @Test func rangeAndAverageUseUsableCyclesOnly() {
        // 26, 18 (too short), 31, 50 (too long), then the current cycle.
        let result = history(periods("2026-04-01", "2026-04-27", "2026-05-15", "2026-06-15", "2026-08-04"), now: "2026-08-10")
        #expect(result.cycles.map(\.length) == [nil, 50, 31, 18, 26])
        #expect(result.cycles.map(\.countsTowardAverage) == [false, false, true, false, true])
        #expect(result.cycleLengthRange == 26...31)
        #expect(result.averageCycleLength == 29) // (26 + 31) / 2 = 28.5, rounded
    }

    @Test func averageMatchesTheForecast() throws {
        let input = periods("2026-03-01", "2026-03-27", "2026-04-27", "2026-05-24", "2026-06-23", "2026-07-20", "2026-08-19", "2026-09-17")
        let forecast = try #require(CyclePredictor.forecast(periods: input, logs: [], settings: CycleSettings(), now: noon("2026-10-02"), calendar: calendar))
        #expect(history(input, now: "2026-10-02").averageCycleLength == forecast.averageCycleLength)
    }

    @Test func onlyTheLastSixUsableCyclesAreAveraged() {
        // Seven 30-day cycles, then one 22-day cycle: the oldest 30 drops out.
        let starts = ["2026-01-01", "2026-01-31", "2026-03-02", "2026-04-01", "2026-05-01", "2026-05-31", "2026-06-30", "2026-07-30", "2026-08-21"]
        let result = CycleHistory.make(periods: starts.flatMap { periods($0) }, logs: [], now: noon("2026-09-01"), calendar: calendar)
        #expect(result.averageCycleLength == 29) // (5 × 30 + 22) / 6 = 28.67
        #expect(result.cycleLengthRange == 22...30)
    }

    @Test func openPeriodCountsUpToTodayCappedAtTenDays() {
        let open = [PeriodRecord(startDate: day("2026-09-28"))]
        #expect(history(open, now: "2026-10-02").cycles.first?.periodLength == 5)
        let long = [PeriodRecord(startDate: day("2026-09-10"))]
        #expect(history(long, now: "2026-10-02").cycles.first?.periodLength == 10)
    }

    @Test func averagePeriodLengthUsesClosedPeriodsOnly() {
        let closed = PeriodRecord(startDate: day("2026-08-23"), endDate: day("2026-08-28")) // 6 days
        let open = PeriodRecord(startDate: day("2026-09-20"))
        #expect(history([closed, open], now: "2026-10-02").averagePeriodLength == 6)
    }

    @Test func futurePeriodsAreIgnored() {
        let result = history(periods("2026-09-20", "2026-10-10"), now: "2026-10-02")
        #expect(result.cycles.count == 1)
        #expect(result.cycles.first?.isCurrent == true)
    }

    @Test func loggedDaysAreOffsetsWithinTheCycle() {
        let logs = [
            CycleLogRecord(day: day("2026-08-23"), flow: .heavy),          // offset 0 of the August cycle
            CycleLogRecord(day: day("2026-09-19"), moods: [.tired]),       // offset 27, last day of August's cycle
            CycleLogRecord(day: day("2026-09-20"), symptoms: [.cramps]),   // offset 0 of the current cycle
            CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 36.4),      // offset 12
            CycleLogRecord(day: day("2026-10-05"), flow: .light),          // after today: ignored
        ]
        let result = history(periods("2026-08-23", "2026-09-20"), logs: logs, now: "2026-10-02")
        #expect(result.cycles.map(\.loggedDays) == [[0, 12], [0, 27]])
    }

    @Test func aBlankNoteIsNotContent() {
        #expect(CycleLogRecord(day: day("2026-10-01"), note: "  \n").hasContent == false)
        #expect(CycleLogRecord(day: day("2026-10-01")).hasContent == false)
        #expect(CycleLogRecord(day: day("2026-10-01"), note: "đau lưng").hasContent)
        #expect(CycleLogRecord(day: day("2026-10-01"), lh: .negative).hasContent)
        #expect(CycleLogRecord(day: day("2026-10-01"), mucus: .dry).hasContent)
        #expect(CycleLogRecord(day: day("2026-10-01"), flow: .noFlow).hasContent)
    }

    @Test func emptyLogsAreNotLoggedDays() {
        let logs = [CycleLogRecord(day: day("2026-09-22"), note: " ")]
        #expect(history(periods("2026-09-20"), logs: logs, now: "2026-10-02").cycles.first?.loggedDays == [])
    }

    @Test func aPregnancyOnlySymptomIsNotContent() {
        #expect(CycleLogRecord(day: day("2026-10-01"), symptoms: [.nausea]).hasContent == false)
        let logs = [CycleLogRecord(day: day("2026-09-22"), symptoms: [.nausea])]
        #expect(history(periods("2026-09-20"), logs: logs, now: "2026-10-02").cycles.first?.loggedDays == [])
    }
}
