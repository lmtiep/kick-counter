import Foundation
import Testing
@testable import KickCore

/// Rules every shipped `pregnancy-content.json` must meet (see plan Task 5).
struct BundledContentTests {
    static let requiredMilestones: [String: ClosedRange<Int>] = [
        "confirm-pregnancy": 6...8,
        "nt-scan": 11...14,
        "triple-test": 15...18,
        "anomaly-scan": 18...22,
        "gdm-screening": 24...28,
        "tetanus-pertussis": 27...36,
        "growth-scan": 30...32,
        "gbs-test": 35...37,
        "weekly-checks": 37...40,
        "post-dates": 40...42,
    ]
    static let careWordsEN = ["doctor", "midwife", "maternity", "hospital", "emergency"]
    static let careWordsVI = ["bác sĩ", "cơ sở y tế", "bệnh viện", "cấp cứu", "115"]
    /// Hadlock-anchored sanity ranges for the 50th-percentile weight (g).
    static let typicalWeights: [Int: ClosedRange<Int>] = [
        12: 48...68,
        20: 300...360,
        28: 1004...1416,
        40: 3400...3800,
    ]
    /// Sanity ranges for crown–rump length (mm).
    static let typicalCRL: [Int: ClosedRange<Double>] = [
        8: 14...18,
        12: 50...57,
    ]
    /// Hadlock, Harrist & Martinez-Poyer, Radiology 1991;181:129–133, Table 1:
    /// week → (10th, 50th, 90th) estimated fetal weight in grams.
    static let hadlock1991: [Int: (p10: Int, p50: Int, p90: Int)] = [
        10: (29, 35, 41), 11: (37, 45, 53), 12: (48, 58, 68), 13: (61, 73, 85),
        14: (77, 93, 109), 15: (97, 117, 137), 16: (121, 146, 171), 17: (150, 181, 212),
        18: (185, 223, 261), 19: (227, 273, 319), 20: (275, 331, 387), 21: (331, 399, 467),
        22: (398, 478, 559), 23: (471, 568, 665), 24: (556, 670, 784), 25: (652, 785, 918),
        26: (758, 913, 1068), 27: (876, 1055, 1234), 28: (1004, 1210, 1416), 29: (1145, 1379, 1613),
        30: (1294, 1559, 1824), 31: (1453, 1751, 2049), 32: (1621, 1953, 2285), 33: (1794, 2162, 2530),
        34: (1973, 2377, 2781), 35: (2154, 2595, 3036), 36: (2335, 2813, 3291), 37: (2513, 3028, 3543),
        38: (2686, 3236, 3786), 39: (2851, 3435, 4019), 40: (3004, 3619, 4234),
    ]
    /// Crown–rump length (mm) at week+0 from the Hadlock 1992 equation (research doc §2.2).
    static let hadlock1992CRL: [Int: Double] = [
        7: 9.6, 8: 16.0, 9: 23.1, 10: 31.3, 11: 41.2, 12: 53.5, 13: 67.2,
    ]

    let library: WeeklyContentLibrary

    init() throws {
        library = try WeeklyContentLibrary.bundled()
    }

    @Test func bundledContentPassesValidation() {
        let issues = ContentValidator.validate(library.document)
        #expect(issues.isEmpty, "\(issues)")
    }

    @Test func coversEveryWeekFrom4To42() {
        #expect(library.document.weeks.map(\.week) == Array(4...42))
    }

    @Test func lookupClampsToTheContentRange() {
        #expect(library.content(forWeek: 1)?.week == 4)
        #expect(library.content(forWeek: 24)?.week == 24)
        #expect(library.content(forWeek: 44)?.week == 42)
    }

    @Test func milestonesMatchTheSpecSchedule() {
        let actual = Dictionary(library.milestones.map { ($0.id, $0.fromWeek...$0.toWeek) }, uniquingKeysWith: { first, _ in first })
        #expect(actual == Self.requiredMilestones)
        #expect(library.milestones.count == Self.requiredMilestones.count)
    }

