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

    @Test func emptyContentKeepsOnlyCelebrationThanksAndSummary() {
        let result = recap(content())
        #expect(result.pages == [.celebration, .thanks, .summary])
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
        #expect(result.pages == [.celebration, .journey, .kicks, .contractions, .appointments, .weight, .thanks, .summary])
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

    /// Celebration art spec §1: the handoff's milestones below the final week, then the final week.
    @Test func journeyWeeksAreTheMilestonesBelowTheFinalWeek() {
        #expect(PregnancyRecap.milestones(to: 40) == [8, 16, 24, 32, 40])
        #expect(PregnancyRecap.milestones(to: 38) == [8, 16, 24, 32, 38])
        #expect(PregnancyRecap.milestones(to: 30) == [8, 16, 24, 30])
        #expect(PregnancyRecap.milestones(to: 12) == [8, 12])
        #expect(PregnancyRecap.milestones(to: 8) == [8])
        #expect(PregnancyRecap.milestones(to: 4) == [4])
        #expect(recap(content(week: 38)).journeyWeeks == [8, 16, 24, 32, 38])
        #expect(recap(content()).journeyWeeks.isEmpty)
    }

    @Test func milestoneArtIsTheNearestHandoffImageAndTheFinalIsTheNewborn() {
        #expect(PregnancyRecap.milestoneArt(8, isFinal: false) == 8)
        #expect(PregnancyRecap.milestoneArt(30, isFinal: false) == 32)
        #expect(PregnancyRecap.milestoneArt(12, isFinal: false) == 8, "a tie takes the earlier image")
        #expect(PregnancyRecap.milestoneArt(4, isFinal: true) == 40)
        #expect(PregnancyRecap.milestoneArt(38, isFinal: true) == 40)
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
