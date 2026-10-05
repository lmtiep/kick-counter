import Foundation
import Testing
@testable import KickCore

struct PregnancyProgressTests {
    private let now = date("2026-10-02T12:00:00Z")

    @Test func midPregnancy() throws {
        // Due 2027-01-19: day 171 = 24w3d, 109 days to go.
        let timeline = try #require(PregnancyTimeline(dueDate: date("2027-01-19T12:00:00Z"), now: now, calendar: utcCalendar))
        let progress = PregnancyProgress(timeline: timeline)
        #expect(progress.fraction == 171.0 / 280)
        #expect(progress.week == GestationalWeek(weeks: 24, days: 3))
        #expect(progress.trimester == .second)
        #expect(progress.daysRemaining == 109)
        #expect(progress.daysPastDue == 0)
    }

    @Test func pastTheDueDateTheBarIsFull() throws {
        let timeline = try #require(PregnancyTimeline(dueDate: date("2026-09-25T12:00:00Z"), now: now, calendar: utcCalendar))
        let progress = PregnancyProgress(timeline: timeline)
        #expect(progress.fraction == 1)
        #expect(progress.daysRemaining == 0)
        #expect(progress.daysPastDue == 7)
        #expect(progress.trimester == .third)
    }

    @Test func trimesterDividersMatchTheDesign() {
        #expect(PregnancyProgress.trimesterMarks == [0.325, 0.675])
    }
}