    @Test func everyWarningPointsToCare() {
        for week in library.document.weeks {
            for item in week.warnings.en {
                #expect(Self.careWordsEN.contains { item.localizedCaseInsensitiveContains($0) }, "week \(week.week): \(item)")
            }
            for item in week.warnings.vi {
                #expect(Self.careWordsVI.contains { item.localizedCaseInsensitiveContains($0) }, "week \(week.week): \(item)")
            }
        }
    }

    /// Core danger signs must be repeated every week of their stage, not only in some weeks.
    @Test func coreDangerSignsAppearEveryWeekOfTheirStage() {
        func mentions(_ items: [String], _ keywords: [String]) -> Bool {
            items.contains { item in keywords.contains { item.localizedCaseInsensitiveContains($0) } }
        }
        for week in library.document.weeks {
            let en = week.warnings.en
            let vi = week.warnings.vi
            #expect(mentions(en, ["fever"]), "week \(week.week): fever")
            #expect(mentions(vi, ["sốt"]), "week \(week.week): sốt")
            if week.week <= 19 {
                #expect(mentions(en, ["bleeding"]), "week \(week.week): bleeding")
                #expect(mentions(en, ["faint"]), "week \(week.week): faint")
                #expect(mentions(en, ["severe", "one-sided"]), "week \(week.week): severe or one-sided pain")
            }
            if week.week <= 12 {
                #expect(mentions(en, ["shoulder"]), "week \(week.week): shoulder-tip pain")
            }
            if week.week >= 20 {
                #expect(mentions(en, ["bleeding"]), "week \(week.week): bleeding")
                #expect(mentions(vi, ["ra máu"]), "week \(week.week): ra máu")
                #expect(mentions(en, ["headache"]), "week \(week.week): headache")
                #expect(mentions(en, ["vision"]), "week \(week.week): vision")
                #expect(mentions(en, ["leaking", "waters"]), "week \(week.week): leaking fluid")
                #expect(mentions(en, ["ambulance"]), "week \(week.week): ambulance")
                #expect(mentions(vi, ["115"]), "week \(week.week): 115")
            }
            if week.week >= 24 {
                #expect(mentions(en, ["moving", "movements"]), "week \(week.week): movements")
            }
        }
        let week24 = library.content(forWeek: 24)?.warnings.en ?? []
        #expect(mentions(week24, ["not felt your baby move"]), "week 24: not felt your baby move")
    }

    @Test func vietnameseTextHasDiacritics() {
        var texts: [String] = []
        for week in library.document.weeks {
            texts.append(week.size.vi)
            texts += week.baby.vi + week.mom.vi + week.tips.vi + week.warnings.vi
        }
        for milestone in library.milestones {
            texts += [milestone.title.vi, milestone.detail.vi]
        }
        let unaccented = texts.filter { !$0.unicodeScalars.contains { $0.value > 127 } }
        #expect(unaccented.isEmpty, "\(unaccented)")
    }

    /// Repeats are allowed when weights are close, but never three weeks running (phase 11 spec §3.3).
    @Test func noComparisonRunsLongerThanTwoWeeks() {
        let names = library.document.weeks.map(\.size.en)
        for index in names.indices.dropFirst(2) where names[index] == names[index - 1] && names[index] == names[index - 2] {
            Issue.record("weeks \(library.document.weeks[index - 2].week)–\(library.document.weeks[index].week): \(names[index])")
        }
    }

    /// Phase 11 spec §3.2: the produce's typical weight is within ±25 % of the week's Hadlock weight.
    @Test func everyComparisonFromWeek10IsWithinTolerance() throws {
        for week in library.document.weeks where week.week >= 10 {
            let typical = try #require(week.size.typicalGrams, "week \(week.week)")
            let reference = try #require(week.weightG, "week \(week.week)")
            let deviation = abs(Double(typical - reference)) / Double(reference)
            #expect(deviation <= ContentValidator.comparisonTolerance, "week \(week.week): \(typical) g vs \(reference) g")
        }
    }

