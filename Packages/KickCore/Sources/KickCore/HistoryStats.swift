import Foundation

/// One bar of the kick history chart: a day, or a 7-day week.
public struct HistoryBar: Equatable, Sendable, Identifiable {
    /// Midnight starting the day or the week.
    public let start: Date
    /// Minutes to reach 10 movements; nil when no session was completed.
    public let minutes: Double?
    /// Today, or the week ending today.
    public let isCurrent: Bool
    public var id: Date { start }

    public init(start: Date, minutes: Double?, isCurrent: Bool) {
        self.start = start
        self.minutes = minutes
        self.isCurrent = isCurrent
    }
}

/// Figures for the Kicks screen, the kick history (spec §4.7) and the
/// "Movements today" card. Only completed sessions count.
public enum HistoryStats {
    /// The chart's top (longer bars are cut there, the value is written above them)
    /// and the dashed 30-minute reference line.
    public static let chartMaxMinutes = 60.0
    public static let referenceMinutes = 30.0

    /// Height of a bar as a share of the chart, cut at `chartMaxMinutes`.
    public static func barFraction(minutes: Double) -> Double {
        min(max(minutes, 0), chartMaxMinutes) / chartMaxMinutes
    }

    /// The last `days` days, today last: the latest completed session of each day.
    public static func daily(
        _ sessions: [SessionState],
        endingAt now: Date,
        days: Int = 7,
        calendar: Calendar = .current
    ) -> [HistoryBar] {
        let summaries = HistorySummary.daily(sessions, endingAt: now, days: days, calendar: calendar)
        let byDay = Dictionary(uniqueKeysWithValues: summaries.map { ($0.day, $0.minutesToTarget) })
        return RecentDay.ending(at: now, count: days, calendar: calendar).map {
            HistoryBar(start: $0.date, minutes: byDay[$0.date], isCurrent: $0.isToday)
        }
    }

    /// Mean minutes to 10 movements over the completed sessions started in the
    /// last `days` days (today included); nil when there are none.
    public static func averageMinutes(
        _ sessions: [SessionState],
        endingAt now: Date,
        days: Int,
        calendar: Calendar = .current
    ) -> Double? {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today)
        else { return nil }
        let minutes = completedMinutes(sessions) { $0 >= start && $0 < end }
        return minutes.isEmpty ? nil : minutes.reduce(0, +) / Double(minutes.count)
    }

    /// The latest completed session started on `now`'s day.
    public static func latestCompleted(
        _ sessions: [SessionState],
        on now: Date,
        calendar: Calendar = .current
    ) -> SessionState? {
        sessions
            .filter { $0.status == .completed && $0.duration != nil && calendar.isDate($0.startedAt, inSameDayAs: now) }
            .max { $0.startedAt < $1.startedAt }
    }

    static func completedMinutes(_ sessions: [SessionState], startedWhere include: (Date) -> Bool) -> [Double] {
        sessions.compactMap { session in
            guard session.status == .completed, let duration = session.duration, include(session.startedAt) else { return nil }
            return duration / 60
        }
    }
}
