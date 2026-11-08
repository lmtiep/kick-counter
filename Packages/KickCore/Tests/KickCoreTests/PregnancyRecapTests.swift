import Foundation
import Testing
@testable import KickCore

/// Birth celebration spec §3: the recap behind the celebration pages.
struct PregnancyRecapTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00+07:00") }

    private func content(
        branch: PregnancyEndBranch = .birth, start: Date? = nil, week: Int? = nil,
        kickDays: [KickDay] = [], episodes: [ContractionEpisodeSummary] = [],
        appointments: [MemoryAppointment] = [], weights: [MemoryWeight] = []
    ) -> PregnancyMemoryContent {
        PregnancyMemoryContent(
            branch: branch, start: start, end: day("2026-11-08"), furthestWeek: week,
            kickDays: kickDays, contractionEpisodes: episodes, appointments: appointments, weights: weights
        )
    }

    private func recap(_ content: PregnancyMemoryContent) -> PregnancyRecap {
        PregnancyRecap.make(content: content, calendar: calendar)
    }

    @Test func emptyContentKeepsOnlyCelebrationAndThanks() {
        let result = recap(content())
        #expect(result.pages == [.celebration, .thanks])
        #expect(result.weeks == nil && result.days == nil && result.artworkWeek == nil)
        #expect(result.journeyWeeks.isEmpty)
        #expect(result.birthDate == day("2026-11-08"))
    }

    @Test func fullContentHasEveryPageInOrder() {
        let result = recap(content(
            start: day("2026-02-01"), week: 40,
            kickDays: [KickDay(day: day("2026-09-01"), sessionCount: 1, totalKicks: 10, bestDuration: nil)],
            episodes: [ContractionEpisodeSummary(start: day("2026-11-07"), count: 3, averageDuration: nil, averageInterval: nil)],
            appointments: [MemoryAppointment(date: day("2026-08-01"), title: "", note: "")],
            weights: [MemoryWeight(day: day("2026-03-01"), kg: 50), MemoryWeight(day: day("2026-11-01"), kg: 61.5)]
        ))
        #expect(result.pages == [.celebration, .journey, .kicks, .contractions, .appointments, .weight, .thanks])
        #expect(result.weeks == 40)
    }

    @Test func sumsKicksSessionsContractionsAndAppointments() {
        let result = recap(content(
            kickDays: [
                KickDay(day: day("2026-09-01"), sessionCount: 2, totalKicks: 20, bestDuration: nil),
                KickDay(day: day("2026-09-02"), sessionCount: 3, totalKicks: 31, bestDuration: 600),
            ],
            episodes: [
                ContractionEpisodeSummary(start: day("2026-11-06"), count: 4, averageDuration: nil, averageInterval: nil),
                ContractionEpisodeSummary(start: day("2026-11-07"), count: 5, averageDuration: nil, averageInterval: nil),
            ],
            appointments: [
                MemoryAppointment(date: day("2026-08-01"), title: "a", note: ""),
                MemoryAppointment(date: day("2026-09-01"), title: "b", note: ""),
            ]
        ))
        #expect(result.totalKicks == 51)
        #expect(result.kickSessions == 5)
        #expect(result.contractions == 9)
        #expect(result.appointments == 2)
    }

    @Test func weightChangeNeedsTwoEntries() {
        let one = recap(content(weights: [MemoryWeight(day: day("2026-03-01"), kg: 50)]))
        #expect(one.weightChangeKg == nil)
        #expect(one.pages.contains(.weight) == false)

        let two = recap(content(weights: [MemoryWeight(day: day("2026-03-01"), kg: 50), MemoryWeight(day: day("2026-11-01"), kg: 61.5)]))
        #expect(two.weightChangeKg == 11.5)
        #expect(two.pages.contains(.weight))
    }

    @Test func daysComeFromStartAndAreNilWithoutIt() {
        #expect(recap(content(week: 40)).days == nil)
        let result = recap(content(start: day("2026-02-01"), week: 40))
        #expect(result.days == 280)
    }

    @Test func journeyWeeksSampleAtMostEightAscendingUnique() {
        for week in 4...42 {
            let weeks = recap(content(week: week)).journeyWeeks
            #expect(weeks.first == 4, "week \(week)")
            #expect(weeks.last == week, "week \(week)")
            #expect(weeks.count <= 8, "week \(week)")
            #expect(weeks == Array(Set(weeks)).sorted(), "week \(week)")
        }
        #expect(recap(content(week: 6)).journeyWeeks == [4, 5, 6])
        #expect(recap(content(week: 11)).journeyWeeks.count == 8)
    }

    @Test func artworkWeekIsClampedTo4Through42() {
        #expect(recap(content(week: 2)).artworkWeek == 4)
        #expect(recap(content(week: 2)).journeyWeeks == [4])
        #expect(recap(content(week: 0)).artworkWeek == 4)
        #expect(recap(content(week: 42)).artworkWeek == 42)
        #expect(recap(content(week: 99)).artworkWeek == 42)
    }

    @Test func onlyABirthEndsWithARecap() {
        #expect(PregnancyRecap.forEnding(content: content(branch: .loss), keptAsMemory: true, calendar: calendar) == nil)
        let birth = PregnancyRecap.forEnding(content: content(branch: .birth), keptAsMemory: true, calendar: calendar)
        #expect(birth != nil)
        #expect(birth?.keptAsMemory == true)
    }

    /// Review fix 1: a birth with no memory and the data kept has no archive step, yet is celebrated.
    @Test func everyBirthKeepChoiceBuildsContentForARecapAndALossOnlyForAMemory() {
        let keeps: [PregnancyEndingKeep] = [.memory(title: "Bông"), .noMemoryKeepData, .noMemoryDeleteData]
        for keep in keeps {
            #expect(PregnancyEndingPlan.hasRecap(branch: .birth), "\(keep)")
            #expect(PregnancyEndingPlan.buildsContent(branch: .birth, keep: keep), "birth \(keep)")
        }
        #expect(PregnancyEndingPlan.hasRecap(branch: .loss) == false)
        #expect(PregnancyEndingPlan.buildsContent(branch: .loss, keep: .memory(title: "")))
        #expect(PregnancyEndingPlan.buildsContent(branch: .loss, keep: .noMemoryKeepData) == false)
        #expect(PregnancyEndingPlan.buildsContent(branch: .loss, keep: .noMemoryDeleteData) == false)
        // The archive step alone cannot be relied on for this.
        #expect(PregnancyEndingPlan.steps(keep: .noMemoryKeepData).contains(.archive) == false)
    }
}
