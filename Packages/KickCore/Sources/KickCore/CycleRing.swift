import Foundation

/// How one stretch of the cycle ring is coloured (spec §4.2).
public enum CycleRingKind: Equatable, Sendable {
    case period
    case predictedPeriod
    case fertile
    /// Ovulation and the day before (`CycleDayStatus.peak`).
    case ovulation
    case base

    init(_ status: CycleDayStatus) {
        switch status {
        case .period(isPredicted: false): self = .period
        case .period(isPredicted: true): self = .predictedPeriod
        case .fertile: self = .fertile
        case .peak: self = .ovulation
        case .low: self = .base
        }
    }
}

/// A run of same-coloured days on the ring, as fractions of a full turn
/// (0 at 12 o'clock, clockwise).
public struct CycleRingSegment: Equatable, Sendable {
    public let kind: CycleRingKind
    public let start: Double
    public let end: Double

    public init(kind: CycleRingKind, start: Double, end: Double) {
        self.kind = kind
        self.start = start
        self.end = end
    }
}

public enum CycleRingGeometry {
    /// Days on the ring: the average cycle, stretched when this cycle runs longer.
    public static func length(of forecast: CycleForecast) -> Int {
        max(forecast.averageCycleLength, forecast.cycleDay)
    }

    /// Consecutive days with the same colour merged into one segment, from day 1.
    public static func segments(for forecast: CycleForecast, calendar: Calendar = .current) -> [CycleRingSegment] {
        let length = length(of: forecast)
        var segments: [CycleRingSegment] = []
        var runKind: CycleRingKind?
        var runStart = 0
        for index in 0...length {
            let kind: CycleRingKind? = index == length ? nil : calendar
                .date(byAdding: .day, value: index, to: forecast.currentPeriodStart)
                .map { CycleRingKind(forecast.dayStatus(for: $0)) }
            if kind != runKind || index == length {
                if let runKind, index > runStart {
                    segments.append(CycleRingSegment(
                        kind: runKind, start: Double(runStart) / Double(length), end: Double(index) / Double(length)
                    ))
                }
                runKind = kind
                runStart = index
            }
        }
        return segments
    }

    /// Radians clockwise from 12 o'clock to the middle of today's day.
    public static func markerAngle(for forecast: CycleForecast) -> Double {
        2 * Double.pi * (Double(forecast.cycleDay) - 0.5) / Double(length(of: forecast))
    }

    /// The marker's centre relative to the ring's centre (y grows downwards).
    public static func markerOffset(angle: Double, radius: Double) -> (x: Double, y: Double) {
        (radius * sin(angle), -radius * cos(angle))
    }
}

/// The big text inside the ring (spec §4.2).
public enum CycleRingHeadline: Equatable, Sendable {
    /// During a logged period: "Day N".
    case periodDay(Int)
    /// "N days" to the next period.
    case daysUntilNextPeriod(Int)
    case nextPeriodToday
    /// "N days late".
    case late(days: Int)

    public init(forecast: CycleForecast) {
        if forecast.dayStatus(for: forecast.today) == .period(isPredicted: false) {
            self = .periodDay(forecast.cycleDay)
        } else if forecast.daysLate > 0 {
            self = .late(days: forecast.daysLate)
        } else if forecast.daysUntilNextPeriod == 0 {
            self = .nextPeriodToday
        } else {
            self = .daysUntilNextPeriod(forecast.daysUntilNextPeriod)
        }
    }
}

extension CycleForecast {
    /// "Regular" on the Coming up card: enough similar cycles and no irregular warning.
    public var isRegular: Bool {
        confidence == .normal && !irregularWarning
    }

    /// Cycle day of `date` for the calendar's selected-day card: counted from the
    /// latest logged period starting on or before it. After today, predicted
    /// cycles repeat every `averageCycleLength` days (unless the period is late).
    /// Nil before the first logged period.
    public func cycleDay(on date: Date) -> Int? {
        let day = calendar.startOfDay(for: date)
        guard let start = periods.last(where: { $0.startDate <= day })?.startDate,
              let elapsed = calendar.dateComponents([.day], from: start, to: day).day
        else { return nil }
        if start == currentPeriodStart, day > today, daysLate == 0 {
            return elapsed % averageCycleLength + 1
        }
        return elapsed + 1
    }

}
