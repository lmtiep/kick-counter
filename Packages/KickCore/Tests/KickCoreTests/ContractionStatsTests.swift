import Foundation
import Testing
@testable import KickCore

/// Phase 20 spec §3.2: durations, intervals, episodes, the last-hour window,
/// the 5-1-1 and preterm alerts at every threshold, validation.
struct ContractionStatsTests {
    let now = date("2026-10-10T12:00:00Z")
    let term = GestationalWeek(weeks: 38, days: 0)

    /// A completed contraction starting `secondsAgo` before `now`.
    private func done(_ secondsAgo: TimeInterval, lasting duration: TimeInterval = 60) -> ContractionRecord {
        let start = now.addingTimeInterval(-secondsAgo)
        return ContractionRecord(startedAt: start, endedAt: start.addingTimeInterval(duration))
    }

    private func running(_ secondsAgo: TimeInterval) -> ContractionRecord {
        ContractionRecord(startedAt: now.addingTimeInterval(-secondsAgo))
    }

    /// `count` completed contractions `every` seconds apart, the last one
    /// starting `lastAgo` seconds before `now`.
    private func series(
        _ count: Int, every interval: TimeInterval, lasting duration: TimeInterval = 60, lastAgo: TimeInterval = 60
    ) -> [ContractionRecord] {
        (0..<count).map { done(lastAgo + Double(count - 1 - $0) * interval, lasting: duration) }
    }

    private func stats(
        _ records: [ContractionRecord], week: GestationalWeek? = nil, endedAt: Date? = nil, at time: Date? = nil
    ) -> ContractionStats {
        ContractionStats(contractions: records, now: time ?? now, week: week, episodeEndedAt: endedAt)
    }

    // MARK: - Durations and intervals

    @Test func durationsAndIntervals() throws {
        let records = [done(900, lasting: 50), done(600, lasting: 70), running(20)]
        let episode = try #require(stats(records).currentEpisode)
        #expect(episode.entries.map(\.duration) == [50, 70, 20])
        #expect(episode.entries.map(\.interval) == [nil, 300, 580])
        #expect(episode.entries.map(\.isRunning) == [false, false, true])
        #expect(stats(records).running?.id == records[2].id)
    }

    @Test func recordsAreSortedByStart() throws {
        let records = [done(300), done(900), done(600)]
        let episode = try #require(stats(records).currentEpisode)
        #expect(episode.entries.map(\.startedAt) == records.map(\.startedAt).sorted())
    }

    // MARK: - Episodes

    @Test func aGapOfExactlyTwoHoursKeepsTheEpisode() {
        let result = stats([done(7200 + 600), done(600)])
        #expect(result.episodes.count == 1)
        #expect(result.currentEpisode?.entries.map(\.interval) == [nil, 7200])
    }

    @Test func aGapLongerThanTwoHoursStartsANewEpisode() throws {
        let result = stats([done(7201 + 600), done(600)])
        #expect(result.episodes.count == 2)
        let current = try #require(result.currentEpisode)
        #expect(current.count == 1)
        #expect(current.entries.first?.interval == nil)
        #expect(result.pastEpisodes.count == 1)
    }

    @Test func theCurrentEpisodeLastsTwoHoursAfterItsLastStart() {
        #expect(stats([done(7200)]).currentEpisode != nil)
        #expect(stats([done(7201)]).currentEpisode == nil)
        #expect(stats([done(7201)]).pastEpisodes.count == 1)
    }

    @Test func endingTheEpisodeClosesItAndTheNextContractionStartsAnother() throws {
        let records = [done(1200), done(900)]
        let ended = stats(records, endedAt: now.addingTimeInterval(-800))
        #expect(ended.currentEpisode == nil)
        #expect(ended.pastEpisodes.count == 1)

        let next = stats(records + [done(300)], endedAt: now.addingTimeInterval(-800))
        #expect(next.episodes.count == 2)
        let current = try #require(next.currentEpisode)
        #expect(current.count == 1)
        #expect(current.entries.first?.interval == nil)
    }

    @Test func pastEpisodesAreNewestFirstWithTheirSummaries() throws {
        let morning = series(3, every: 600, lasting: 40, lastAgo: 5 * 3600)
        let noon = series(2, every: 300, lasting: 60, lastAgo: 60)
        let result = stats(morning + noon)
        #expect(result.pastEpisodes.count == 1)
        let past = try #require(result.pastEpisodes.first)
        #expect(past.count == 3)
        #expect(past.averageDuration == 40)
        #expect(past.averageInterval == 600)
        #expect(past.startedAt == morning[0].startedAt)
        #expect(past.lastStartedAt == morning[2].startedAt)
        #expect(past.endedAt == morning[2].endedAt)
        #expect(result.currentEpisode?.id == noon[0].id)
    }

