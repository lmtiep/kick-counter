import Foundation
import Testing
@testable import KickCore

struct ContentValidatorTests {
    private func issues(_ content: PregnancyContent) -> [ContentIssue] {
        ContentValidator.validate(content, requiredWeeks: 7...11)
    }

    @Test func fixtureIsValid() throws {
        #expect(issues(try fixtureContent()).isEmpty)
    }

    @Test func missingWeekIsReported() throws {
        var content = try fixtureContent()
        content.weeks.removeAll { $0.week == 8 }
        #expect(issues(content).contains(.missingWeek(8)))
    }

    @Test func duplicateAndUnexpectedWeeksAreReported() throws {
        var content = try fixtureContent()
        content.weeks.append(content.weeks[0])
        var extra = content.weeks[2]
        extra.week = 43
        content.weeks.append(extra)
        let found = issues(content)
        #expect(found.contains(.duplicateWeek(7)))
        #expect(found.contains(.unexpectedWeek(43)))
        #expect(found.contains(.weeksOutOfOrder))
    }

    @Test func tooFewItemsPerLanguageIsReported() throws {
        var content = try fixtureContent()
        content.weeks[1].tips.vi = ["Một ý."]
        let found = issues(content)
        #expect(found.contains(.tooFewItems(week: 8, section: "tips", language: .vi, minimum: 2)))
        #expect(found.contains(.translationCountMismatch(week: 8, section: "tips")))
    }

    @Test func everyWeekNeedsAWarning() throws {
        var content = try fixtureContent()
        content.weeks[0].warnings.en = []
        #expect(issues(content).contains(.tooFewItems(week: 7, section: "warnings", language: .en, minimum: 1)))
    }

    @Test func blankTextIsReported() throws {
        var content = try fixtureContent()
        content.weeks[0].baby.en[0] = "   "
        content.weeks[1].size.vi = ""
        let found = issues(content)
        #expect(found.contains(.blankText("week 7 baby.en")))
        #expect(found.contains(.blankText("week 8 size.vi")))
    }

    @Test func crownRumpLengthIsRequiredInWeeks7To13Only() throws {
        var content = try fixtureContent()
        content.weeks[1].crlMm = nil
        var week14 = content.weeks[4]
        week14.week = 14
        week14.crlMm = 80.1
        content.weeks.append(week14)
        let found = issues(content)
        #expect(found.contains(.missingMeasurement(week: 8, field: "crlMm")))
        #expect(found.contains(.unexpectedMeasurement(week: 14, field: "crlMm")))
        #expect(!found.contains(.missingMeasurement(week: 7, field: "crlMm")))
    }

    @Test func weightIsRequiredFromWeek10AndAbsentBefore() throws {
        var content = try fixtureContent()
        content.weeks[3].weightP90G = nil
        content.weeks[4].weightG = nil
        content.weeks[2].weightP10G = 20
        let found = issues(content)
        #expect(found.contains(.missingMeasurement(week: 10, field: "weightP90G")))
        #expect(found.contains(.missingMeasurement(week: 11, field: "weightG")))
        #expect(found.contains(.unexpectedMeasurement(week: 9, field: "weightP10G")))
        #expect(!found.contains(.missingMeasurement(week: 9, field: "weightG")))
    }

    @Test func weightPercentilesMustBeOrdered() throws {
        var content = try fixtureContent()
        content.weeks[3].weightP10G = 36 // above the 50th (35)
        content.weeks[4].weightP90G = 44 // below the 50th (45)
        let found = issues(content)
        #expect(found.contains(.invalidWeightRange(week: 10)))
        #expect(found.contains(.invalidWeightRange(week: 11)))
    }

    @Test func decreasingOrNonPositiveMeasurementsAreReported() throws {
        var content = try fixtureContent()
        content.weeks[4].weightG = 34
        content.weeks[4].weightP10G = 28
        content.weeks[1].crlMm = 0
        let found = issues(content)
        #expect(found.contains(.decreasingMeasurement(week: 11, field: "weightG")))
        #expect(found.contains(.decreasingMeasurement(week: 11, field: "weightP10G")))
        #expect(found.contains(.nonPositiveMeasurement(week: 8, field: "crlMm")))
    }

    @Test func crownRumpLengthMustStrictlyIncrease() throws {
        var content = try fixtureContent()
        content.weeks[2].crlMm = 16.0 // same as week 8
        #expect(issues(content).contains(.decreasingMeasurement(week: 9, field: "crlMm")))
    }

    @Test func equalWeightsInConsecutiveWeeksAreAllowed() throws {
        var content = try fixtureContent()
        content.weeks[4].weightG = 35
        content.weeks[4].weightP10G = 29
        content.weeks[4].weightP90G = 41
        #expect(issues(content).isEmpty)
    }

