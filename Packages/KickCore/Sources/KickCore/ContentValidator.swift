import Foundation

public enum ContentIssue: Equatable, Sendable {
    case unsupportedVersion(Int)
    case noSources
    case missingWeek(Int)
    case unexpectedWeek(Int)
    case duplicateWeek(Int)
    case weeksOutOfOrder
    /// `context` names the field, e.g. "week 7 baby.en" or "milestone nt-scan title.vi".
    case blankText(String)
    case tooFewItems(week: Int, section: String, language: ContentLanguage, minimum: Int)
    case translationCountMismatch(week: Int, section: String)
    /// A measurement is required in this week (weights 10–42, `crlMm` 7–13) but absent.
    case missingMeasurement(week: Int, field: String)
    /// A measurement is present outside the weeks its source covers.
    case unexpectedMeasurement(week: Int, field: String)
    case nonPositiveMeasurement(week: Int, field: String)
    /// Weights fell from the previous week, or `crlMm` did not rise.
    case decreasingMeasurement(week: Int, field: String)
    /// Not `weightP10G ≤ weightG ≤ weightP90G`.
    case invalidWeightRange(week: Int)
    case invalidMilestoneRange(id: String)
    case duplicateMilestoneID(String)
    /// Weeks 10–42 need a produce comparison by weight: `size.typicalGrams` and `size.sourceKey`.
    case missingTypicalWeight(week: Int)
    /// `size.sourceKey` names no entry of `produceSources`.
    case unknownProduceSource(week: Int, key: String)
    /// `|typicalGrams − reference| / reference` exceeds `comparisonTolerance`.
    case comparisonOutOfTolerance(week: Int, typicalGrams: Int, referenceGrams: Int)
}

/// Structural rules for `pregnancy-content.json`, enforced by unit tests so a
/// broken file never ships (the app itself only logs and hides content).
public enum ContentValidator {
    /// Version 2: Hadlock `crlMm` / `weightG` / `weightP10G` / `weightP90G` replace `lengthCm`.
    /// Version 3: optional `article` per week (phase 6, checked by `WeekArticleChecks`).
    /// Version 4: `size.typicalGrams` / `size.sourceKey` and `produceSources` (phase 11).
    public static let supportedVersion = 4
    /// Hadlock 1991 Table 1 starts at week 10; weeks 41–42 reuse week 40.
    public static let weightWeeks = 10...42
    /// Hadlock 1992 crown–rump length, within the CRL dating window (ACOG: up to 13 6/7 weeks).
    public static let crlWeeks = 7...13
    /// Weeks whose size comparison is by weight (the weeks with a Hadlock weight).
    public static let comparisonWeeks = 10...42
    /// The produce's typical weight may differ from the week's `weightG` by at most 25 %.
    public static let comparisonTolerance = 0.25
    static let minimumItems: [(section: String, minimum: Int)] = [
        ("baby", 2), ("mom", 2), ("tips", 2), ("warnings", 1),
    ]

