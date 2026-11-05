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
}