    @Test func invalidMilestoneRangesAreReported() throws {
        var content = try fixtureContent()
        content.milestones[0].fromWeek = 9
        content.milestones[0].toWeek = 8
        content.milestones[1].toWeek = 43
        let found = issues(content)
        #expect(found.contains(.invalidMilestoneRange(id: "m-early")))
        #expect(found.contains(.invalidMilestoneRange(id: "m-late")))
    }

    @Test func duplicateMilestoneIDsAreReported() throws {
        var content = try fixtureContent()
        content.milestones[1].id = "m-early"
        #expect(issues(content).contains(.duplicateMilestoneID("m-early")))
    }

    @Test func blankMilestoneTextIsReported() throws {
        var content = try fixtureContent()
        content.milestones[0].detail.vi = " "
        #expect(issues(content).contains(.blankText("milestone m-early detail.vi")))
    }

    @Test func versionAndSourcesAreChecked() throws {
        var content = try fixtureContent()
        content.version = 1 // the old lengthCm/weightG schema
        content.sources = []
        let found = issues(content)
        #expect(found.contains(.unsupportedVersion(1)))
        #expect(found.contains(.noSources))
    }

    // MARK: - Weight comparisons (phase 11, version 4)

    @Test func version3IsNoLongerSupported() throws {
        var content = try fixtureContent()
        content.version = 3 // before typicalGrams / produceSources
        #expect(issues(content).contains(.unsupportedVersion(3)))
    }

    @Test func comparisonConstants() {
        #expect(ContentValidator.supportedVersion == 4)
        #expect(ContentValidator.comparisonWeeks == 10...42)
        #expect(ContentValidator.comparisonTolerance == 0.25)
    }

    @Test func typicalWeightIsRequiredFromWeek10() throws {
        var content = try fixtureContent()
        content.weeks[3].size.typicalGrams = nil
        #expect(issues(content).contains(.missingTypicalWeight(week: 10)))
    }

    @Test func sourceKeyIsRequiredFromWeek10() throws {
        var content = try fixtureContent()
        content.weeks[4].size.sourceKey = nil
        #expect(issues(content).contains(.missingTypicalWeight(week: 11)))
    }

    @Test func typicalWeightBeforeWeek10IsUnexpected() throws {
        var content = try fixtureContent()
        content.weeks[1].size.typicalGrams = 16
        content.weeks[1].size.sourceKey = "usda-apricot"
        let found = issues(content)
        #expect(found.contains(.unexpectedMeasurement(week: 8, field: "typicalGrams")))
        #expect(found.contains(.unexpectedMeasurement(week: 8, field: "sourceKey")))
    }

    @Test func unknownProduceSourceIsReported() throws {
        var content = try fixtureContent()
        content.weeks[3].size.sourceKey = "usda-unknown"
        #expect(issues(content).contains(.unknownProduceSource(week: 10, key: "usda-unknown")))
    }

    @Test func blankProduceSourceFieldsAreReported() throws {
        var content = try fixtureContent()
        content.produceSources["usda-apricot"]?.title = " "
        content.produceSources["usda-apricot"]?.url = ""
        let found = issues(content)
        #expect(found.contains(.blankText("produceSources usda-apricot title")))
        #expect(found.contains(.blankText("produceSources usda-apricot url")))
    }

    /// Week 11's Hadlock weight is 45 g: 35 g is −22 % (inside ±25 %), 30 g is −33 %.
    @Test func comparisonMustBeWithinTolerance() throws {
        var content = try fixtureContent()
        content.weeks[4].size.typicalGrams = 35
        #expect(issues(content).isEmpty)
        content.weeks[4].size.typicalGrams = 30
        #expect(issues(content).contains(.comparisonOutOfTolerance(week: 11, typicalGrams: 30, referenceGrams: 45)))
        content.weeks[4].size.typicalGrams = 57 // +27 %
        #expect(issues(content).contains(.comparisonOutOfTolerance(week: 11, typicalGrams: 57, referenceGrams: 45)))
    }

    /// Weeks 41–42 carry week 40's weight in their own `weightG`, which is the reference.
    @Test func weeks41And42UseTheirOwnWeight() throws {
        var content = try fixtureContent()
        for number in [41, 42] {
            var week = content.weeks[4] // week 11: weightG 45, typicalGrams 38
            week.week = number
            week.crlMm = nil
            content.weeks.append(week)
        }
        let comparisons = { (issues: [ContentIssue]) in
            issues.filter { if case .comparisonOutOfTolerance = $0 { true } else { false } }
        }
        #expect(comparisons(ContentValidator.validate(content, requiredWeeks: 7...42)).isEmpty)
        content.weeks[6].size.typicalGrams = 30
        #expect(comparisons(ContentValidator.validate(content, requiredWeeks: 7...42))
            == [.comparisonOutOfTolerance(week: 42, typicalGrams: 30, referenceGrams: 45)])
    }
}
