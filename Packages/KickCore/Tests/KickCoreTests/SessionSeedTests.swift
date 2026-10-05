import Foundation
import Testing
@testable import KickCore

struct SessionSeedTests {
    private let now = date("2026-10-02T12:00:00Z")

    @Test func fourWeeksOfEveningSessionsAndOneCancelled() throws {
        let sessions = SessionSeed.sessions(today: now, calendar: utcCalendar)
        #expect(sessions.count == 29)
        let completed = sessions.filter { $0.status == .completed }
        #expect(completed.count == 28)
        #expect(completed.allSatisfy { $0.count == 10 && $0.endedAt == $0.kicks.last })
        let cancelled = try #require(sessions.first { $0.status == .cancelled })
        #expect(cancelled.startedAt == date("2026-09-30T14:10:00Z"))
        #expect(cancelled.count == 4)
        #expect(sessions.first?.startedAt == date("2026-09-05T20:40:00Z"))
        #expect(sessions.first?.duration == TimeInterval(25 * 60))
        #expect(sessions.allSatisfy { !utcCalendar.isDate($0.startedAt, inSameDayAs: now) })
        let long = try #require(sessions.first { $0.duration == TimeInterval(SessionSeed.longMinutes * 60) })
        #expect(long.startedAt == date("2026-09-28T21:10:00Z"))
        #expect(long.status == SessionStatus.completed)
        #expect(!long.exceededThreshold)
        #expect(zip(sessions, sessions.dropFirst()).allSatisfy { $0.startedAt < $1.startedAt })
    }

    /// The design's last week (19/31/16/27/21/18′), except that a later 75′
    /// session on the 16′ day shows a bar cut at 60′.
    @Test func matchesTheDesignsLastSevenDaysWithOneBarOverTheTop() throws {
        let sessions = SessionSeed.sessions(today: now, calendar: utcCalendar)
        let bars = HistoryStats.daily(sessions, endingAt: now, calendar: utcCalendar)
        #expect(bars.map(\.minutes) == [19, 31, 75, 27, 21, 18, nil])
        #expect(bars.compactMap(\.minutes).contains { $0 > HistoryStats.chartMaxMinutes })
        let average = try #require(HistoryStats.averageMinutes(sessions, endingAt: now, days: 7, calendar: utcCalendar))
        #expect(abs(average - 207.0 / 7) < 1e-9) // "30 min"
        let month = try #require(HistoryStats.averageMinutes(sessions, endingAt: now, days: 28, calendar: utcCalendar))
        #expect(abs(month - 738.0 / 28) < 1e-9) // "26 min"
    }

    @Test func weeksGetQuicker() throws {
        let sessions = SessionSeed.sessions(today: now, calendar: utcCalendar)
        let weeks = HistoryStats.weekly(sessions, endingAt: now, calendar: utcCalendar).compactMap(\.minutes)
        #expect(weeks.count == 4)
        #expect(abs(weeks[0] - 198.0 / 7) < 1e-9)
        #expect(abs(weeks[1] - 177.0 / 7) < 1e-9)
        #expect(abs(weeks[2] - 156.0 / 7) < 1e-9)
        #expect(abs(weeks[3] - 207.0 / 7) < 1e-9)
    }
}
