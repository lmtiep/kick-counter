import Foundation
import Testing
@testable import KickCore

struct RecentDaysTests {
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func calendar(_ identifier: String, firstWeekday: Int? = nil) -> Calendar {
        var calendar = utcCalendar
        calendar.locale = Locale(identifier: identifier)
        if let firstWeekday { calendar.firstWeekday = firstWeekday }
        return calendar
    }

    @Test func weekStripIsSixDaysThenToday() {
        let days = WeekStrip.days(endingAt: date("2026-10-04T18:30:00Z"), calendar: utcCalendar)
        #expect(days.count == 7)
        #expect(days.first?.date == day("2026-09-28"))
        #expect(days.last == RecentDay(date: day("2026-10-04"), isToday: true))
        #expect(days.filter(\.isToday).count == 1)
    }

    @Test func weekStripCrossesMonthAndYearBoundaries() {
        let days = WeekStrip.days(endingAt: date("2027-01-02T08:00:00Z"), calendar: utcCalendar)
        #expect(days.map(\.date) == ["2026-12-27", "2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02"].map(day))
    }

    @Test func recentDaysGridIsTwoWeeksEndingToday() {
        let days = RecentDaysGrid.days(endingAt: date("2026-10-02T12:00:00Z"), calendar: utcCalendar)
        #expect(days.count == 14)
        #expect(days.first?.date == day("2026-09-19"))
        #expect(days[1].date == day("2026-09-20"))
        #expect(days.last?.isToday == true)
        #expect(days.dropLast().allSatisfy { !$0.isToday })
    }

    @Test func weekdayLabelsFollowTheCalendarsLanguage() {
        let sunday = day("2026-10-04")
        let monday = day("2026-10-05")
        #expect(WeekdayLabel.short(for: monday, calendar: calendar("vi_VN")) == "T2")
        #expect(WeekdayLabel.short(for: sunday, calendar: calendar("vi_VN")) == "CN")
        #expect(WeekdayLabel.short(for: monday, calendar: calendar("en_US")) == "Mon")
        #expect(WeekdayLabel.short(for: sunday, calendar: calendar("en_US")) == "Sun")
    }

    @Test func weekdayRowStartsAtTheFirstWeekday() {
        #expect(WeekdayLabel.row(calendar: calendar("vi_VN", firstWeekday: 2)) == ["T2", "T3", "T4", "T5", "T6", "T7", "CN"])
        #expect(WeekdayLabel.row(calendar: calendar("en_US", firstWeekday: 1)) == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
    }
}
