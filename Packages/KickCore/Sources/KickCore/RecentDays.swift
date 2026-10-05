import Foundation

/// One calendar day (midnight) in a row of recent days.
public struct RecentDay: Equatable, Sendable, Identifiable {
    public let date: Date
    public let isToday: Bool
    public var id: Date { date }

    public init(date: Date, isToday: Bool) {
        self.date = date
        self.isToday = isToday
    }

    /// `count` days ending today (oldest first, today last).
    static func ending(at now: Date, count: Int, calendar: Calendar) -> [RecentDay] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: today).map { RecentDay(date: $0, isToday: back == 0) }
        }
    }
}

/// The strip under the Today header (spec §4.2, §4.4): 6 days before today, then today.
public enum WeekStrip {
    public static let length = 7

    public static func days(endingAt now: Date, calendar: Calendar = .current) -> [RecentDay] {
        RecentDay.ending(at: now, count: length, calendar: calendar)
    }
}

/// Onboarding "When did your last period start?" (spec §4.1): the 14 most
/// recent days in 7 columns, today last. Older dates go through "Another day".
public enum RecentDaysGrid {
    public static let length = 14
    public static let columns = 7

    public static func days(endingAt now: Date, calendar: Calendar = .current) -> [RecentDay] {
        RecentDay.ending(at: now, count: length, calendar: calendar)
    }
}

/// Weekday names of the redesign: "T2"…"CN" in Vietnamese, "Mon"…"Sun" in
/// English. The calendar's locale picks the language.
public enum WeekdayLabel {
    public static func short(for date: Date, calendar: Calendar) -> String {
        symbol(weekday: calendar.component(.weekday, from: date), calendar: calendar)
    }

    /// `weekday` is 1 (Sunday) … 7 (Saturday), like `Calendar.component(.weekday, …)`.
    public static func symbol(weekday: Int, calendar: Calendar) -> String {
        let isVietnamese = calendar.locale?.language.languageCode?.identifier == "vi"
        let symbols = isVietnamese ? calendar.veryShortStandaloneWeekdaySymbols : calendar.shortStandaloneWeekdaySymbols
        return symbols[(weekday - 1 + 7) % 7]
    }

    /// The seven labels in grid order, starting at the calendar's first weekday.
    public static func row(calendar: Calendar) -> [String] {
        (0..<7).map { symbol(weekday: (calendar.firstWeekday - 1 + $0) % 7 + 1, calendar: calendar) }
    }
}
