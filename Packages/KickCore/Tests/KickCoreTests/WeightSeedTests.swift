import Foundation
import Testing
@testable import KickCore

struct WeightSeedTests {
    @Test func samplesSitOnTheFirstDayOfTheirWeek() {
        // 38w0d on 2026-10-02: every sample is in the past.
        let due = date("2026-10-16T12:00:00Z")
        let now = date("2026-10-02T12:00:00Z")
        let entries = WeightSeed.entries(dueDate: due, today: now, calendar: utcCalendar)
        #expect(entries.map(\.kg) == [53.1, 54.6, 56.2, 58.0, 59.4, 60.9])
        let points = WeightStats.points(entries, profile: WeightSeed.profile, dueDate: due, calendar: utcCalendar)
        #expect(points.map(\.week.weeks) == [12, 16, 20, 24, 27, 30])
        #expect(points.allSatisfy { $0.week.days == 0 })
        #expect(points.last?.gainKg == 8.9)
        #expect(points.last?.status == .inRange)
        #expect(WeightSeed.profile.category == .normal)
    }

    @Test func futureWeeksAreLeftOut() {
        // 24w3d: weeks 27 and 30 have not come yet.
        let entries = WeightSeed.entries(dueDate: date("2027-01-19T12:00:00Z"), today: date("2026-10-02T12:00:00Z"), calendar: utcCalendar)
        #expect(entries.map(\.kg) == [53.1, 54.6, 56.2, 58.0])
    }

    @Test func seedWeightsNeedsUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedWeights"]).seedWeights)
        #expect(UITestLaunchOptions(arguments: ["-seedWeights"]).seedWeights == false)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting"]).seedWeights == false)
    }
}
