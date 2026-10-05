import Foundation
import Testing
@testable import KickCore

struct SessionSeedTests {
    private let now = date("2026-10-02T12:00:00Z")

    @Test func fourWeeksOfEveningSessionsAndOneCancelled() throws {
        let sessions = SessionSeed.sessions(today: now, calendar: utcCalendar)
        #expect(sessions.count == 28)
        let completed = sessions.filter { $0.status == .completed }
        #expect(completed.count == 27)
        #expect(completed.allSatisfy { $0.count == 10 && $0.endedAt == $0.kicks.last })
        let cancelled = try #require(sessions.first { $0.status == .cancelled })
        #expect(cancelled.startedAt == date("2026-09-30T14:10:00Z"))
        #expect(cancelled.count == 4)
        #expect(sessions.first?.startedAt == date("2026-09-05T20:40:00Z"))
        #expect(sessions.first?.duration == TimeInterval(25 * 60))
        #expect(sessions.allSatisfy { !utcCalendar.isDate($0.startedAt, inSameDayAs: now) })
        #expect(zip(sessions, sessions.dropFirst()).allSatisfy { $0.startedAt < $1.startedAt })
    }

    @Test func matchesTheDesignsLastSevenDays() {
        let sessions = SessionSeed.sessions(today: now, calendar: utcCalendar)
        let bars = HistoryStats.daily(sessions, endingAt: now, calendar: utcCalendar)
        #expect(bars.map(\.minutes) == [19, 31, 16, 27, 21, 18, nil])
        #expect(HistoryStats.averageMinutes(sessions, endingAt: now, days: 7, calendar: utcCalendar) == 22)
    }

    @Test func weeksGetQuicker() throws {
        let sessions = SessionSeed.sessions(today: now, calendar: utcCalendar)
        let weeks = HistoryStats.weekly(sessions, endingAt: now, calendar: utcCalendar).compactMap(\.minutes)
        #expect(weeks.count == 4)
        #expect(abs(weeks[0] - 198.0 / 7) < 1e-9)
        #expect(abs(weeks[1] - 177.0 / 7) < 1e-9)
        #expect(abs(weeks[2] - 156.0 / 7) < 1e-9)
        #expect(weeks[3] == 22)
    }
}