    // MARK: - Last hour

    @Test func theLastHourIncludesAStartExactlySixtyMinutesAgo() {
        #expect(stats([done(3600)]).lastHour.count == 1)
        #expect(stats([done(3601)]).lastHour.count == 0)
    }

    @Test func theLastHourCountsCompletedContractionsOnly() {
        let result = stats([done(600, lasting: 40), done(300, lasting: 50), running(10)])
        #expect(result.lastHour.count == 2)
        #expect(result.lastHour.averageDuration == 45)
        #expect(result.lastHour.averageInterval == 300)
    }

    @Test func theLastHourAveragesUseOnlyItsOwnContractions() {
        // The one 70 minutes ago is outside: its interval and duration don't count.
        let result = stats([done(4200, lasting: 200), done(1200, lasting: 30), done(600, lasting: 60)])
        #expect(result.lastHour.count == 2)
        #expect(result.lastHour.averageDuration == 45)
        #expect(result.lastHour.averageInterval == 600)
    }

    @Test func emptyAndSingleWindows() {
        #expect(stats([]).lastHour == ContractionSummary(count: 0, averageDuration: nil, averageInterval: nil))
        #expect(stats([done(60, lasting: 30)]).lastHour == ContractionSummary(count: 1, averageDuration: 30, averageInterval: nil))
    }

    // MARK: - 5-1-1 (week 37 or later, or unknown)

    @Test func fiveOneOneAtEveryThreshold() {
        // 14 contractions 5:30 apart, 45 s each: 11 in the last hour, span 71:30.
        let pattern = series(14, every: 330, lasting: 45)
        let result = stats(pattern, week: term)
        #expect(result.lastHour.count == 11)
        #expect(result.lastHour.averageInterval == 330)
        #expect(result.lastHour.averageDuration == 45)
        #expect(result.alert == .fiveOneOne)
    }

    @Test func anIntervalOverFiveThirtyIsNotFiveOneOne() {
        #expect(stats(series(14, every: 331, lasting: 45), week: term).alert == .none)
    }

    @Test func aDurationUnderFortyFiveSecondsIsNotFiveOneOne() {
        #expect(stats(series(14, every: 300, lasting: 44.9), week: term).alert == .none)
        #expect(stats(series(14, every: 300, lasting: 45), week: term).alert == .fiveOneOne)
    }

    @Test func sixContractionsInTheHourAreNeeded() {
        // Two early ones make the episode span over an hour; the last hour holds 6, then 5.
        let early = [done(110 * 60), done(90 * 60)]
        let six = (0..<6).map { done(Double(30 - 5 * $0) * 60) }
        #expect(stats(early + six, week: term).lastHour.count == 6)
        #expect(stats(early + six, week: term).alert == .fiveOneOne)
        let five = Array(six.dropFirst())
        #expect(stats(early + five, week: term).lastHour.count == 5)
        #expect(stats(early + five, week: term).alert == .none)
    }

    @Test func theEpisodeMustSpanSixtyMinutes() {
        // 13 starts 5 min apart, last one a minute ago: the first is outside the
        // last hour and the span is exactly 60:00.
        let exact = series(13, every: 300)
        #expect(stats(exact, week: term).currentEpisode?.span == 3600)
        #expect(stats(exact, week: term).alert == .fiveOneOne)
        // The first one a second later: span 59:59, the last hour unchanged.
        var short = exact
        short[0] = done(60 + 3599)
        #expect(stats(short, week: term).currentEpisode?.span == 3599)
        #expect(stats(short, week: term).lastHour == stats(exact, week: term).lastHour)
        #expect(stats(short, week: term).alert == .none)
    }

    @Test func theSpanCountsCompletedContractionsOfTheCurrentEpisodeOnly() {
        // A new episode began 70 minutes ago after a 3-hour gap: the old one doesn't stretch the span.
        let old = done(5 * 3600)
        let recent = series(12, every: 300)
        #expect(stats([old] + recent, week: term).currentEpisode?.span == 3300)
        #expect(stats([old] + recent, week: term).alert == .none)
        // A running contraction doesn't count either.
        #expect(stats(series(12, every: 300, lastAgo: 360) + [running(30)], week: term).alert == .none)
    }

    @Test func endingTheEpisodeResetsTheSpan() {
        let pattern = series(14, every: 300)
        #expect(stats(pattern, week: term, endedAt: now.addingTimeInterval(-30)).alert == .none)
    }

    @Test func fiveOneOneWhenTheWeekIsUnknown() {
        #expect(stats(series(14, every: 300), week: nil).alert == .fiveOneOne)
    }

