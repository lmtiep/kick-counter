import Foundation

public enum CycleConfidence: Sendable, Equatable {
    case normal
    /// Fewer than 2 usable cycles, or cycles that vary a lot: the fertile window is widened.
    case low
}

/// Where the estimated ovulation day comes from, most reliable last.
public enum OvulationSource: Sendable, Equatable {
    /// Next period − 14 days.
    case calendar
    /// The day after the first positive LH test of this cycle.
    case lhTest
    /// Confirmed afterwards by a sustained BBT rise (the day before the rise).
    case temperature
}

/// How a calendar day is coloured.
public enum CycleDayStatus: Sendable, Equatable {
    /// A logged period day, or a predicted one (`isPredicted`).
    case period(isPredicted: Bool)
    case fertile
    /// Ovulation day and the day before it.
    case peak
    case low
}

/// The calendar-based forecast for the current cycle, adjusted by LH tests and
/// confirmed by basal body temperature (spec §4.1). All dates are the start of
/// a calendar day.
public struct CycleForecast: Equatable, Sendable {
    public let today: Date
    public let currentPeriodStart: Date
    /// 1 on the first day of the latest period.
    public let cycleDay: Int
    /// Mean of up to 6 most recent complete cycles of 21–45 days, else the typical length.
    public let averageCycleLength: Int
    /// The cycle lengths behind the average, oldest first.
    public let usableCycleLengths: [Int]
    public let nextPeriodStart: Date
    public let ovulationDate: Date
    public let ovulationSource: OvulationSource
    public let fertileWindow: ClosedRange<Date>
    public let confidence: CycleConfidence
    /// Extra days added on each side of a low-confidence calendar window.
    public let windowWidening: Int
    /// Days past `nextPeriodStart` with no new period logged.
    public let daysLate: Int
    public let irregularWarning: Bool
    /// The latest period has no end date and has gone on for more than 10 days.
    public let isLongOpenPeriod: Bool

    let periods: [PeriodRecord]
    let typicalPeriodLength: Int
    let calendar: Calendar

    public var ovulationConfirmed: Bool { ovulationSource == .temperature }

    /// Whole days from today to `nextPeriodStart` (0 when due today or late).
    public var daysUntilNextPeriod: Int {
        max(0, calendar.dateComponents([.day], from: today, to: nextPeriodStart).day ?? 0)
    }

    /// Late enough for the "take a test" card and reminder (3 days or more).
    public var isNoticeablyLate: Bool { daysLate >= CyclePredictor.lateNoticeDays }

    /// The latest period, still open.
    public var openPeriod: PeriodRecord? {
        guard let latest = periods.last, latest.isOpen else { return nil }
        return latest
    }

    public func dayStatus(for date: Date) -> CycleDayStatus {
        let day = calendar.startOfDay(for: date)
        for period in periods where CycleRules.dayRange(of: period, today: today, calendar: calendar).contains(day) {
            return .period(isPredicted: false)
        }
        if let open = openPeriod, day > today, let lastDay = adding(typicalPeriodLength - 1, to: open.startDate), day <= lastDay {
            return .period(isPredicted: true)
        }
        guard day >= currentPeriodStart else { return .low }
        // A missed period: no fertile/peak/predicted-period coloring from the
        // predicted next start onward until a new period is actually logged.
        if daysLate > 0, day >= nextPeriodStart { return .low }
        if let status = windowStatus(day, ovulation: ovulationDate, window: fertileWindow) {
            return status
        }
        // Later cycles repeat the calendar prediction.
        let cycleIndex = days(from: currentPeriodStart, to: day) / averageCycleLength
        guard cycleIndex >= 1, let cycleStart = adding(cycleIndex * averageCycleLength, to: currentPeriodStart) else { return .low }
        if day > today, let lastDay = adding(typicalPeriodLength - 1, to: cycleStart), day <= lastDay {
            return .period(isPredicted: true)
        }
        guard let ovulation = adding(averageCycleLength - CyclePredictor.lutealPhaseDays, to: cycleStart),
              let window = CyclePredictor.window(around: ovulation, widening: windowWidening, calendar: calendar)
        else { return .low }
        return windowStatus(day, ovulation: ovulation, window: window) ?? .low
    }

    private func windowStatus(_ day: Date, ovulation: Date, window: ClosedRange<Date>) -> CycleDayStatus? {
        if day == ovulation || adding(1, to: day) == ovulation { return .peak }
        return window.contains(day) ? .fertile : nil
    }

    private func adding(_ days: Int, to date: Date) -> Date? {
        calendar.date(byAdding: .day, value: days, to: date)
    }