    @Test func everyComparisonCitesASource() throws {
        let sources = library.document.produceSources
        #expect(!sources.isEmpty)
        for week in library.document.weeks where week.week >= 10 {
            let key = try #require(week.size.sourceKey, "week \(week.week)")
            #expect(sources[key] != nil, "week \(week.week): \(key)")
        }
        for (key, source) in sources {
            #expect(!ContentValidator.isBlank(source.title), "\(key)")
            #expect(!ContentValidator.isBlank(source.note), "\(key)")
            #expect(URL(string: source.url)?.scheme == "https", "\(key): \(source.url)")
        }
        #expect(library.document.weeks.filter { $0.week < 10 }.allSatisfy { $0.size.typicalGrams == nil && $0.size.sourceKey == nil })
    }

    private struct ResearchTable: Decodable {
        struct Row: Decodable {
            var week: Int
            var emoji: String
            var en: String
            var vi: String
            var typicalGrams: Int
            var sourceKey: String
        }
        var produceSources: [String: ProduceSource]
        var weeks: [Row]
    }

    /// The research JSON's emoji, except the plan's overrides: 🍋‍🟩 needs iOS 17.4 and 🎃 is a jack-o'-lantern.
    static let emojiOverrides: [Int: String] = [13: "🍋", 37: "🍈", 38: "🍈", 41: "🍈"]

    /// `docs/research/2026-10-08-produce-weights.json` is the reviewed table; the bundle copies it.
    @Test func comparisonsMatchTheResearchTable() throws {
        let expected: [Int: (en: String, grams: Int)] = [
            10: ("a passion fruit", 35), 20: ("an Asian pear", 302), 31: ("a pineapple", 1775), 40: ("a watermelon", 3500),
        ]
        for (number, row) in expected {
            let week = try #require(library.content(forWeek: number))
            #expect(week.size.en == row.en, "week \(number)")
            #expect(week.size.typicalGrams == row.grams, "week \(number)")
        }

        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/research/2026-10-08-produce-weights.json")
        let research = try JSONDecoder().decode(ResearchTable.self, from: Data(contentsOf: url))
        #expect(research.weeks.map(\.week) == Array(10...42))
        #expect(library.document.produceSources == research.produceSources)
        for row in research.weeks {
            let size = try #require(library.content(forWeek: row.week)).size
            #expect(size.en == row.en, "week \(row.week)")
            #expect(size.vi == row.vi, "week \(row.week)")
            #expect(size.typicalGrams == row.typicalGrams, "week \(row.week)")
            #expect(size.sourceKey == row.sourceKey, "week \(row.week)")
            #expect(size.emoji == (Self.emojiOverrides[row.week] ?? row.emoji), "week \(row.week)")
        }
    }

    @Test func measurementsAreInTypicalRanges() {
        for (week, expected) in Self.typicalWeights {
            #expect(library.content(forWeek: week)?.weightG.map(expected.contains) == true, "week \(week) weight")
        }
        for (week, expected) in Self.typicalCRL {
            #expect(library.content(forWeek: week)?.crlMm.map(expected.contains) == true, "week \(week) CRL")
        }
    }

    @Test func keyWeightsEqualHadlockTable1() {
        #expect(library.content(forWeek: 20)?.weightG == 331)
        #expect(library.content(forWeek: 24)?.weightG == 670)
        #expect(library.content(forWeek: 28)?.weightG == 1210)
        #expect(library.content(forWeek: 40)?.weightG == 3619)
        #expect(library.content(forWeek: 12)?.crlMm == 53.5)
    }

