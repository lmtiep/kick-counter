import Foundation

/// Month layout for the Calendar tab, following the locale's first weekday.
public enum CycleCalendarGrid {
    /// Midnight on the first day of the month containing `date`.
    public static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    /// The first day of the month `offset` months from the one containing `date`.
    public static func month(_ offset: Int, from date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfMonth(date, calendar: calendar)
        return calendar.date(byAdding: .month, value: offset, to: start) ?? start
    }

    /// One entry per cell, row by row: `nil` for the blanks before day 1, then
    /// every day of the month (midnight). No trailing blanks.
    public static func days(inMonthOf date: Date, calendar: Calendar = .current) -> [Date?] {
        let first = startOfMonth(date, calendar: calendar)
        guard let count = calendar.range(of: .day, in: .month, for: first)?.count else { return [] }
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let days: [Date?] = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: first) }
        return Array(repeating: nil, count: leading) + days
    }

    /// Very short weekday names starting at the calendar's first weekday ("S M T…" / "T2 T3…").
    public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