    @Test func fiveOneOneFromWeekThirtySevenExactly() {
        let pattern = series(14, every: 300)
        #expect(stats(pattern, week: GestationalWeek(weeks: 37, days: 0)).alert == .fiveOneOne)
        // Before 37 the same pattern is the preterm card.
        #expect(stats(pattern, week: GestationalWeek(weeks: 36, days: 6)).alert == .pretermRegular)
    }

    // MARK: - Preterm (before week 37)

    @Test func fourCompletedInTheHourBeforeWeekThirtySevenIsPreterm() {
        let four = series(4, every: 900)
        #expect(stats(four, week: GestationalWeek(weeks: 36, days: 6)).alert == .pretermRegular)
        #expect(stats(four, week: GestationalWeek(weeks: 37, days: 0)).alert == .none)
        #expect(stats(Array(four.dropFirst()), week: GestationalWeek(weeks: 36, days: 6)).alert == .none)
    }

    @Test func pretermAppliesBeforeWeekTwentyEightToo() {
        #expect(stats(series(4, every: 900), week: GestationalWeek(weeks: 20, days: 0)).alert == .pretermRegular)
        #expect(stats(series(4, every: 900), week: GestationalWeek(weeks: 0, days: 0)).alert == .pretermRegular)
    }

    @Test func pretermWindowEdges() {
        let week = GestationalWeek(weeks: 33, days: 0)
        // The fourth starts exactly 60 minutes ago: in.
        #expect(stats([done(3600), done(2400), done(1200), done(60)], week: week).alert == .pretermRegular)
        // One second earlier: out.
        #expect(stats([done(3601), done(2400), done(1200), done(60)], week: week).alert == .none)
    }

    @Test func aRunningContractionDoesNotCountForPreterm() {
        let week = GestationalWeek(weeks: 33, days: 0)
        #expect(stats([done(2400), done(1200), done(600), running(30)], week: week).alert == .none)
    }

    @Test func pretermIgnoresTheEpisodeEnd() {
        // Ending the episode never hides the urgent card: the hour still has 4.
        let week = GestationalWeek(weeks: 33, days: 0)
        #expect(stats(series(4, every: 600), week: week, endedAt: now).alert == .pretermRegular)
    }

    @Test func anUnknownWeekIsNeverPreterm() {
        #expect(stats(series(4, every: 900), week: nil).alert == .none)
    }

    @Test func noContractionsNoAlert() {
        #expect(stats([], week: term).alert == .none)
        #expect(stats([], week: GestationalWeek(weeks: 30, days: 0)).alert == .none)
    }

    // MARK: - Validation

    @Test func aRunningContractionOverFiveMinutesIsClosedAtFiveMinutes() throws {
        let over = stats([running(301)])
        let entry = try #require(over.currentEpisode?.entries.first)
        #expect(!entry.isRunning)
        #expect(entry.duration == 300)
        #expect(entry.record.endedAt == now.addingTimeInterval(-1))
        #expect(over.running == nil)
        // Exactly five minutes: still running.
        #expect(stats([running(300)]).running?.duration == 300)
    }

    @Test func aCompletedContractionOverFiveMinutesIsCappedAtFiveMinutes() {
        #expect(stats([done(1200, lasting: 600)]).currentEpisode?.entries.first?.duration == 300)
    }

    @Test func contractionsUnderThreeSecondsAreDropped() {
        #expect(stats([done(600, lasting: 2.9)]).episodes.isEmpty)
        #expect(stats([done(600, lasting: 3)]).episodes.count == 1)
    }

    @Test func futureStartsAndEndsBeforeStartsAreDropped() {
        let future = ContractionRecord(startedAt: now.addingTimeInterval(1))
        let backwards = ContractionRecord(startedAt: now.addingTimeInterval(-600), endedAt: now.addingTimeInterval(-700))
        #expect(stats([future, backwards]).episodes.isEmpty)
    }

    @Test func onlyTheNewestCanBeRunning() throws {
        let stray = running(1200)
        let result = stats([stray, done(600, lasting: 40)])
        let entries = try #require(result.currentEpisode?.entries)
        #expect(entries.allSatisfy { !$0.isRunning })
        #expect(entries.first?.duration == 300)
    }

    @Test func rulesHelpers() {
        let start = now.addingTimeInterval(-301)
        let record = ContractionRecord(startedAt: start)
        #expect(ContractionRules.isForgotten(record, now: now))
        #expect(!ContractionRules.isForgotten(ContractionRecord(startedAt: now.addingTimeInterval(-300)), now: now))
        #expect(ContractionRules.closingForgotten(record).endedAt == start.addingTimeInterval(300))
        #expect(ContractionRules.isMisTap(ContractionRecord(startedAt: now, endedAt: now.addingTimeInterval(2.9))))
        #expect(!ContractionRules.isMisTap(ContractionRecord(startedAt: now, endedAt: now.addingTimeInterval(3))))
    }

