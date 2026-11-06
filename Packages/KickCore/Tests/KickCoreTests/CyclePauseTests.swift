import Foundation
import Testing
@testable import KickCore

/// 1.1 item 4 (spec §4.4, §4.6): predictions pause after a pregnancy ends,
/// until she confirms the first period after it.
struct CyclePauseTests {
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private let end = PregnancyEndState(branch: .loss, endDate: date("2026-08-01T00:00:00Z"), calendar: utcCalendar)
    private let before = PeriodRecord(startDate: date("2026-01-10T00:00:00Z"), endDate: date("2026-01-14T00:00:00Z"))
    private let after = PeriodRecord(startDate: date("2026-09-03T00:00:00Z"), endDate: date("2026-09-07T00:00:00Z"))

    @Test func notPausedWithoutAnEndedPregnancy() {
        #expect(!CyclePause.isPaused(nil, periods: [before, after]))
    }

    @Test func pausedWithNoConfirmedPeriod() {
        #expect(CyclePause.isPaused(end, periods: []))
        #expect(CyclePause.isPaused(end, periods: [before, after]))
    }

    @Test func resumesAfterConfirm() {
        var state = end
        state.firstPeriodConfirmedID = after.id
        #expect(!CyclePause.isPaused(state, periods: [before, after]))
    }

    @Test func confirmedPeriodDeletedPausesAgain() {
        var state = end
        state.firstPeriodConfirmedID = after.id
        #expect(CyclePause.isPaused(state, periods: [before]))
    }

    @Test func preEndPeriodsExcludedFromForecast() {
        #expect(CyclePause.periodsForForecast([before, after], state: end) == [after])
        #expect(CyclePause.periodsForForecast([before, after], state: nil) == [before, after])
    }

    @Test func periodOnTheEndDayCounts() {
        let onEnd = PeriodRecord(startDate: day("2026-08-01"))
        #expect(CyclePause.periodsForForecast([onEnd], state: end) == [onEnd])
        #expect(CyclePause.periodNeedingConfirmation(end, periods: [onEnd], declined: []) == onEnd)
    }

    @Test func periodBeforeEndDateNeverAsked() {
        #expect(CyclePause.periodNeedingConfirmation(end, periods: [before], declined: []) == nil)
        #expect(CyclePause.periodNeedingConfirmation(end, periods: [before, after], declined: []) == after)
    }

    @Test func declinedPeriodNotAskedAgainAndStaysPaused() {
        #expect(CyclePause.periodNeedingConfirmation(end, periods: [before, after], declined: [after.id]) == nil)
        #expect(CyclePause.isPaused(end, periods: [before, after]))
        let later = PeriodRecord(startDate: day("2026-10-01"))
        #expect(CyclePause.periodNeedingConfirmation(end, periods: [before, after, later], declined: [after.id]) == later)
    }

    @Test func nothingAskedOnceResumedOrWithoutAnEnd() {
        var state = end
        state.firstPeriodConfirmedID = after.id
        #expect(CyclePause.periodNeedingConfirmation(state, periods: [after], declined: []) == nil)
        #expect(CyclePause.periodNeedingConfirmation(nil, periods: [after], declined: []) == nil)
    }

    /// Review fix 4: a first period logged with a date before the end day is asked about.
    @Test func aPeriodAfterTheRangeStartIsAsked() {
        let state = PregnancyEndState(
            branch: .birth, endDate: day("2026-08-01"), rangeStart: day("2025-11-01"), calendar: utcCalendar
        )
        let beforePregnancy = PeriodRecord(startDate: day("2025-10-05"))
        let earlyDated = PeriodRecord(startDate: day("2026-07-28"))
        #expect(CyclePause.periodNeedingConfirmation(state, periods: [beforePregnancy, earlyDated], declined: []) == earlyDated)
        #expect(CyclePause.periodNeedingConfirmation(state, periods: [beforePregnancy], declined: []) == nil)
    }

    /// Review fix 5: once confirmed, only that period and later ones count; declined bleeding does not.
    @Test func forecastStartsAtTheConfirmedPeriod() {
        let declined = PeriodRecord(startDate: day("2026-08-20"), endDate: day("2026-08-24"))
        let confirmed = PeriodRecord(startDate: day("2026-09-20"), endDate: day("2026-09-24"))
        let later = PeriodRecord(startDate: day("2026-10-18"), endDate: day("2026-10-22"))
        var state = end
        state.firstPeriodConfirmedID = confirmed.id
        #expect(CyclePause.periodsForForecast([before, declined, confirmed, later], state: state) == [confirmed, later])
    }
}
