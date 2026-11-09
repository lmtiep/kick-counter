import Foundation
import Testing
@testable import KickCore

struct CycleInsightsTests {
    let calendar = utcCalendar

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Closed 5-day periods: the first starts on `first`, each next one `lengths[i]` days later.
    private func periods(from first: String, lengths: [Int]) -> [PeriodRecord] {
        var start = day(first)
        var result: [PeriodRecord] = []
        for length in lengths + [0] {
            result.append(PeriodRecord(startDate: start, endDate: calendar.date(byAdding: .day, value: 4, to: start)))
            start = calendar.date(byAdding: .day, value: length, to: start)!
        }
        return result
    }

    /// The day `cycleDay` (1-based) of cycle `index` (0-based, oldest first).
    private func dayOf(_ periods: [PeriodRecord], cycle index: Int, cycleDay: Int) -> Date {
        calendar.date(byAdding: .day, value: cycleDay - 1, to: periods[index].startDate)!
    }

    private func insights(_ periods: [PeriodRecord], logs: [CycleLogRecord], now: Date) -> CycleInsights {
        let history = CycleHistory.make(periods: periods, logs: logs, now: now, calendar: calendar)
        return CycleInsights.make(history: history, logs: logs, calendar: calendar)
    }

    private func now(after periods: [PeriodRecord]) -> Date {
        calendar.date(byAdding: .day, value: 3, to: periods.last!.startDate)!
    }

    // MARK: - Patterns