    private func days(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

public enum CyclePredictor {
    static let lutealPhaseDays = 14
    static let daysBeforeOvulation = 5
    static let daysAfterOvulation = 1
    static let maxCyclesAveraged = 6
    /// Cycles that count toward the average (and the history's "counts toward average").
    static let usableCycleLengths = 21...45
    /// A latest cycle outside this range shows "Your cycle looks irregular", matching its
    /// text ("shorter than 24 days, longer than 38 days"): the FIGO 2018 normal range for
    /// adults. Content review §19 (supersedes fact-check rows 22-c/22-e).
    static let regularCycleLengths = 24...38
    static let maxStandardDeviation = 4.0
    static let maxSpread = 7
    static let maxWidening = 3
    static let minimumTemperatureRise = 0.2
    static let temperatureBaselineDays = 6
    static let temperatureHighDays = 3
    public static let lateNoticeDays = 3

    /// nil when no period has been logged yet (the Cycle tab asks for the last one).
    public static func forecast(
        periods: [PeriodRecord],
        logs: [CycleLogRecord],
        settings: CycleSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> CycleForecast? {
        let today = calendar.startOfDay(for: now)
        let sorted = periods
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { $0.startDate <= today }
            .sorted { $0.startDate < $1.startDate }
        guard let current = sorted.last else { return nil }
        func days(_ start: Date, _ end: Date) -> Int {
            calendar.dateComponents([.day], from: start, to: end).day ?? 0
        }
        func adding(_ count: Int, to date: Date) -> Date {
            calendar.date(byAdding: .day, value: count, to: date) ?? date
        }

        let allLengths = zip(sorted, sorted.dropFirst()).map { days($0.startDate, $1.startDate) }
        let usable = Array(allLengths.filter { usableCycleLengths.contains($0) }.suffix(maxCyclesAveraged))
        let average = usable.isEmpty
            ? settings.typicalCycleLength
            : Int((Double(usable.reduce(0, +)) / Double(usable.count)).rounded())
        let spread = (usable.max() ?? 0) - (usable.min() ?? 0)
        let isVariable = usable.count >= 3 && (standardDeviation(usable) > maxStandardDeviation || spread > maxSpread)
        let confidence: CycleConfidence = usable.count < 2 || isVariable ? .low : .normal

        let nextPeriodStart = adding(average, to: current.startDate)
        let cycleLogs = logs
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { $0.day >= current.startDate && $0.day <= today }
            .sorted { $0.day < $1.day }

        var ovulation = adding(-lutealPhaseDays, to: nextPeriodStart)
        var source = OvulationSource.calendar
        if let firstPositive = cycleLogs.first(where: { $0.lh == .positive }) {
            ovulation = adding(1, to: firstPositive.day)
            source = .lhTest
        }
        if let confirmed = temperatureConfirmedOvulation(cycleLogs, calendar: calendar) {
            ovulation = confirmed
            source = .temperature
        }
        let widening = confidence == .low && source == .calendar ? min(maxWidening, spread / 2) : 0
        let window = window(around: ovulation, widening: widening, calendar: calendar)
            ?? ovulation...ovulation

        let lastLength = allLengths.last
        let irregular = (lastLength.map { !regularCycleLengths.contains($0) } ?? false) || (usable.count >= 3 && spread > maxSpread)

        return CycleForecast(
            today: today,
            currentPeriodStart: current.startDate,
            cycleDay: days(current.startDate, today) + 1,
            averageCycleLength: average,
            usableCycleLengths: usable,
            nextPeriodStart: nextPeriodStart,
            ovulationDate: ovulation,
            ovulationSource: source,
            fertileWindow: window,
            confidence: confidence,
            windowWidening: widening,
            daysLate: max(0, days(nextPeriodStart, today)),
            irregularWarning: irregular,
            isLongOpenPeriod: current.isOpen && days(current.startDate, today) + 1 > CycleRules.longPeriodDays,
            periods: sorted,
            typicalPeriodLength: settings.typicalPeriodLength,
            calendar: calendar
        )
    }

    /// Ovulation − 5 … ovulation + 1, widened by `widening` days on each side.
    static func window(around ovulation: Date, widening: Int, calendar: Calendar) -> ClosedRange<Date>? {
        guard let start = calendar.date(byAdding: .day, value: -(daysBeforeOvulation + widening), to: ovulation),
              let end = calendar.date(byAdding: .day, value: daysAfterOvulation + widening, to: ovulation)
        else { return nil }
        return start...end
    }

    /// The 3-over-6 rule: the first 3 readings on consecutive days that are all at
    /// least 0.2 °C above the highest of the 6 readings before them confirm that
    /// ovulation happened the day before the first high reading.
    static func temperatureConfirmedOvulation(_ cycleLogs: [CycleLogRecord], calendar: Calendar) -> Date? {
        let readings = cycleLogs.compactMap { log in log.bbtCelsius.map { (day: log.day, celsius: $0) } }
        guard readings.count >= temperatureBaselineDays + temperatureHighDays else { return nil }
        for start in temperatureBaselineDays...(readings.count - temperatureHighDays) {
            let high = readings[start..<(start + temperatureHighDays)]
            let consecutive = zip(high, high.dropFirst()).allSatisfy { pair in
                calendar.dateComponents([.day], from: pair.0.day, to: pair.1.day).day == 1
            }
            guard consecutive else { continue }
            let baseline = readings[(start - temperatureBaselineDays)..<start].map(\.celsius).max() ?? .infinity
            // Readings are entered to 0.1 °C; the epsilon absorbs floating-point error.
            if high.allSatisfy({ $0.celsius >= baseline + minimumTemperatureRise - 0.0001 }) {
                return calendar.date(byAdding: .day, value: -1, to: readings[start].day)
            }
        }
        return nil
    }

    static func standardDeviation(_ values: [Int]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let variance = values.map { (Double($0) - mean) * (Double($0) - mean) }.reduce(0, +) / Double(values.count)
        return variance.squareRoot()
    }
}
