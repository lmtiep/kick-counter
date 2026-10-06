import Foundation
import Testing
@testable import KickCore

struct WeightRulesTests {
    let calendar = utcCalendar
    let today = date("2026-10-02T12:00:00Z")

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func normalizingMovesToTheStartOfTheDayAndRoundsToOneDecimal() {
        let entry = WeightRecord(day: date("2026-10-01T18:30:00Z"), kg: 58.04)
        #expect(WeightRules.normalized(entry, calendar: calendar) == WeightRecord(id: entry.id, day: day("2026-10-01"), kg: 58.0))
        #expect(WeightRules.rounded(56.25) == 56.3)
    }

    @Test func weightsFrom30To200KgAreAccepted() throws {
        try WeightRules.validate(WeightRecord(day: today, kg: 30.0), today: today, calendar: calendar)
        try WeightRules.validate(WeightRecord(day: today, kg: 200.0), today: today, calendar: calendar)
        try WeightRules.validate(WeightRecord(day: today, kg: 29.96), today: today, calendar: calendar) // rounds to 30.0
        #expect(throws: WeightRepositoryError.outOfRange) {
            try WeightRules.validate(WeightRecord(day: today, kg: 29.9), today: today, calendar: calendar)
        }
        #expect(throws: WeightRepositoryError.outOfRange) {
            try WeightRules.validate(WeightRecord(day: today, kg: 200.1), today: today, calendar: calendar)
        }
        #expect(throws: WeightRepositoryError.outOfRange) {
            try WeightRules.validate(WeightRecord(day: today, kg: .nan), today: today, calendar: calendar)
        }
    }

    @Test func futureDaysAreRefusedAndTodayIsAllowed() throws {
        try WeightRules.validate(WeightRecord(day: date("2026-10-02T23:59:00Z"), kg: 58), today: today, calendar: calendar)
        #expect(throws: WeightRepositoryError.futureDate) {
            try WeightRules.validate(WeightRecord(day: day("2026-10-03"), kg: 58), today: today, calendar: calendar)
        }
    }

    @Test func sameDayDuplicatesKeepTheFirstIdWithItsOwnWeight() {
        let a = WeightRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"), kg: 58.0)
        let b = WeightRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: date("2026-10-01T09:00:00Z"), kg: 58.4)
        let other = WeightRecord(day: day("2026-09-24"), kg: 57.5)
        let result = WeightRules.mergingDuplicates([b, other, a], calendar: calendar)
        #expect(result.entries == [other, a])
        #expect(result.removedIDs == [b.id])
    }

    @Test func pickerRangeRunsFromTheLastPeriodToToday() {
        // Due 2027-01-19 → first day of the last period 2026-04-14.
        let range = WeightRules.dayRange(dueDate: date("2027-01-19T12:00:00Z"), now: today, calendar: calendar)
        #expect(range.lowerBound == day("2026-04-14"))
        #expect(range.upperBound == date("2026-10-02T23:59:59Z"))
    }

    @Test func decimalEntryAcceptsCommaAndDotAndChecksTheRange() {
        #expect(DecimalEntry(text: "56,2", range: WeightRules.kgRange) == .valid(56.2))
        #expect(DecimalEntry(text: " 56.24 ", range: WeightRules.kgRange) == .valid(56.2))
        #expect(DecimalEntry(text: "", range: WeightRules.kgRange) == .empty)
        #expect(DecimalEntry(text: "abc", range: WeightRules.kgRange) == .invalid)
        #expect(DecimalEntry(text: "250", range: WeightRules.kgRange) == .invalid)
        #expect(DecimalEntry(text: "160", range: MaternalProfile.heightRange) == .valid(160))
        #expect(DecimalEntry(text: "119,9", range: MaternalProfile.heightRange) == .invalid)
    }
}
