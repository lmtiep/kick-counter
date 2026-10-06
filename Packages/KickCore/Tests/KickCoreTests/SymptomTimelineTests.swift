import Foundation
import Testing
@testable import KickCore

struct SymptomTimelineTests {
    /// 24w3d on 2026-10-02; first day of the last period 2026-04-14.
    let dueDate = date("2027-01-19T12:00:00Z")
    let now = date("2026-10-02T12:00:00Z")

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func pregnancyLogsAreGroupedByWeekNewestFirst() {
        let today = CycleLogRecord(day: day("2026-10-02"), symptoms: [.contractions])
        let monday = CycleLogRecord(day: day("2026-09-29"), moods: [.tired])
        let week23 = CycleLogRecord(day: day("2026-09-27"), note: "Slept badly")
        let sections = SymptomTimeline.sections([monday, week23, today], dueDate: dueDate, now: now, calendar: utcCalendar)
        #expect(sections.map(\.week) == [24, 23])
        #expect(sections.first?.logs == [today, monday])
        #expect(sections.last?.logs == [week23])
    }

    @Test func cycleOnlyLogsAndDaysOutsideThePregnancyAreLeftOut() {
        let ovulation = CycleLogRecord(day: day("2026-09-30"), lh: .positive, symptoms: [.cramps])
        let beforeLMP = CycleLogRecord(day: day("2026-04-13"), moods: [.happy])
        let future = CycleLogRecord(day: day("2026-10-03"), moods: [.happy])
        #expect(SymptomTimeline.sections([ovulation, beforeLMP, future], dueDate: dueDate, now: now, calendar: utcCalendar).isEmpty)
    }
}
