import Foundation

/// What the Cycle history page learns from her own logs (1.2 spec §2, §2b): the
/// lengths of her recent cycles, how regular they are, and the moods and
/// symptoms that come back at the same point of the cycle. Observations only:
/// the app never names a condition.
public struct CycleInsights: Equatable, Sendable {
    public struct LengthBar: Equatable, Sendable {
        public let start: Date
        public let length: Int
        /// Within `CyclePredictor.usableCycleLengths`, as the average counts it.
        public let counts: Bool
        /// The bar's height on the chart: a long gap (a pregnancy) stops at `chartCap`
        /// so the normal bars and the 24–38-day band stay readable.
        public var shownLength: Int { min(length, CycleInsights.chartCap) }
        public var isCapped: Bool { length > CycleInsights.chartCap }
    }

    public enum Regularity: Equatable, Sendable {
        /// Longest − shortest ≤ 7 days.
        case regular(spread: Int)
        /// 8–9 days.
        case somewhatVariable(spread: Int)
        /// 10 days or more.
        case variable(spread: Int)
    }

    public enum Item: Equatable, Sendable {
        case mood(Mood)
        case symptom(Symptom)
        case spotting
    }

    public enum Anchor: Equatable, Sendable {
        /// Day 1 is the first day of the period.
        case startDay
        /// Day 1 is the last day before the next period.
        case daysBefore
    }

    public struct Pattern: Equatable, Sendable {
        public let item: Item
        public let anchor: Anchor
        public let window: ClosedRange<Int>
        public let cyclesWithItem: Int
        public let cyclesLogged: Int

        /// A start-day window past day 7 is no longer in the period: worded as a
        /// day of the cycle, not of the period.
        public var isPastThePeriod: Bool { anchor == .startDay && window.lowerBound > 7 }
    }

    /// Completed cycles, oldest first, at most 12; empty with fewer than 2.
    public let lengths: [LengthBar]
    /// nil with fewer than 3 counted cycles.
    public let regularity: Regularity?
    /// At most 5, most consistent first.
    public let patterns: [Pattern]

    static let maxBars = 12
    public static let chartCap = 60
    static let cyclesForPatterns = 6
    static let minCyclesWithItem = 3
    static let maxWindowDays = 5
    static let maxPatterns = 5

    public static func make(history: CycleHistorySummary, logs: [CycleLogRecord], calendar: Calendar) -> CycleInsights {
        let completed = history.cycles.reversed().filter { !$0.isCurrent && $0.length != nil }
        let bars = completed.suffix(maxBars).map { LengthBar(start: $0.start, length: $0.length ?? 0, counts: $0.countsTowardAverage) }
        let counted = completed.filter(\.countsTowardAverage)
        let recentLengths = counted.suffix(CyclePredictor.maxCyclesAveraged).compactMap(\.length)
        return CycleInsights(
            lengths: bars.count >= 2 ? Array(bars) : [],
            regularity: regularity(recentLengths),
            patterns: patterns(cycles: Array(counted.suffix(cyclesForPatterns)), logs: logs, calendar: calendar)
        )
    }

    /// The first pattern (in ranking order) whose window holds today. A `.daysBefore`
    /// pattern needs a next period the forecast is sure of: not low-confidence, not late.
    public func todayPattern(cycleDay: Int, daysUntilNextPeriod: Int, nextPeriodIsReliable: Bool) -> Pattern? {
        patterns.first { pattern in
            switch pattern.anchor {
            case .startDay: pattern.window.contains(cycleDay)
            case .daysBefore: nextPeriodIsReliable && pattern.window.contains(daysUntilNextPeriod)
            }
        }
    }

    public func todayPattern(forecast: CycleForecast?) -> Pattern? {
        guard let forecast else { return nil }
        return todayPattern(
            cycleDay: forecast.cycleDay,
            daysUntilNextPeriod: forecast.daysUntilNextPeriod,
            nextPeriodIsReliable: forecast.confidence == .normal && forecast.daysLate == 0
        )
    }

    // MARK: - Rules

    static func regularity(_ lengths: [Int]) -> Regularity? {
        guard lengths.count >= 3, let low = lengths.min(), let high = lengths.max() else { return nil }
        let spread = high - low
        switch spread {
        case ...7: return .regular(spread: spread)
        case 8...9: return .somewhatVariable(spread: spread)
        default: return .variable(spread: spread)
        }
    }