    public static func validate(
        _ content: PregnancyContent,
        requiredWeeks: ClosedRange<Int> = WeeklyContentLibrary.weekRange
    ) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        if content.version != supportedVersion { issues.append(.unsupportedVersion(content.version)) }
        if content.sources.isEmpty { issues.append(.noSources) }
        for source in content.sources where isBlank(source) { issues.append(.blankText("sources")) }
        issues += weekIssues(content.weeks, requiredWeeks: requiredWeeks)
        issues += measurementIssues(content.weeks.sorted { $0.week < $1.week })
        issues += comparisonIssues(content)
        issues += milestoneIssues(content.milestones)
        return issues
    }

    private static func weekIssues(_ weeks: [WeekContent], requiredWeeks: ClosedRange<Int>) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        var seen = Set<Int>()
        for week in weeks {
            if !seen.insert(week.week).inserted { issues.append(.duplicateWeek(week.week)) }
            if !requiredWeeks.contains(week.week) { issues.append(.unexpectedWeek(week.week)) }
        }
        for number in requiredWeeks where !seen.contains(number) { issues.append(.missingWeek(number)) }
        let numbers = weeks.map(\.week)
        if numbers != numbers.sorted() { issues.append(.weeksOutOfOrder) }

        for week in weeks {
            let number = week.week
            let sizeFields = [("size.emoji", week.size.emoji), ("size.en", week.size.en), ("size.vi", week.size.vi)]
            for (field, text) in sizeFields where isBlank(text) {
                issues.append(.blankText("week \(number) \(field)"))
            }
            let sections = ["baby": week.baby, "mom": week.mom, "tips": week.tips, "warnings": week.warnings]
            for (section, minimum) in minimumItems {
                guard let list = sections[section] else { continue }
                for language in ContentLanguage.allCases {
                    let items = list.items(language)
                    if items.count < minimum {
                        issues.append(.tooFewItems(week: number, section: section, language: language, minimum: minimum))
                    }
                    if items.contains(where: isBlank) {
                        issues.append(.blankText("week \(number) \(section).\(language.rawValue)"))
                    }
                }
                if list.en.count != list.vi.count {
                    issues.append(.translationCountMismatch(week: number, section: section))
                }
            }
        }
        return issues
    }

    private struct MeasurementField: Sendable {
        let name: String
        let weeks: ClosedRange<Int>
        /// `crlMm` must rise every week; weights may stay level (weeks 41–42 reuse week 40).
        let strictlyIncreasing: Bool
        let value: @Sendable (WeekContent) -> Double?
    }

    private static let measurementFields: [MeasurementField] = [
        MeasurementField(name: "crlMm", weeks: crlWeeks, strictlyIncreasing: true) { $0.crlMm },
        MeasurementField(name: "weightG", weeks: weightWeeks, strictlyIncreasing: false) { $0.weightG.map(Double.init) },
        MeasurementField(name: "weightP10G", weeks: weightWeeks, strictlyIncreasing: false) { $0.weightP10G.map(Double.init) },
        MeasurementField(name: "weightP90G", weeks: weightWeeks, strictlyIncreasing: false) { $0.weightP90G.map(Double.init) },
    ]

    private static func measurementIssues(_ weeks: [WeekContent]) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        for field in measurementFields {
            var previous: Double?
            for week in weeks {
                guard let value = field.value(week) else {
                    if field.weeks.contains(week.week) {
                        issues.append(.missingMeasurement(week: week.week, field: field.name))
                    }
                    continue
                }
                if !field.weeks.contains(week.week) {
                    issues.append(.unexpectedMeasurement(week: week.week, field: field.name))
                }
                if value <= 0 { issues.append(.nonPositiveMeasurement(week: week.week, field: field.name)) }
                if let previous, field.strictlyIncreasing ? value <= previous : value < previous {
                    issues.append(.decreasingMeasurement(week: week.week, field: field.name))
                }
                previous = value
            }
        }
        for week in weeks {
            if let p10 = week.weightP10G, let p50 = week.weightG, let p90 = week.weightP90G,
               !(p10 <= p50 && p50 <= p90) {
                issues.append(.invalidWeightRange(week: week.week))
            }
        }
        return issues
    }

    private static func comparisonIssues(_ content: PregnancyContent) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        for (key, source) in content.produceSources.sorted(by: { $0.key < $1.key }) {
            for (field, text) in [("title", source.title), ("url", source.url), ("note", source.note)] where isBlank(text) {
                issues.append(.blankText("produceSources \(key) \(field)"))
            }
        }
        for week in content.weeks {
            let number = week.week
            let size = week.size
            guard comparisonWeeks.contains(number) else {
                if size.typicalGrams != nil { issues.append(.unexpectedMeasurement(week: number, field: "typicalGrams")) }
                if size.sourceKey != nil { issues.append(.unexpectedMeasurement(week: number, field: "sourceKey")) }
                continue
            }
            if size.typicalGrams == nil || size.sourceKey == nil {
                issues.append(.missingTypicalWeight(week: number))
            }
            if let key = size.sourceKey, content.produceSources[key] == nil {
                issues.append(.unknownProduceSource(week: number, key: key))
            }
            // Weeks 41–42 carry week 40's weight in their own `weightG`.
            if let typical = size.typicalGrams, let reference = week.weightG, reference > 0,
               abs(Double(typical - reference)) / Double(reference) > comparisonTolerance {
                issues.append(.comparisonOutOfTolerance(week: number, typicalGrams: typical, referenceGrams: reference))
            }
        }
        return issues
    }

    private static func milestoneIssues(_ milestones: [Milestone]) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        var ids = Set<String>()
        let allowed = WeeklyContentLibrary.weekRange
        for milestone in milestones {
            if isBlank(milestone.id) { issues.append(.blankText("milestone id")) }
            if !ids.insert(milestone.id).inserted { issues.append(.duplicateMilestoneID(milestone.id)) }
            if milestone.fromWeek > milestone.toWeek
                || !allowed.contains(milestone.fromWeek)
                || !allowed.contains(milestone.toWeek) {
                issues.append(.invalidMilestoneRange(id: milestone.id))
            }
            for language in ContentLanguage.allCases {
                if isBlank(milestone.title.text(language)) {
                    issues.append(.blankText("milestone \(milestone.id) title.\(language.rawValue)"))
                }
                if isBlank(milestone.detail.text(language)) {
                    issues.append(.blankText("milestone \(milestone.id) detail.\(language.rawValue)"))
                }
            }
        }
        return issues
    }

    static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
