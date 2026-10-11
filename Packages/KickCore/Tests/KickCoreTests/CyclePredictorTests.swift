import Foundation
import Testing
@testable import KickCore

struct CyclePredictorTests {
    let calendar = utcCalendar
    let settings = CycleSettings()

    /// Midnight UTC of a "yyyy-MM-dd" day.
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Noon UTC, as a "now" in the middle of that day.
    private func noon(_ iso: String) -> Date { date("\(iso)T12:00:00Z") }

    /// Closed 5-day periods starting on each day (oldest first).
    private func periods(_ starts: String...) -> [PeriodRecord] {
        starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
    }

    private func forecast(
        _ periods: [PeriodRecord],
        logs: [CycleLogRecord] = [],
        settings: CycleSettings = CycleSettings(),
        now: String
    ) throws -> CycleForecast {
        try #require(CyclePredictor.forecast(periods: periods, logs: logs, settings: settings, now: noon(now), calendar: calendar))
    }

    // MARK: - No data

    @Test func noPeriodsMeansNoForecast() {
        #expect(CyclePredictor.forecast(periods: [], logs: [], settings: settings, now: noon("2026-10-02"), calendar: calendar) == nil)
    }

    @Test func periodsInTheFutureAreIgnored() {
        let future = [PeriodRecord(startDate: day("2026-10-05"))]
        #expect(CyclePredictor.forecast(periods: future, logs: [], settings: settings, now: noon("2026-10-02"), calendar: calendar) == nil)
    }