    /// The spec's worked example (§2b).
    @Test func workedExample() throws {
        let p = periods(from: "2026-06-01", lengths: [28, 30, 27, 29])
        let logs = [
            CycleLogRecord(day: dayOf(p, cycle: 0, cycleDay: 26), symptoms: [.headache]),
            CycleLogRecord(day: dayOf(p, cycle: 1, cycleDay: 28), symptoms: [.headache]),
            CycleLogRecord(day: dayOf(p, cycle: 2, cycleDay: 25), symptoms: [.headache]),
            CycleLogRecord(day: dayOf(p, cycle: 3, cycleDay: 3), flow: .light),
        ]
        let result = insights(p, logs: logs, now: now(after: p))
        #expect(result.patterns == [CycleInsights.Pattern(
            item: .symptom(.headache), anchor: .daysBefore, window: 3...3, cyclesWithItem: 3, cyclesLogged: 4
        )])
    }

    @Test func fewerThanThreeCyclesIsNoPattern() {
        let p = periods(from: "2026-06-01", lengths: [28, 28])
        let logs = (0..<2).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 1), symptoms: [.cramps]) }
        #expect(insights(p, logs: logs, now: now(after: p)).patterns.isEmpty)
    }

    @Test func threeOfSixLoggedCyclesIsEnough() {
        let p = periods(from: "2026-03-01", lengths: [28, 28, 28, 28, 28, 28])
        let flow = (0..<6).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 10), flow: .noFlow) }
        let cramps = (0..<3).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 1), symptoms: [.cramps]) }
        #expect(insights(p, logs: flow + cramps, now: now(after: p)).patterns.map(\.item) == [.symptom(.cramps)])
    }

    @Test func onlyTheLastSixCompletedCyclesCount() {
        // Cramps in cycles 0, 1, 2 of 7: cycle 0 drops out, leaving 2.
        let p = periods(from: "2026-01-01", lengths: [28, 28, 28, 28, 28, 28, 28])
        let cramps = (0..<3).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 1), symptoms: [.cramps]) }
        #expect(insights(p, logs: cramps, now: now(after: p)).patterns.isEmpty)
    }

    @Test func aWindowWiderThanFiveDaysIsNoPattern() {
        let p = periods(from: "2026-06-01", lengths: [28, 28, 28])
        let logs = [1, 8, 15].enumerated().map { CycleLogRecord(day: dayOf(p, cycle: $0.offset, cycleDay: $0.element), moods: [.sad]) }
        #expect(insights(p, logs: logs, now: now(after: p)).patterns.isEmpty)
    }

    @Test func aTieGoesToTheStartOfThePeriod() throws {
        // Same length cycles: both anchors give a 1-day window.
        let p = periods(from: "2026-06-01", lengths: [28, 28, 28])
        let logs = (0..<3).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 2), symptoms: [.cramps]) }
        let pattern = try #require(insights(p, logs: logs, now: now(after: p)).patterns.first)
        #expect(pattern.anchor == .startDay)
        #expect(pattern.window == 2...2)
    }

    @Test func threeQuartersOfTheOccurrencesSetTheWindow() throws {
        // Start days 1, 2, 2, 20: ⌈0.75 × 4⌉ = 3 → 1...2; the outlier is left out.
        let p = periods(from: "2026-06-01", lengths: [28, 28, 28, 28])
        let logs = [1, 2, 2, 20].enumerated().map { CycleLogRecord(day: dayOf(p, cycle: $0.offset, cycleDay: $0.element), symptoms: [.cramps]) }
        let pattern = try #require(insights(p, logs: logs, now: now(after: p)).patterns.first)
        #expect(pattern.anchor == .startDay && pattern.window == 1...2 && pattern.cyclesWithItem == 4)
    }

    @Test func onlyTheFirstDayInACycleCounts() throws {
        let p = periods(from: "2026-06-01", lengths: [28, 28, 28])
        let logs = (0..<3).flatMap { cycle in
            [1, 2, 3].map { CycleLogRecord(day: dayOf(p, cycle: cycle, cycleDay: $0), symptoms: [.cramps]) }
        }
        #expect(try #require(insights(p, logs: logs, now: now(after: p)).patterns.first).window == 1...1)
    }

    @Test func pregnancyOnlySymptomsAreIgnoredButSharedOnesCount() {
        let p = periods(from: "2026-06-01", lengths: [28, 28, 28])
        let logs = (0..<3).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 5), symptoms: [.heartburn, .nausea]) }
        #expect(insights(p, logs: logs, now: now(after: p)).patterns.map(\.item) == [.symptom(.nausea)])
    }

    @Test func spottingCanBeAPattern() {
        let p = periods(from: "2026-06-01", lengths: [28, 28, 28])
        let logs = (0..<3).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 14), spotting: true) }
        #expect(insights(p, logs: logs, now: now(after: p)).patterns.map(\.item) == [.spotting])
    }

    @Test func aLongGapIsNeverOneOfTheCycles() {
        // 28, 28, 120 (a pregnancy), 28, 28: the 120-day gap is not counted.
        let p = periods(from: "2025-12-01", lengths: [28, 28, 120, 28, 28])
        let logs = [
            CycleLogRecord(day: dayOf(p, cycle: 0, cycleDay: 3), moods: [.sad]),
            CycleLogRecord(day: dayOf(p, cycle: 1, cycleDay: 3), moods: [.sad]),
            CycleLogRecord(day: dayOf(p, cycle: 2, cycleDay: 3), moods: [.sad]),
        ]
        let result = insights(p, logs: logs, now: now(after: p))
        #expect(result.patterns.isEmpty)
        #expect(result.lengths.map(\.length) == [28, 28, 120, 28, 28])
        #expect(result.lengths.map(\.counts) == [true, true, false, true, true])
        #expect(result.regularity == .regular(spread: 0))
    }

    @Test func rankingByShareThenWidthThenDisplayOrderCappedAtFive() {
        let p = periods(from: "2026-03-01", lengths: [28, 28, 28, 28])
        var logs: [CycleLogRecord] = []
        // In all 4 cycles, window 1 day: happy, calm, cramps, headache, acne, bloating (six items).
        for cycle in 0..<4 {
            logs.append(CycleLogRecord(
                day: dayOf(p, cycle: cycle, cycleDay: 3),
                moods: [.happy, .calm], symptoms: [.cramps, .headache, .acne, .bloating]
            ))
        }
        // Sad in 3/4 only: ranks below all of them.
        for cycle in 0..<3 {
            logs.append(CycleLogRecord(day: dayOf(p, cycle: cycle, cycleDay: 10), moods: [.sad]))
        }
        let items = insights(p, logs: logs, now: now(after: p)).patterns.map(\.item)
        // Calm ("Bình thường") is never a pattern.
        #expect(items == [.mood(.happy), .symptom(.cramps), .symptom(.headache), .symptom(.acne), .symptom(.bloating)])
    }

    // MARK: - Lengths and regularity

    @Test func lengthsNeedTwoCompletedCycles() {
        let one = periods(from: "2026-06-01", lengths: [28])
        #expect(insights(one, logs: [], now: now(after: one)).lengths.isEmpty)
        let two = periods(from: "2026-06-01", lengths: [28, 30])
        #expect(insights(two, logs: [], now: now(after: two)).lengths.map(\.length) == [28, 30])
    }

    @Test func lengthsKeepTheLastTwelve() {
        let p = periods(from: "2025-01-01", lengths: Array(21...34))
        #expect(insights(p, logs: [], now: now(after: p)).lengths.map(\.length) == Array(23...34))
    }

    @Test(arguments: [
        ([28, 28, 35], CycleInsights.Regularity.regular(spread: 7)),
        ([28, 28, 36], .somewhatVariable(spread: 8)),
        ([28, 28, 37], .somewhatVariable(spread: 9)),
        ([28, 28, 38], .variable(spread: 10)),
    ])
    func regularityBands(lengths: [Int], expected: CycleInsights.Regularity) {
        let p = periods(from: "2026-01-01", lengths: lengths)
        #expect(insights(p, logs: [], now: now(after: p)).regularity == expected)
    }

    @Test func regularityNeedsThreeCountedCycles() {
        let p = periods(from: "2026-01-01", lengths: [28, 50, 30])
        #expect(insights(p, logs: [], now: now(after: p)).regularity == nil)
    }

    @Test func regularityUsesTheLastSixCounted() {
        // 21 first, then six cycles of 28–30: the 21 drops out.
        let p = periods(from: "2025-12-01", lengths: [21, 28, 29, 30, 28, 29, 30])
        #expect(insights(p, logs: [], now: now(after: p)).regularity == .regular(spread: 2))
    }

    // MARK: - Today

    private func patterns() -> CycleInsights {
        let p = periods(from: "2026-06-01", lengths: [28, 30, 27, 29])
        let headache = [26, 28, 25].enumerated().map {
            CycleLogRecord(day: dayOf(p, cycle: $0.offset, cycleDay: $0.element), symptoms: [.headache])
        }
        let cramps = (0..<4).map { CycleLogRecord(day: dayOf(p, cycle: $0, cycleDay: 1), symptoms: [.cramps]) }
        return insights(p, logs: headache + cramps, now: now(after: p))
    }

    @Test func todayMatchesAStartDayPattern() {
        let result = patterns()
        #expect(result.todayPattern(cycleDay: 1, daysUntilNextPeriod: 27, nextPeriodIsReliable: true)?.item == .symptom(.cramps))
        #expect(result.todayPattern(cycleDay: 2, daysUntilNextPeriod: 26, nextPeriodIsReliable: true) == nil)
    }

    @Test func todayMatchesADaysBeforePatternOnlyWhenTheNextPeriodIsReliable() {
        let result = patterns()
        // 3 days before the next period.
        #expect(result.todayPattern(cycleDay: 26, daysUntilNextPeriod: 3, nextPeriodIsReliable: true)?.item == .symptom(.headache))
        #expect(result.todayPattern(cycleDay: 26, daysUntilNextPeriod: 3, nextPeriodIsReliable: false) == nil)
        #expect(result.todayPattern(cycleDay: 26, daysUntilNextPeriod: 2, nextPeriodIsReliable: true) == nil)
    }

    // MARK: - Chart (review fix: a pregnancy gap must not squash the normal bars)

    @Test func longBarsAreCappedForTheChart() {
        let p = periods(from: "2025-01-01", lengths: [28, 280, 30])
        let bars = insights(p, logs: [], now: now(after: p)).lengths
        #expect(bars.map(\.length) == [28, 280, 30])
        #expect(bars.map(\.shownLength) == [28, CycleInsights.chartCap, 30])
        #expect(bars.map(\.isCapped) == [false, true, false])
        #expect(CycleInsights.chartCap == 60)
    }
}
