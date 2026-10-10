import Foundation
import Testing
@testable import KickCore

struct ContractionClockTests {
    @Test func formatsMinutesAndSeconds() {
        #expect(ContractionClock.text(0) == "0:00")
        #expect(ContractionClock.text(5) == "0:05")
        #expect(ContractionClock.text(59.6) == "1:00")
        #expect(ContractionClock.text(330) == "5:30")
        #expect(ContractionClock.text(3599) == "59:59")
    }

    @Test func formatsHoursFromOneHour() {
        #expect(ContractionClock.text(3600) == "1:00:00")
        #expect(ContractionClock.text(7265) == "2:01:05")
    }

    @Test func negativeIsZero() {
        #expect(ContractionClock.text(-4) == "0:00")
    }
}

struct ContractionSeedTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func fiveOneOneSeedRaisesTheFiveOneOneAlertAtTerm() {
        let records = ContractionSeed.fiveOneOne.records(now: now)
        let stats = ContractionStats(contractions: records, now: now, week: GestationalWeek(weeks: 38, days: 0))
        #expect(stats.alert == .fiveOneOne)
        #expect(stats.running == nil)
        #expect(stats.pastEpisodes.count == 1)
        // Still true a minute later (UI tests read the screen after launching).
        let later = ContractionStats(contractions: records, now: now.addingTimeInterval(60), week: GestationalWeek(weeks: 38, days: 0))
        #expect(later.alert == .fiveOneOne)
    }

    @Test func pretermSeedRaisesThePretermAlertBeforeWeek37() {
        let records = ContractionSeed.preterm.records(now: now)
        let stats = ContractionStats(contractions: records, now: now, week: GestationalWeek(weeks: 33, days: 0))
        #expect(stats.alert == .pretermRegular)
        #expect(stats.pastEpisodes.count == 1)
        let atTerm = ContractionStats(contractions: records, now: now, week: GestationalWeek(weeks: 38, days: 0))
        #expect(atTerm.alert == .none)
    }

    @Test func everySeedIsValidForTheStore() throws {
        for seed in ContractionSeed.allCases {
            var stored: [ContractionRecord] = []
            for record in seed.records(now: now) {
                try ContractionRules.validate(record, existing: stored)
                #expect(!ContractionRules.isMisTap(record))
                #expect(record.startedAt <= now)
                stored.append(record)
            }
        }
    }

    @Test func launchOptionParsesOnlyWhenUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedContractions", "511"]).seedContractions == .fiveOneOne)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedContractions", "preterm"]).seedContractions == .preterm)
        #expect(UITestLaunchOptions(arguments: ["-seedContractions", "511"]).seedContractions == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedContractions", "twins"]).seedContractions == nil)
    }
}
