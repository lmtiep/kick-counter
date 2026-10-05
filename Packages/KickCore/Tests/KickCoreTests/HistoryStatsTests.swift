import Foundation
import Testing
@testable import KickCore

struct HistoryStatsTests {
    private let now = date("2026-10-02T21:30:00Z")

    private func session(_ iso: String, minutes: Double, status: SessionStatus = .completed) -> SessionState {
        let start = date(iso)
        return SessionState(startedAt: start, status: status, endedAt: start.addingTimeInterval(minutes * 60))
    }

    @Test func dailyHasSevenBarsWithTheLatestCompletedSessionOfEachDay() {
        let bars = HistoryStats.daily([
            session("2026-10-02T08:00:00Z", minutes: 20),
            session("2026-10-02T19:00:00Z", minutes: 12),
            session("2026-09-30T20:00:00Z", minutes: 25),
            session("2026-09-29T20:00:00Z", minutes: 40, status: .cancelled),
            session("2026-09-20T20:00:00Z", minutes: 10),
        ], endingAt: now, calendar: utcCalendar)
        #expect(bars.count == 7)
        #expect(bars.first?.start == date("2026-09-26T00:00:00Z"))
        #expect(bars.map(\.minutes) == [nil, nil, nil, nil, 25, nil, 12])
        #expect(bars.map(\.isCurrent) == [false, false, false, false, false, false, true])
    }

    @Test func averageUsesEveryCompletedSessionInTheWindow() {
        let sessions = [
            session("2026-10-02T08:00:00Z", minutes: 20),
            session("2026-10-02T19:00:00Z", minutes: 12),
            session("2026-09-26T20:00:00Z", minutes: 25),
            session("2026-09-25T20:00:00Z", minutes: 90), // 8 days ago: outside 7 days
            session("2026-09-30T20:00:00Z", minutes: 50, status: .cancelled),
        ]
        #expect(HistoryStats.averageMinutes(sessions, endingAt: now, days: 7, calendar: utcCalendar) == 19)
        #expect(HistoryStats.averageMinutes(sessions, endingAt: now, days: 28, calendar: utcCalendar) == 36.75)
        #expect(HistoryStats.averageMinutes([], endingAt: now, days: 7, calendar: utcCalendar) == nil)
    }

    @Test func latestCompletedIsTodaysLastFinishedSession() {
        let sessions = [
            session("2026-10-02T08:00:00Z", minutes: 20),
            session("2026-10-02T19:00:00Z", minutes: 12),
            session("2026-10-02T20:30:00Z", minutes: 5, status: .cancelled),
            session("2026-10-01T22:00:00Z", minutes: 15),
        ]
        #expect(HistoryStats.latestCompleted(sessions, on: now, calendar: utcCalendar)?.startedAt == date("2026-10-02T19:00:00Z"))
        #expect(HistoryStats.latestCompleted(Array(sessions.suffix(1)), on: now, calendar: utcCalendar) == nil)
    }

    @Test func barsAreCutAtSixtyMinutes() {
        #expect(HistoryStats.barFraction(minutes: 30) == 0.5)
        #expect(HistoryStats.barFraction(minutes: 75) == 1)
        #expect(HistoryStats.barFraction(minutes: -1) == 0)
        #expect(HistoryStats.referenceMinutes == 30)
    }

    @Test func weeklyAveragesFourSevenDayBlocksEndingToday() {
        let bars = HistoryStats.weekly([
            session("2026-10-02T08:00:00Z", minutes: 20),
            session("2026-09-26T08:00:00Z", minutes: 10), // first day of this week's block
            session("2026-09-25T08:00:00Z", minutes: 30), // last day of the previous block
            session("2026-09-19T08:00:00Z", minutes: 40),
            session("2026-09-05T08:00:00Z", minutes: 50), // first day of the oldest block
            session("2026-09-04T08:00:00Z", minutes: 99), // too old
        ], endingAt: now, calendar: utcCalendar)
        #expect(bars.map(\.start) == ["2026-09-05", "2026-09-12", "2026-09-19", "2026-09-26"].map { date("\($0)T00:00:00Z") })
        #expect(bars.map(\.minutes) == [50, nil, 35, 15])
        #expect(bars.map(\.isCurrent) == [false, false, false, true])
    }
}
