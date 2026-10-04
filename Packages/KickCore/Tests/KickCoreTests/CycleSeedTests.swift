import Foundation
import Testing
@testable import KickCore

/// The seeded scenarios must show what the screenshots claim (fixed now 2026-10-02).
struct CycleSeedTests {
    let now = date("2026-10-02T12:00:00Z")

    private func forecast(_ scenario: CycleSeedScenario) -> CycleForecast? {
        let records = scenario.records(today: now, calendar: utcCalendar)
        return CyclePredictor.forecast(periods: records.periods, logs: records.logs, settings: CycleSettings(), now: now, calendar: utcCalendar)
    }

    @Test func emptyHasNoData() {
        #expect(CycleSeedScenario.empty.records(today: now, calendar: utcCalendar) == .init(periods: [], logs: []))
        #expect(forecast(.empty) == nil)
    }

    @Test func periodIsOnCycleDayTwoWithAnOpenPeriod() throws {
        let result = try #require(forecast(.period))
        #expect(result.cycleDay == 2)
        #expect(result.openPeriod != nil)
        #expect(result.dayStatus(for: now) == .period(isPredicted: false))
        #expect(result.confidence == .normal)
    }

    @Test func fertileIsInsideTheWindowWithOvulationInTwoDays() throws {
        let result = try #require(forecast(.fertile))
        #expect(result.cycleDay == 13)
        #expect(result.dayStatus(for: now) == .fertile)
        #expect(result.ovulationDate == date("2026-10-04T00:00:00Z"))
        #expect(result.nextPeriodStart == date("2026-10-18T00:00:00Z"))
        #expect(result.ovulationSource == .calendar)
    }

    @Test func positiveLHTodayMovesOvulationToTomorrow() throws {
        var records = CycleSeedScenario.fertile.records(today: now, calendar: utcCalendar)
        var logs = records.logs
        logs[logs.count - 1].lh = .positive
        records = .init(periods: records.periods, logs: logs)
        let result = try #require(CyclePredictor.forecast(periods: records.periods, logs: records.logs, settings: CycleSettings(), now: now, calendar: utcCalendar))
        #expect(result.ovulationDate == date("2026-10-03T00:00:00Z"))
    }

    @Test func lateIsFourDaysLate() throws {
        let result = try #require(forecast(.late))
        #expect(result.daysLate == 4)
        #expect(result.cycleDay == 33)
        #expect(result.currentPeriodStart == date("2026-08-31T00:00:00Z"))
    }

    @Test func irregularHasLowConfidenceAndTheWarning() throws {
        let result = try #require(forecast(.irregular))
        #expect(result.cycleDay == 11)
        #expect(result.usableCycleLengths == [24, 35, 26, 34])
        #expect(result.confidence == .low)
        #expect(result.irregularWarning)
        #expect(result.dayStatus(for: now) == .fertile)
    }

    @Test func seededDataPassesTheStoreRules() throws {
        for scenario in CycleSeedScenario.allCases {
            let records = scenario.records(today: now, calendar: utcCalendar)
            var accepted: [PeriodRecord] = []
            for period in records.periods {
                try CycleRules.validate(period, existing: accepted, today: now, calendar: utcCalendar)
                accepted.append(period)
            }
            for log in records.logs {
                try CycleRules.validate(log, today: now, calendar: utcCalendar)
            }
        }
    }
}

struct CycleCalendarGridTests {
    private func calendar(firstWeekday: Int, locale: String) -> Calendar {
        var calendar = utcCalendar
        calendar.firstWeekday = firstWeekday
        calendar.locale = Locale(identifier: locale)
        return calendar
    }

    @Test func october2026StartsOnThursday() {
        let sundayFirst = calendar(firstWeekday: 1, locale: "en_US")
        let days = CycleCalendarGrid.days(inMonthOf: date("2026-10-15T12:00:00Z"), calendar: sundayFirst)
        #expect(days.prefix(4).allSatisfy { $0 == nil })
        #expect(days[4] == date("2026-10-01T00:00:00Z"))
        #expect(days.compactMap { $0 }.count == 31)
        #expect(days.last == date("2026-10-31T00:00:00Z"))

        let mondayFirst = calendar(firstWeekday: 2, locale: "vi_VN")
        let vietnamese = CycleCalendarGrid.days(inMonthOf: date("2026-10-15T12:00:00Z"), calendar: mondayFirst)
        #expect(vietnamese.prefix(3).allSatisfy { $0 == nil })
        #expect(vietnamese[3] == date("2026-10-01T00:00:00Z"))
    }

    @Test func monthStartingOnTheFirstWeekdayHasNoBlanks() {
        // 2026-02-01 is a Sunday.
        let days = CycleCalendarGrid.days(inMonthOf: date("2026-02-10T00:00:00Z"), calendar: calendar(firstWeekday: 1, locale: "en_US"))
        #expect(days.first == date("2026-02-01T00:00:00Z"))
        #expect(days.count == 28)
    }

    @Test func monthsStepAcrossYearEnds() {
        let cal = utcCalendar
        #expect(CycleCalendarGrid.month(1, from: date("2026-12-31T23:00:00Z"), calendar: cal) == date("2027-01-01T00:00:00Z"))
        #expect(CycleCalendarGrid.month(-1, from: date("2026-01-31T00:00:00Z"), calendar: cal) == date("2025-12-01T00:00:00Z"))
        #expect(CycleCalendarGrid.startOfMonth(date("2028-02-29T10:00:00Z"), calendar: cal) == date("2028-02-01T00:00:00Z"))
        #expect(CycleCalendarGrid.days(inMonthOf: date("2028-02-29T10:00:00Z"), calendar: cal).compactMap { $0 }.count == 29)
    }

    @Test func weekdaySymbolsFollowTheFirstWeekday() {
        #expect(CycleCalendarGrid.weekdaySymbols(calendar: calendar(firstWeekday: 1, locale: "en_US")) == ["S", "M", "T", "W", "T", "F", "S"])
        let monday = CycleCalendarGrid.weekdaySymbols(calendar: calendar(firstWeekday: 2, locale: "en_US"))
        #expect(monday.first == "M")
        #expect(monday.last == "S")
        #expect(monday.count == 7)
    }
}
