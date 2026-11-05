import Foundation
import Testing
@testable import KickCore

struct WidgetTimelinePlanTests {
    let calendar = utcCalendar
    let now = date("2026-10-02T12:00:00Z")

    private var pregnant: WidgetInput {
        WidgetInput(mode: .pregnant, hasCompletedOnboarding: true, dueDate: date("2026-12-11T00:00:00Z"), kicksToday: 6)
    }

    private func kicks(_ entry: WidgetTimelineEntry) -> WidgetSnapshot.KickLine? {
        guard case .pregnancy(let content) = entry.snapshot.content else { return nil }
        return content.kicks
    }

    @Test func goodReadGivesOneEntryPerMidnightAndReloadsAfterTheLast() {
        let plan = WidgetTimelinePlan.make(read: .input(pregnant), lastGood: nil, now: now, calendar: calendar)
        #expect(plan.entries.map(\.date) == [now, date("2026-10-03T00:00:00Z"), date("2026-10-04T00:00:00Z")])
        #expect(plan.reloadAfter == date("2026-10-05T00:00:00Z"))
        #expect(plan.remembered == pregnant)
    }

    @Test func tomorrowsEntriesDoNotCarryTodaysKickCount() {
        let plan = WidgetTimelinePlan.make(read: .input(pregnant), lastGood: nil, now: now, calendar: calendar)
        #expect(plan.entries.map(kicks) == [.counted(6), .notCounted, .notCounted])
    }

    @Test func failedReadWithoutHistoryIsNeutralAndRetriesInFifteenMinutes() {
        let plan = WidgetTimelinePlan.make(read: .unavailable, lastGood: nil, now: now, calendar: calendar)
        #expect(plan.entries.count == 1)
        #expect(plan.entries[0].snapshot.content == .needsSetup)
        #expect(plan.reloadAfter == now.addingTimeInterval(15 * 60))
        #expect(plan.remembered == nil)
    }

    @Test func failedReadKeepsTheLastGoodSnapshotAndRetriesSoon() {
        let plan = WidgetTimelinePlan.make(read: .unavailable, lastGood: pregnant, now: now, calendar: calendar)
        #expect(plan.entries.count == 1)
        #expect(kicks(plan.entries[0]) == .counted(6))
        #expect(plan.reloadAfter == now.addingTimeInterval(15 * 60))
        #expect(plan.remembered == nil)
    }
}