    @Test func validateRefusesASecondRunningOrAnEndBeforeTheStart() throws {
        let open = ContractionRecord(startedAt: now)
        #expect(throws: ContractionError.alreadyRunning) {
            try ContractionRules.validate(ContractionRecord(startedAt: now.addingTimeInterval(10)), existing: [open])
        }
        // Replacing the running one itself is fine.
        try ContractionRules.validate(ContractionRecord(id: open.id, startedAt: now, endedAt: now.addingTimeInterval(30)), existing: [open])
        try ContractionRules.validate(ContractionRecord(id: open.id, startedAt: now), existing: [open])
        #expect(throws: ContractionError.endBeforeStart) {
            try ContractionRules.validate(ContractionRecord(startedAt: now, endedAt: now.addingTimeInterval(-1)), existing: [])
        }
    }

    @Test func thresholdsMatchTheSpec() {
        #expect(ContractionRules.episodeGap == 2 * 3600)
        #expect(ContractionRules.window == 3600)
        #expect(ContractionRules.termWeek == 37)
        #expect(ContractionRules.pretermMinCount == 4)
        #expect(ContractionRules.fiveOneOneMaxAverageInterval == 5 * 60 + 30)
        #expect(ContractionRules.fiveOneOneMinAverageDuration == 45)
        #expect(ContractionRules.fiveOneOneMinCount == 6)
        #expect(ContractionRules.fiveOneOneMinSpan == 3600)
        #expect(ContractionRules.maxDuration == 300)
        #expect(ContractionRules.minDuration == 3)
    }

    // MARK: - Days and time zones

    @Test func anEpisodeAcrossMidnightStaysOneEpisodeOnItsStartDay() throws {
        let records = [
            ContractionRecord(startedAt: date("2026-10-09T23:50:00Z"), endedAt: date("2026-10-09T23:51:00Z")),
            ContractionRecord(startedAt: date("2026-10-09T23:56:00Z"), endedAt: date("2026-10-09T23:57:00Z")),
            ContractionRecord(startedAt: date("2026-10-10T00:02:00Z"), endedAt: date("2026-10-10T00:03:00Z")),
        ]
        let result = stats(records)
        #expect(result.episodes.count == 1)
        #expect(result.episodes.first?.entries.map(\.interval) == [nil, 360, 360])
        let days = result.pastEpisodesByDay(calendar: utcCalendar)
        #expect(days.map(\.day) == [CalendarDay(year: 2026, month: 10, day: 9)])
        #expect(days.first?.episodes.first?.count == 3)
    }

    @Test func aTimeZoneChangeMovesTheDayButNotTheNumbers() throws {
        let records = [
            ContractionRecord(startedAt: date("2026-10-09T23:50:00Z"), endedAt: date("2026-10-09T23:51:00Z")),
            ContractionRecord(startedAt: date("2026-10-09T23:56:00Z"), endedAt: date("2026-10-09T23:57:00Z")),
        ]
        var hanoi = Calendar(identifier: .gregorian)
        hanoi.timeZone = try #require(TimeZone(identifier: "Asia/Ho_Chi_Minh"))
        let result = stats(records)
        #expect(result.pastEpisodesByDay(calendar: utcCalendar).map(\.day) == [CalendarDay(year: 2026, month: 10, day: 9)])
        #expect(result.pastEpisodesByDay(calendar: hanoi).map(\.day) == [CalendarDay(year: 2026, month: 10, day: 10)])
        #expect(result.episodes.first?.averageInterval == 360)
        #expect(result.episodes.first?.averageDuration == 60)
    }

    @Test func historyGroupsPastEpisodesByDayNewestFirst() {
        let records = [
            ContractionRecord(startedAt: date("2026-10-08T09:00:00Z"), endedAt: date("2026-10-08T09:01:00Z")),
            ContractionRecord(startedAt: date("2026-10-09T06:00:00Z"), endedAt: date("2026-10-09T06:01:00Z")),
            ContractionRecord(startedAt: date("2026-10-09T15:00:00Z"), endedAt: date("2026-10-09T15:01:00Z")),
            ContractionRecord(startedAt: date("2026-10-10T11:55:00Z"), endedAt: date("2026-10-10T11:56:00Z")),
        ]
        let days = stats(records).pastEpisodesByDay(calendar: utcCalendar)
        #expect(days.map(\.day) == [CalendarDay(year: 2026, month: 10, day: 9), CalendarDay(year: 2026, month: 10, day: 8)])
        #expect(days.first?.episodes.map(\.startedAt) == [date("2026-10-09T15:00:00Z"), date("2026-10-09T06:00:00Z")])
    }
}
