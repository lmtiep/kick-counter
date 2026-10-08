import Foundation

/// One cycle in the history (phase 10 spec §3): from the start of a period to
/// the day before the next one; the last cycle runs to today.
public struct PastCycle: Equatable, Sendable, Identifiable {
    public var id: UUID { periodID }
    /// The period that opens the cycle.
    public let periodID: UUID
    /// Start of the period's first day.
    public let start: Date
    /// Days to the next period's start; nil for the current cycle.
    public let length: Int?
    /// Days of bleeding (`CycleRules.dayRange`: an open period runs to today,
    /// at most `CycleRules.longPeriodDays`).
    public let periodLength: Int
    public let isCurrent: Bool
    /// Today's day of the cycle (1-based); current cycle only.
    public let cycleDay: Int?
    /// `length` is within `CyclePredictor.usableCycleLengths`; never the current cycle.
    public let countsTowardAverage: Bool
    /// 0-based day offsets with something logged (`CycleLogRecord.hasContent`), ascending.
    public let loggedDays: [Int]
}

/// The "Cycle history" page's data.
public struct CycleHistorySummary: Equatable, Sendable {
    /// `CyclePredictor`'s average: the last 6 usable lengths, rounded. nil without one.
    public let averageCycleLength: Int?
    /// Shortest...longest of those lengths; nil with fewer than two.
    public let cycleLengthRange: ClosedRange<Int>?
    /// Mean bleeding days of the closed periods among the last 6; nil without one.
    public let averagePeriodLength: Int?
    /// Newest first.
    public let cycles: [PastCycle]
}

public enum CycleHistory {
    static let periodsAveraged = 6

    public static func make(
        periods: [PeriodRecord],
        logs: [CycleLogRecord],
        now: Date,
        calendar: Calendar = .current
    ) -> CycleHistorySummary {
        let today = calendar.startOfDay(for: now)
        let sorted = periods
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { $0.startDate <= today }
            .sorted { $0.startDate < $1.startDate }
        let logged = Set(
            logs.map { CycleRules.normalized($0, calendar: calendar) }
                .filter { $0.hasContent && $0.day <= today }
                .map(\.day)
        )
        func days(_ start: Date, _ end: Date) -> Int {
            calendar.dateComponents([.day], from: start, to: end).day ?? 0
        }

        var cycles: [PastCycle] = []
        for (index, period) in sorted.enumerated() {
            let next = sorted.indices.contains(index + 1) ? sorted[index + 1] : nil
            let length = next.map { days(period.startDate, $0.startDate) }
            let lastDay = next.flatMap { calendar.date(byAdding: .day, value: -1, to: $0.startDate) } ?? today
            let bleeding = CycleRules.dayRange(of: period, today: today, calendar: calendar)
            cycles.append(PastCycle(
                periodID: period.id,
                start: period.startDate,
                length: length,
                periodLength: days(bleeding.lowerBound, bleeding.upperBound) + 1,
                isCurrent: next == nil,
                cycleDay: next == nil ? days(period.startDate, today) + 1 : nil,
                countsTowardAverage: length.map(CyclePredictor.usableCycleLengths.contains) ?? false,
                loggedDays: logged
                    .filter { $0 >= period.startDate && $0 <= lastDay }
                    .map { days(period.startDate, $0) }
                    .sorted()
            ))
        }

        let usable = Array(cycles.filter(\.countsTowardAverage).compactMap(\.length).suffix(CyclePredictor.maxCyclesAveraged))
        let average = usable.isEmpty ? nil : Int((Double(usable.reduce(0, +)) / Double(usable.count)).rounded())
        let range = usable.count >= 2 ? (usable.min() ?? 0)...(usable.max() ?? 0) : nil
        let closedLengths = zip(sorted, cycles)
            .suffix(periodsAveraged)
            .filter { $0.0.endDate != nil }
            .map(\.1.periodLength)
        let averagePeriod = closedLengths.isEmpty
            ? nil
            : Int((Double(closedLengths.reduce(0, +)) / Double(closedLengths.count)).rounded())

        return CycleHistorySummary(
            averageCycleLength: average,
            cycleLengthRange: range,
            averagePeriodLength: averagePeriod,
            cycles: cycles.reversed()
        )
    }
}

extension CycleLogRecord {
    /// Something is logged: flow (even "none"), a mood, a symptom, mucus, LH,
    /// a temperature or a non-blank note.
    public var hasContent: Bool {
        flow != nil || !moods.isEmpty || !symptoms.isEmpty || mucus != nil || lh != nil
            || bbtCelsius != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
