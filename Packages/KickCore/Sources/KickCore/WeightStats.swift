import Foundation

/// A logged weight placed in the pregnancy, for the chart, the summary and the list.
public struct WeightPoint: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let day: Date
    public let kg: Double
    /// Gestational age on that day.
    public let week: GestationalWeek
    /// Gain since pre-pregnancy (one decimal); nil without a pre-pregnancy weight.
    public let gainKg: Double?
    /// nil without a BMI group (no height or no pre-pregnancy weight).
    public let status: WeightStatus?

    /// Weeks with days as a fraction (24w3d → 24.43), the chart's x value.
    public var exactWeek: Double { Double(week.weeks) + Double(week.days) / 7 }
}

/// One group of the history list: a pregnancy week, or (nil) days outside it.
public struct WeightSection: Equatable, Sendable, Identifiable {
    public let week: Int?
    /// Newest first.
    public let entries: [WeightRecord]

    public var id: Int { week ?? -1 }
}

/// The recommended range at a whole week, for the chart's band.
public struct WeightBandPoint: Equatable, Sendable, Identifiable {
    public let week: Int
    public let lowKg: Double
    public let highKg: Double

    public var id: Int { week }
}

public enum WeightStats {
    /// Entries inside the pregnancy (weeks 0–44), oldest first.
    public static func points(
        _ entries: [WeightRecord],
        profile: MaternalProfile,
        dueDate: Date,
        calendar: Calendar = .current
    ) -> [WeightPoint] {
        entries.sorted { $0.day < $1.day }.compactMap { entry in
            guard let timeline = PregnancyTimeline(dueDate: dueDate, now: entry.day, calendar: calendar) else { return nil }
            let week = timeline.week
            let gain = profile.preWeightKg.map { WeightRules.rounded(entry.kg - $0) }
            let exactWeek = Double(week.weeks) + Double(week.days) / 7
            let status: WeightStatus? = gain.flatMap { gain in
                profile.category.map { WeightGuidance.status(gain: gain, week: exactWeek, category: $0) }
            }
            return WeightPoint(id: entry.id, day: entry.day, kg: entry.kg, week: week, gainKg: gain, status: status)
        }
    }

    /// The history list: newest week first, newest day first inside a week;
    /// days outside the pregnancy (dates changed later) in a last group.
    public static func sections(_ entries: [WeightRecord], dueDate: Date, calendar: Calendar = .current) -> [WeightSection] {
        let newestFirst = entries.sorted { $0.day > $1.day }
        var weeks: [Int?] = []
        var grouped: [Int?: [WeightRecord]] = [:]
        for entry in newestFirst {
            let week = PregnancyTimeline(dueDate: dueDate, now: entry.day, calendar: calendar)?.week.weeks
            if grouped[week] == nil { weeks.append(week) }
            grouped[week, default: []].append(entry)
        }
        let ordered = weeks.compactMap { $0 }.sorted(by: >).map(Optional.some) + (weeks.contains(nil) ? [nil] : [])
        return ordered.map { WeightSection(week: $0, entries: grouped[$0] ?? []) }
    }

    /// The recommended range at weeks 0…40.
    public static func band(category: BMICategory) -> [WeightBandPoint] {
        (0...Int(WeightGuidance.termWeek)).map { week in
            let range = WeightGuidance.range(atWeek: Double(week), category: category)
            return WeightBandPoint(week: week, lowKg: range.lowerBound, highKg: range.upperBound)
        }
    }
}
