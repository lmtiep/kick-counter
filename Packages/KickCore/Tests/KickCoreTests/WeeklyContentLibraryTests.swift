import Foundation
import Testing
@testable import KickCore

struct WeeklyContentLibraryTests {
    private func library() throws -> WeeklyContentLibrary {
        WeeklyContentLibrary(document: try fixtureContent())
    }

    @Test func decodesFromJSONData() throws {
        let data = try JSONEncoder().encode(try fixtureContent())
        let library = try WeeklyContentLibrary(data: data)
        #expect(library.document.weeks.map(\.week) == [7, 8, 9, 10, 11])
        #expect(library.sources == ["Fixture source A", "Fixture source B"])
        let week7 = try #require(library.content(forWeek: 7))
        #expect(week7.crlMm == 9.6)
        #expect(week7.weightG == nil)
        let week10 = try #require(library.content(forWeek: 10))
        #expect(week10.crlMm == 31.3)
        #expect(week10.weightG == 35)
        #expect(week10.weightP10G == 29)
        #expect(week10.weightP90G == 41)
    }

    @Test func weightBeyondWeek40ReusesTheEndOfTheStandard() throws {
        var week = try #require(try library().content(forWeek: 10))
        #expect(!week.weightBeyondStandard)
        week.week = 40
        #expect(!week.weightBeyondStandard)
        week.week = 41
        #expect(week.weightBeyondStandard)
        week.weightG = nil
        #expect(!week.weightBeyondStandard)
        #expect(WeekContent.weightStandardLastWeek == 40)
    }

    @Test func malformedJSONThrows() {
        #expect(throws: DecodingError.self) {
            try WeeklyContentLibrary(data: Data("{}".utf8))
        }
    }

    @Test func weekLookupClampsTo4Through42() {
        #expect(WeeklyContentLibrary.clampedWeek(1) == 4)
        #expect(WeeklyContentLibrary.clampedWeek(4) == 4)
        #expect(WeeklyContentLibrary.clampedWeek(24) == 24)
        #expect(WeeklyContentLibrary.clampedWeek(42) == 42)
        #expect(WeeklyContentLibrary.clampedWeek(44) == 42)
    }

    @Test func lookupReturnsThatWeek() throws {
        let library = try library()
        #expect(library.content(forWeek: 8)?.size.emoji == "🍒")
        #expect(library.content(forWeek: 5) == nil) // clamped to 5, absent from the fixture
    }

    @Test func displayHonoursReviewedFlag() throws {
        let library = try library()
        let week7 = try #require(library.content(forWeek: 7))
        let week8 = try #require(library.content(forWeek: 8))
        #expect(library.display(forWeek: 7, visibility: .reviewedOnly) == .content(week7, pendingReview: false))
        #expect(library.display(forWeek: 8, visibility: .reviewedOnly) == .underReview(week: 8))
        #expect(library.display(forWeek: 8, visibility: .all) == .content(week8, pendingReview: true))
        #expect(library.display(forWeek: 7, visibility: .all) == .content(week7, pendingReview: false))
    }

    @Test func showsWarningsIsFalseOnlyWhenUnderReview() throws {
        let library = try library()
        #expect(library.display(forWeek: 7, visibility: .reviewedOnly)?.showsWarnings == true)
        #expect(library.display(forWeek: 8, visibility: .reviewedOnly)?.showsWarnings == false)
        #expect(library.display(forWeek: 8, visibility: .all)?.showsWarnings == true)
    }

    @Test func upcomingMilestonesIncludeOnesUnderway() throws {
        let library = try library()
        #expect(library.upcomingMilestones(atWeek: 7).map(\.id) == ["m-early", "m-late"])
        #expect(library.upcomingMilestones(atWeek: 8).map(\.id) == ["m-early", "m-late"])
        #expect(library.upcomingMilestones(atWeek: 9).map(\.id) == ["m-late"])
        #expect(library.upcomingMilestones(atWeek: 15).isEmpty)
        #expect(library.upcomingMilestones(atWeek: 7, visibility: .reviewedOnly).map(\.id) == ["m-early"])
    }

    @Test func suggestedMilestonesExcludeAddedIDs() throws {
        let library = try library()
        #expect(library.suggestedMilestones(atWeek: 7, visibility: .all, excluding: []).map(\.id) == ["m-early", "m-late"])
        #expect(library.suggestedMilestones(atWeek: 7, visibility: .all, excluding: ["m-early"]).map(\.id) == ["m-late"])
        // Excluding an id that's already past (not in upcomingMilestones) is a no-op.
        #expect(library.suggestedMilestones(atWeek: 9, visibility: .all, excluding: ["m-early"]).map(\.id) == ["m-late"])
        #expect(library.suggestedMilestones(atWeek: 7, visibility: .all, excluding: ["m-early", "m-late"]).isEmpty)
    }

    @Test func suggestedMilestonesRespectVisibility() throws {
        let library = try library()
        #expect(library.suggestedMilestones(atWeek: 7, visibility: .reviewedOnly, excluding: []).map(\.id) == ["m-early"])
        #expect(library.suggestedMilestones(atWeek: 7, visibility: .reviewedOnly, excluding: ["m-early"]).isEmpty)
    }

    @Test func milestonesAreSortedByWeek() throws {
        var content = try fixtureContent()
        content.milestones.reverse()
        #expect(WeeklyContentLibrary(document: content).milestones.map(\.id) == ["m-early", "m-late"])
    }

    @Test func localizedAccessorsPickTheLanguage() throws {
        let library = try library()
        let week8 = try #require(library.content(forWeek: 8))
        #expect(week8.size.name(.vi) == "một quả anh đào")
        #expect(week8.size.name(.en) == "a cherry")
        #expect(week8.baby.items(.en) == ["Baby fact 8a.", "Baby fact 8b."])
        #expect(week8.warnings.items(.vi) == ["Gọi bác sĩ về 8."])
        #expect(library.milestones[0].title.text(.vi) == "Khám sớm")
    }

    @Test func contentLanguageFollowsTheFirstSupportedPreference() {
        #expect(ContentLanguage(preferredLanguages: ["vi-VN"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["vi"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["en-GB"]) == .en)
        #expect(ContentLanguage(preferredLanguages: ["fr-FR", "vi-VN"]) == .vi)
        #expect(ContentLanguage(preferredLanguages: ["fr-FR"]) == .en)
        #expect(ContentLanguage(preferredLanguages: []) == .en)
    }
}