    @Test func everyWeightMatchesHadlock1991() {
        for (week, expected) in Self.hadlock1991 {
            let content = library.content(forWeek: week)
            #expect(content?.weightP10G == expected.p10, "week \(week) 10th")
            #expect(content?.weightG == expected.p50, "week \(week) 50th")
            #expect(content?.weightP90G == expected.p90, "week \(week) 90th")
        }
    }

    @Test func weeks41And42ReuseWeek40() throws {
        let week40 = try #require(library.content(forWeek: 40))
        for number in [41, 42] {
            let week = try #require(library.content(forWeek: number))
            #expect(week.weightG == week40.weightG, "week \(number)")
            #expect(week.weightP10G == week40.weightP10G, "week \(number)")
            #expect(week.weightP90G == week40.weightP90G, "week \(number)")
            #expect(week.weightBeyondStandard, "week \(number)")
        }
    }

    @Test func crownRumpLengthsMatchHadlock1992() {
        for week in library.document.weeks {
            #expect(week.crlMm == Self.hadlock1992CRL[week.week], "week \(week.week)")
        }
    }

    @Test func noWeightBeforeWeek10() {
        for week in library.document.weeks where week.week < 10 {
            #expect(week.weightG == nil && week.weightP10G == nil && week.weightP90G == nil, "week \(week.week)")
        }
    }

    @Test func sourcesCiteHadlock() {
        let joined = library.sources.joined(separator: " | ")
        #expect(joined.contains("Hadlock FP, Harrist RB, Martinez-Poyer J"))
        #expect(joined.contains("Radiology. 1991;181(1):129–133"))
        #expect(joined.contains("Hadlock FP, Shah YP, Kanon DJ, Lindsey JV"))
        #expect(joined.contains("Radiology. 1992;182(2):501–505"))
    }

    @Test func sourceJSONHasNoLegacyLengthKey() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/KickCore/Resources/\(WeeklyContentLibrary.resourceName).json")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("\"lengthCm\""))
    }

    /// The CRL values are calculated from Hadlock 1992's equation, not printed in the paper.
    @Test func crlSourceSaysValuesAreCalculated() throws {
        let source = try #require(library.sources.first { $0.contains("Hadlock FP, Shah YP") })
        #expect(source.contains("calculated from this paper's regression equation"), "\(source)")
    }

    /// Items with a fitting emoji must use it. The emoji is only the fallback when
    /// a week's fruit artwork is missing, so pumpkin and lime use the closest one.
    @Test func sizeEmojiDepictsTheItem() {
        let expectedEmoji: [(keyword: String, emoji: Set<String>)] = [
            ("watermelon", ["🍉"]), ("cantaloupe", ["🍈"]), ("honeydew", ["🍈"]),
            ("pineapple", ["🍍"]), ("coconut", ["🥥"]), ("banana", ["🍌"]),
            ("cabbage", ["🥬"]), ("lettuce", ["🥬"]), ("lemon", ["🍋"]),
            ("garlic", ["🧄"]), ("ginger", ["🫚"]),
            ("pumpkin", ["🍈"]), ("lime", ["🍋"]),
        ]
        for week in library.document.weeks {
            let name = week.size.en
            for rule in expectedEmoji where name.contains(rule.keyword) {
                #expect(rule.emoji.contains(week.size.emoji), "week \(week.week): \(name) \(week.size.emoji)")
            }
        }
    }

    /// 🎃 is a carved jack-o'-lantern; not fitting for medical content.
    @Test func noJackOLanternEmoji() {
        for week in library.document.weeks {
            #expect(!week.size.emoji.contains("🎃"), "week \(week.week)")
        }
    }

    @Test func sourcesNameTheFourGuidelineBodies() {
        let joined = library.sources.joined(separator: " | ")
        for body in ["WHO", "ACOG", "NHS", "Bộ Y tế"] {
            #expect(joined.contains(body), "missing source: \(body)")
        }
    }
}