    @Test func singlePeriodUsesTheTypicalLengthWithLowConfidence() throws {
        let result = try forecast(
            [PeriodRecord(startDate: day("2026-09-20"), endDate: day("2026-09-24"))],
            settings: CycleSettings(typicalCycleLength: 30), now: "2026-10-02"
        )
        #expect(result.cycleDay == 13)
        #expect(result.averageCycleLength == 30)
        #expect(result.usableCycleLengths.isEmpty)
        #expect(result.nextPeriodStart == day("2026-10-20"))
        #expect(result.ovulationDate == day("2026-10-06"))
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 0)
        #expect(result.fertileWindow == day("2026-10-01")...day("2026-10-07"))
        #expect(result.irregularWarning == false)
    }

    // MARK: - Regular cycles

    @Test func regular28DayCycles() throws {
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), now: "2026-09-15")
        #expect(result.currentPeriodStart == day("2026-09-03"))
        #expect(result.cycleDay == 13)
        #expect(result.averageCycleLength == 28)
        #expect(result.usableCycleLengths == [28, 28])
        #expect(result.nextPeriodStart == day("2026-10-01"))
        #expect(result.ovulationDate == day("2026-09-17"))
        #expect(result.ovulationSource == .calendar)
        #expect(result.ovulationConfirmed == false)
        #expect(result.fertileWindow == day("2026-09-12")...day("2026-09-18"))
        #expect(result.confidence == .normal)
        #expect(result.daysLate == 0)
        #expect(result.irregularWarning == false)
        #expect(result.isLongOpenPeriod == false)
    }

    @Test func dayStatusesAcrossARegularCycle() throws {
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), now: "2026-09-15")
        #expect(result.dayStatus(for: day("2026-09-03")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: noon("2026-09-07")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: day("2026-09-08")) == .low)
        #expect(result.dayStatus(for: day("2026-09-11")) == .low)
        #expect(result.dayStatus(for: day("2026-09-12")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-15")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-16")) == .peak)
        #expect(result.dayStatus(for: day("2026-09-17")) == .peak)
        #expect(result.dayStatus(for: day("2026-09-18")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-19")) == .low)
        #expect(result.dayStatus(for: day("2026-09-30")) == .low)
        // Next period is predicted for the typical 5 days.
        #expect(result.dayStatus(for: day("2026-10-01")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-05")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-06")) == .low)
        // The cycle after repeats the calendar prediction.
        #expect(result.dayStatus(for: day("2026-10-09")) == .low)
        #expect(result.dayStatus(for: day("2026-10-10")) == .fertile)
        #expect(result.dayStatus(for: day("2026-10-14")) == .peak)
        #expect(result.dayStatus(for: day("2026-10-15")) == .peak)
        #expect(result.dayStatus(for: day("2026-10-16")) == .fertile)
        #expect(result.dayStatus(for: day("2026-10-29")) == .period(isPredicted: true))
        // Before the logged history: nothing is known.
        #expect(result.dayStatus(for: day("2026-06-01")) == .low)
        #expect(result.dayStatus(for: day("2026-08-08")) == .period(isPredicted: false))
    }

    @Test func short24DayCycles() throws {
        let result = try forecast(periods("2026-08-01", "2026-08-25", "2026-09-18"), now: "2026-09-25")
        #expect(result.averageCycleLength == 24)
        #expect(result.cycleDay == 8)
        #expect(result.nextPeriodStart == day("2026-10-12"))
        #expect(result.ovulationDate == day("2026-09-28"))
        #expect(result.fertileWindow == day("2026-09-23")...day("2026-09-29"))
        #expect(result.dayStatus(for: day("2026-09-25")) == .fertile)
        #expect(result.confidence == .normal)
    }

    @Test func long35DayCycles() throws {
        let result = try forecast(periods("2026-07-01", "2026-08-05", "2026-09-09"), now: "2026-09-20")
        #expect(result.averageCycleLength == 35)
        #expect(result.cycleDay == 12)
        #expect(result.nextPeriodStart == day("2026-10-14"))
        #expect(result.ovulationDate == day("2026-09-30"))
        #expect(result.fertileWindow == day("2026-09-25")...day("2026-10-01"))
        #expect(result.dayStatus(for: day("2026-09-20")) == .low)
        #expect(result.confidence == .normal)
    }

    @Test func averageIsRoundedToTheNearestDay() throws {
        // 29 and 30 → 29.5 → 30.
        let result = try forecast(periods("2026-07-01", "2026-07-30", "2026-08-29"), now: "2026-09-02")
        #expect(result.usableCycleLengths == [29, 30])
        #expect(result.averageCycleLength == 30)
    }

    @Test func onlyTheSixMostRecentCyclesAreAveraged() throws {
        // Two 40-day cycles, then six of 28 days.
        let starts = ["2026-01-01", "2026-02-10", "2026-03-22", "2026-04-19", "2026-05-17", "2026-06-14", "2026-07-12", "2026-08-09", "2026-09-06"]
        let records = starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
        let result = try forecast(records, now: "2026-09-10")
        #expect(result.usableCycleLengths == [28, 28, 28, 28, 28, 28])
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .normal)
    }

    @Test func oneCompleteCycleIsStillLowConfidence() throws {
        let result = try forecast(periods("2026-08-06", "2026-09-03"), now: "2026-09-10")
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 0)
    }

    // MARK: - Irregular cycles

    @Test func irregularCyclesLowerConfidenceAndWidenTheWindow() throws {
        // 24, 35, 26, 34 days: mean 29.75 → 30; spread 11 > 7; SD ≈ 4.8 > 4.
        let result = try forecast(periods("2026-05-01", "2026-05-25", "2026-06-29", "2026-07-25", "2026-08-28"), now: "2026-09-05")
        #expect(result.usableCycleLengths == [24, 35, 26, 34])
        #expect(result.averageCycleLength == 30)
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 3)
        #expect(result.nextPeriodStart == day("2026-09-27"))
        #expect(result.ovulationDate == day("2026-09-13"))
        #expect(result.fertileWindow == day("2026-09-05")...day("2026-09-17"))
        #expect(result.irregularWarning)
        #expect(result.dayStatus(for: day("2026-09-05")) == .fertile)
        #expect(result.dayStatus(for: day("2026-09-04")) == .low)
    }

    @Test func smallVariationKeepsNormalConfidence() throws {
        // 27, 29, 28: spread 2, SD ≈ 0.8.
        let result = try forecast(periods("2026-06-01", "2026-06-28", "2026-07-27", "2026-08-24"), now: "2026-08-30")
        #expect(result.confidence == .normal)
        #expect(result.windowWidening == 0)
        #expect(result.irregularWarning == false)
    }

    @Test func wideningIsHalfTheSpreadUpToThreeDays() throws {
        // 28, 29, 28 then a 36: spread 8 > 7 → low, widening min(3, 8 / 2) = 3.
        let result = try forecast(periods("2026-04-01", "2026-04-29", "2026-05-28", "2026-06-25", "2026-07-31"), now: "2026-08-05")
        #expect(result.usableCycleLengths == [28, 29, 28, 36])
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 3)
    }

    @Test func cyclesOutside21To45DaysAreLeftOutOfTheAverage() throws {
        // 28, then 60 (a missed log), then 28.
        let result = try forecast(periods("2026-05-01", "2026-05-29", "2026-07-28", "2026-08-25"), now: "2026-09-01")
        #expect(result.usableCycleLengths == [28, 28])
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .normal)
        #expect(result.irregularWarning == false)
    }

    @Test func aLatestCycleShorterThan24DaysRaisesTheIrregularWarning() throws {
        let result = try forecast(periods("2026-08-01", "2026-08-29", "2026-09-12"), now: "2026-09-15")
        #expect(result.usableCycleLengths == [28])
        #expect(result.averageCycleLength == 28)
        #expect(result.confidence == .low)
        #expect(result.irregularWarning)
    }

    @Test func aLatestCycleLongerThan45DaysRaisesTheIrregularWarning() throws {
        let result = try forecast(periods("2026-06-01", "2026-06-29", "2026-08-20"), now: "2026-08-25")
        #expect(result.usableCycleLengths == [28])
        #expect(result.irregularWarning)
    }

    /// FIGO 2018 (content review §19): a normal adult cycle is 24–38 days, so a latest
    /// cycle of 21–23 or 39–45 days raises the warning, while it still counts toward
    /// the average (21–45).
    @Test(arguments: [(21, true), (23, true), (24, false), (38, false), (39, true), (45, true)])
    func theIrregularWarningUses24To38Days(latest: Int, warns: Bool) throws {
        let second = try #require(calendar.date(byAdding: .day, value: 28, to: day("2026-05-01")))
        let third = try #require(calendar.date(byAdding: .day, value: latest, to: second))
        let records = [day("2026-05-01"), second, third].map {
            PeriodRecord(startDate: $0, endDate: calendar.date(byAdding: .day, value: 4, to: $0))
        }
        let now = try #require(calendar.date(byAdding: .day, value: 2, to: third))
        let result = try #require(CyclePredictor.forecast(periods: records, logs: [], settings: settings, now: now, calendar: calendar))
        #expect(result.irregularWarning == warns)
        #expect(result.usableCycleLengths == [28, latest])
        #expect(result.averageCycleLength == Int((Double(28 + latest) / 2).rounded()))
    }

    // MARK: - LH tests

    @Test func positiveLHTestMovesOvulationToTheNextDay() throws {
        let logs = [
            CycleLogRecord(day: day("2026-09-13"), lh: .negative),
            CycleLogRecord(day: day("2026-09-14"), lh: .positive),
            CycleLogRecord(day: day("2026-09-15"), lh: .positive),
        ]
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-15")
        #expect(result.ovulationSource == .lhTest)
        #expect(result.ovulationDate == day("2026-09-15"))
        #expect(result.fertileWindow == day("2026-09-10")...day("2026-09-16"))
        #expect(result.nextPeriodStart == day("2026-10-01"))
        #expect(result.dayStatus(for: day("2026-09-14")) == .peak)
        #expect(result.dayStatus(for: day("2026-09-17")) == .low)
    }

    @Test func lhTestsFromAnEarlierCycleAreIgnored() throws {
        let logs = [CycleLogRecord(day: day("2026-08-20"), lh: .positive)]
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-15")
        #expect(result.ovulationSource == .calendar)
        #expect(result.ovulationDate == day("2026-09-17"))
    }

    @Test func lhOverrideIsNotWidenedEvenWithLowConfidence() throws {
        let logs = [CycleLogRecord(day: day("2026-09-10"), lh: .positive)]
        let result = try forecast(periods("2026-05-01", "2026-05-25", "2026-06-29", "2026-07-25", "2026-08-28"), logs: logs, now: "2026-09-12")
        #expect(result.confidence == .low)
        #expect(result.windowWidening == 0)
        #expect(result.ovulationDate == day("2026-09-11"))
        #expect(result.fertileWindow == day("2026-09-06")...day("2026-09-12"))
    }

    // MARK: - Basal body temperature

    /// Readings on consecutive days from `start`.
    private func temperatures(from start: String, _ values: [Double]) -> [CycleLogRecord] {
        values.enumerated().map { offset, value in
            CycleLogRecord(day: calendar.date(byAdding: .day, value: offset, to: day(start))!, bbtCelsius: value)
        }
    }

    @Test func threeHighReadingsOverSixConfirmOvulation() throws {
        let logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6, 36.7, 36.6])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed)
        #expect(result.ovulationSource == .temperature)
        #expect(result.ovulationDate == day("2026-09-10"))
        #expect(result.fertileWindow == day("2026-09-05")...day("2026-09-11"))
    }

    @Test func aRiseOfLessThanTwoTenthsDoesNotConfirm() throws {
        let logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6, 36.5, 36.7])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed == false)
        #expect(result.ovulationSource == .calendar)
    }

    @Test func highReadingsMustBeOnConsecutiveDays() throws {
        var logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6])
        logs += temperatures(from: "2026-09-13", [36.7, 36.6]) // 09-12 is missing
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed == false)
    }

    @Test func fewerThanSixEarlierReadingsDoNotConfirm() throws {
        let logs = temperatures(from: "2026-09-06", [36.3, 36.4, 36.2, 36.4, 36.3, 36.7, 36.8, 36.7])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed == false)
    }

    @Test func readingsBeforeThisCycleAreIgnored() throws {
        // Six low readings at the end of the previous cycle, three high ones in this one.
        let logs = temperatures(from: "2026-08-28", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.7, 36.8, 36.7])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-10")
        #expect(result.ovulationConfirmed == false)
    }

    @Test func baselineIsTheMaxOfThePreviousSixNotTheirMean() throws {
        // Mean of the six baseline readings is ~36.27 (+0.2 = 36.47, which 36.7
        // would clear); the rule uses the max, 36.6 (+0.2 = 36.8), which 36.7
        // does not clear, so this must NOT confirm.
        let logs = temperatures(from: "2026-09-05", [36.2, 36.2, 36.2, 36.2, 36.2, 36.6, 36.7, 36.7, 36.7])
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationConfirmed == false)
    }

    @Test func temperatureConfirmationWinsOverAnLHTest() throws {
        var logs = temperatures(from: "2026-09-05", [36.3, 36.4, 36.2, 36.4, 36.3, 36.4, 36.6, 36.7, 36.6])
        logs.append(CycleLogRecord(day: day("2026-09-07"), lh: .positive))
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), logs: logs, now: "2026-09-14")
        #expect(result.ovulationSource == .temperature)
        #expect(result.ovulationDate == day("2026-09-10"))
    }

    // MARK: - Lateness and long periods

    @Test func daysLateCountFromThePredictedStart() throws {
        let records = periods("2026-07-09", "2026-08-06", "2026-09-03")
        #expect(try forecast(records, now: "2026-10-01").daysLate == 0)
        #expect(try forecast(records, now: "2026-09-25").daysUntilNextPeriod == 6)
        #expect(try forecast(records, now: "2026-10-01").daysUntilNextPeriod == 0)
        let twoDays = try forecast(records, now: "2026-10-03")
        #expect(twoDays.daysLate == 2)
        #expect(twoDays.isNoticeablyLate == false)
        let late = try forecast(records, now: "2026-10-04")
        #expect(late.daysLate == 3)
        #expect(late.isNoticeablyLate)
        #expect(late.daysUntilNextPeriod == 0)
        #expect(late.cycleDay == 32)
        // A missed period is not shown as predicted on days already passed.
        #expect(late.dayStatus(for: day("2026-10-02")) == .low)
    }

    @Test func noFertileOrPeakPredictionWhileAPeriodIsLate() throws {
        // 13 days late (nextPeriodStart 2026-10-01): nothing past the predicted
        // start should show fertile/peak/predicted-period until a new period
        // is actually logged.
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), now: "2026-10-14")
        #expect(result.daysLate == 13)
        #expect(result.nextPeriodStart == day("2026-10-01"))
        #expect(result.dayStatus(for: day("2026-10-14")) == .low)
        for offset in 0...10 {
            let probe = calendar.date(byAdding: .day, value: offset, to: day("2026-10-10"))!
            #expect(result.dayStatus(for: probe) == .low)
        }
    }

    @Test func futureFertileWindowsAreUnaffectedWhenNotLate() throws {
        // Same cycle, but observed before the next period is due: future cycle
        // predictions keep showing their fertile/peak days as before.
        let result = try forecast(periods("2026-07-09", "2026-08-06", "2026-09-03"), now: "2026-09-15")
        #expect(result.daysLate == 0)
        #expect(result.dayStatus(for: day("2026-10-10")) == .fertile)
        #expect(result.dayStatus(for: day("2026-10-14")) == .peak)
        #expect(result.dayStatus(for: day("2026-10-15")) == .peak)
    }

    @Test func openPeriodShowsLoggedDaysThenPredictedDays() throws {
        var records = periods("2026-08-06", "2026-09-03")
        records.append(PeriodRecord(startDate: day("2026-10-01")))
        let result = try forecast(records, now: "2026-10-02")
        #expect(result.cycleDay == 2)
        #expect(result.openPeriod?.startDate == day("2026-10-01"))
        #expect(result.dayStatus(for: day("2026-10-01")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: day("2026-10-02")) == .period(isPredicted: false))
        #expect(result.dayStatus(for: day("2026-10-03")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-05")) == .period(isPredicted: true))
        #expect(result.dayStatus(for: day("2026-10-06")) == .low)
        #expect(result.isLongOpenPeriod == false)
    }

    @Test func periodOpenForMoreThanTenDaysIsFlagged() throws {
        let tenDays = try forecast([PeriodRecord(startDate: day("2026-09-23"))], now: "2026-10-02")
        #expect(tenDays.isLongOpenPeriod == false)
        let elevenDays = try forecast([PeriodRecord(startDate: day("2026-09-22"))], now: "2026-10-02")
        #expect(elevenDays.isLongOpenPeriod)
    }

    // MARK: - Calendar boundaries

    @Test func predictionsCrossMonthAndYearEnds() throws {
        let result = try forecast(periods("2025-12-06", "2026-01-03", "2026-01-31"), now: "2026-02-02")
        #expect(result.usableCycleLengths == [28, 28])
        #expect(result.cycleDay == 3)
        #expect(result.nextPeriodStart == day("2026-02-28"))
        #expect(result.ovulationDate == day("2026-02-14"))
        #expect(result.fertileWindow == day("2026-02-09")...day("2026-02-15"))
    }

    @Test func daylightSavingChangesDoNotShiftDays() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        func local(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
            newYork.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        func closed(_ start: Date) -> PeriodRecord {
            PeriodRecord(startDate: start, endDate: newYork.date(byAdding: .day, value: 4, to: start))
        }

        // Clocks spring forward on 2026-03-08.
        let spring = try #require(CyclePredictor.forecast(
            periods: [closed(local(2026, 1, 23)), closed(local(2026, 2, 20))],
            logs: [], settings: settings, now: local(2026, 3, 10, hour: 12), calendar: newYork
        ))
        #expect(spring.cycleDay == 19)
        #expect(spring.nextPeriodStart == local(2026, 3, 20))
        #expect(newYork.component(.hour, from: spring.nextPeriodStart) == 0)
        #expect(spring.ovulationDate == local(2026, 3, 6))
        #expect(spring.fertileWindow == local(2026, 3, 1)...local(2026, 3, 7))
        #expect(spring.dayStatus(for: local(2026, 3, 7, hour: 23)) == .fertile)
        #expect(spring.dayStatus(for: local(2026, 3, 8, hour: 12)) == .low)

        // Clocks fall back on 2026-11-01, inside the fertile window.
        let fall = try #require(CyclePredictor.forecast(
            periods: [closed(local(2026, 9, 22)), closed(local(2026, 10, 20))],
            logs: [], settings: settings, now: local(2026, 10, 30, hour: 12), calendar: newYork
        ))
        #expect(fall.nextPeriodStart == local(2026, 11, 17))
        #expect(fall.ovulationDate == local(2026, 11, 3))
        #expect(fall.fertileWindow == local(2026, 10, 29)...local(2026, 11, 4))
        #expect(fall.dayStatus(for: local(2026, 11, 1, hour: 12)) == .fertile)
        #expect(fall.dayStatus(for: local(2026, 11, 2, hour: 12)) == .peak)
        #expect(fall.dayStatus(for: local(2026, 11, 3, hour: 1)) == .peak)
    }
}