    /// Every item she can log in cycle mode, in display order (the ranking's last
    /// tie-break). Not calm: "Bình thường" coming back is nothing to point out.
    static var items: [Item] {
        Mood.allCases.filter { $0 != .calm }.map(Item.mood) + Symptom.cases(for: .tryingToConceive).map(Item.symptom) + [.spotting]
    }

    static func patterns(cycles: [PastCycle], logs: [CycleLogRecord], calendar: Calendar) -> [Pattern] {
        let normalized = logs.map { CycleRules.normalized($0, calendar: calendar) }.filter(\.hasContent)
        // Each cycle's logs with their 1-based day, first day first.
        let perCycle: [(length: Int, logs: [(day: Int, log: CycleLogRecord)])] = cycles.compactMap { cycle in
            guard let length = cycle.length else { return nil }
            let days = normalized.compactMap { log -> (Int, CycleLogRecord)? in
                let offset = calendar.dateComponents([.day], from: cycle.start, to: log.day).day ?? -1
                return (0..<length).contains(offset) ? (offset + 1, log) : nil
            }
            return (length, days.sorted { $0.0 < $1.0 })
        }
        let logged = perCycle.filter { !$0.logs.isEmpty }
        guard !logged.isEmpty else { return [] }

        var found: [(pattern: Pattern, order: Int)] = []
        for (order, item) in items.enumerated() {
            var startDays: [Int] = []
            var daysBefore: [Int] = []
            for cycle in logged {
                guard let first = cycle.logs.first(where: { contains(item, in: $0.log) }) else { continue }
                startDays.append(first.day)
                daysBefore.append(cycle.length - first.day + 1)
            }
            let count = startDays.count
            guard count >= minCyclesWithItem, count * 2 >= logged.count else { continue }
            let fromStart = window(startDays)
            let beforeNext = window(daysBefore)
            let chosen: (Anchor, ClosedRange<Int>)?
            switch (fromStart, beforeNext) {
            case let (start?, before?):
                // Narrower wins; on a tie the nearer end of the cycle: "day 26" reads as
                // a period day, "3 days before your period" does not (CI-found, 1.2).
                let preferBefore = width(before) == width(start) ? before.lowerBound < start.lowerBound : width(before) < width(start)
                chosen = preferBefore ? (.daysBefore, before) : (.startDay, start)
            case let (start?, nil): chosen = (.startDay, start)
            case let (nil, before?): chosen = (.daysBefore, before)
            case (nil, nil): chosen = nil
            }
            guard let (anchor, range) = chosen else { continue }
            found.append((Pattern(item: item, anchor: anchor, window: range, cyclesWithItem: count, cyclesLogged: logged.count), order))
        }
        // Same denominator for every item, so the share orders like the count.
        return found
            .sorted {
                if $0.pattern.cyclesWithItem != $1.pattern.cyclesWithItem { return $0.pattern.cyclesWithItem > $1.pattern.cyclesWithItem }
                if width($0.pattern.window) != width($1.pattern.window) { return width($0.pattern.window) < width($1.pattern.window) }
                return $0.order < $1.order
            }
            .prefix(maxPatterns)
            .map(\.pattern)
    }

    /// The narrowest range holding ⌈75 %⌉ of the days, earliest on a tie; nil when wider than 5 days.
    static func window(_ days: [Int]) -> ClosedRange<Int>? {
        let sorted = days.sorted()
        let needed = Int((Double(sorted.count) * 0.75).rounded(.up))
        guard needed > 0, needed <= sorted.count else { return nil }
        var best: ClosedRange<Int>?
        for index in 0...(sorted.count - needed) {
            let range = sorted[index]...sorted[index + needed - 1]
            if best.map({ width(range) < width($0) }) ?? true { best = range }
        }
        return best.flatMap { width($0) <= maxWindowDays ? $0 : nil }
    }

    static func width(_ range: ClosedRange<Int>) -> Int { range.upperBound - range.lowerBound + 1 }

    static func contains(_ item: Item, in log: CycleLogRecord) -> Bool {
        switch item {
        case .mood(let mood): log.moods.contains(mood)
        case .symptom(let symptom): log.symptoms.contains(symptom)
        case .spotting: log.spotting
        }
    }
}
