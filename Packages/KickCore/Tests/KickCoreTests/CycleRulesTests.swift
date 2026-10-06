import Foundation
import Testing
@testable import KickCore

struct CycleRulesTests {
    let calendar = utcCalendar
    let today = date("2026-10-02T12:00:00Z")

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    @Test func normalizingMovesDatesToTheStartOfTheDay() {
        let period = CycleRules.normalized(
            PeriodRecord(startDate: date("2026-09-03T18:30:00Z"), endDate: date("2026-09-07T07:00:00Z")), calendar: calendar
        )
        #expect(period.startDate == day("2026-09-03"))
        #expect(period.endDate == day("2026-09-07"))
        let log = CycleRules.normalized(CycleLogRecord(day: date("2026-10-01T22:00:00Z"), note: "  tired \n"), calendar: calendar)
        #expect(log.day == day("2026-10-01"))
        #expect(log.note == "tired")
    }

    @Test func openPeriodCoversUpToTodayAtMostTenDays() {
        let recent = PeriodRecord(startDate: day("2026-09-30"))
        #expect(CycleRules.dayRange(of: recent, today: today, calendar: calendar) == day("2026-09-30")...day("2026-10-02"))
        let long = PeriodRecord(startDate: day("2026-09-10"))
        #expect(CycleRules.dayRange(of: long, today: today, calendar: calendar) == day("2026-09-10")...day("2026-09-19"))
        let closed = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        #expect(CycleRules.dayRange(of: closed, today: today, calendar: calendar) == day("2026-09-03")...day("2026-09-07"))
    }

    @Test func futurePeriodsAreRejected() {
        #expect(throws: CycleRepositoryError.futureDate) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-10-03")), existing: [], today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.futureDate) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-30"), endDate: day("2026-10-03")), existing: [], today: today, calendar: calendar)
        }
    }

    @Test func periodStartingTodayIsAllowed() throws {
        try CycleRules.validate(PeriodRecord(startDate: date("2026-10-02T23:00:00Z")), existing: [], today: today, calendar: calendar)
    }

    @Test func endBeforeStartIsRejected() {
        #expect(throws: CycleRepositoryError.endBeforeStart) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-10"), endDate: day("2026-09-08")), existing: [], today: today, calendar: calendar)
        }
    }

    @Test func overlappingPeriodsAreRejected() {
        let existing = [PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))]
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-07")), existing: existing, today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-03")), existing: existing, today: today, calendar: calendar)
        }
    }

    @Test func startingWhileAnotherPeriodIsOpenOverlaps() {
        let existing = [PeriodRecord(startDate: day("2026-09-29"))]
        #expect(throws: CycleRepositoryError.overlapsExistingPeriod) {
            try CycleRules.validate(PeriodRecord(startDate: day("2026-10-02")), existing: existing, today: today, calendar: calendar)
        }
    }

    @Test func adjacentPeriodsAndEditingItselfAreAllowed() throws {
        let existing = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        try CycleRules.validate(PeriodRecord(startDate: day("2026-09-08")), existing: [existing], today: today, calendar: calendar)
        var edited = existing
        edited.endDate = day("2026-09-08")
        try CycleRules.validate(edited, existing: [existing], today: today, calendar: calendar)
    }

    @Test func logsInTheFutureOrWithImplausibleTemperaturesAreRejected() throws {
        #expect(throws: CycleRepositoryError.futureDate) {
            try CycleRules.validate(CycleLogRecord(day: day("2026-10-03")), today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.invalidTemperature) {
            try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 34.9), today: today, calendar: calendar)
        }
        #expect(throws: CycleRepositoryError.invalidTemperature) {
            try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 38.6), today: today, calendar: calendar)
        }
        try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 35.0), today: today, calendar: calendar)
        try CycleRules.validate(CycleLogRecord(day: day("2026-10-02"), bbtCelsius: 38.5), today: today, calendar: calendar)
    }

    @Test func emptyLogIsDetected() {
        #expect(CycleLogRecord(day: today, note: "  ").isEmpty)
        #expect(!CycleLogRecord(day: today, mucus: .dry).isEmpty)
    }

    @Test func flowMoodsSymptomsAndUnknownValuesAreNotEmpty() {
        #expect(!CycleLogRecord(day: today, flow: .noFlow).isEmpty)
        #expect(!CycleLogRecord(day: today, moods: [.calm]).isEmpty)
        #expect(!CycleLogRecord(day: today, symptoms: [.nausea]).isEmpty)
        #expect(!CycleLogRecord(day: today, unknownMoodsRaw: ["excited"]).isEmpty)
        #expect(!CycleLogRecord(day: today, unknownSymptomsRaw: ["hiccups"]).isEmpty)
    }

    @Test func normalizingOrdersMoodsAndSymptoms() {
        let log = CycleRules.normalized(
            CycleLogRecord(day: today, moods: [.tired, .happy, .tired], symptoms: [.nausea, .cramps]),
            calendar: calendar
        )
        #expect(log.moods == [.happy, .tired])
        #expect(log.symptoms == [.cramps, .nausea])
    }

    @Test func sameDayLogsUniteMoodsAndSymptomsAndKeepTheHeavierFlow() {
        let a = CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"),
            flow: .light, moods: [.tired], symptoms: [.cramps], unknownMoodsRaw: ["excited"]
        )
        let b = CycleLogRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: day("2026-10-01"),
            flow: .heavy, moods: [.happy, .tired], symptoms: [.nausea],
            unknownMoodsRaw: ["excited", "bored"], unknownSymptomsRaw: ["hiccups"]
        )
        let result = CycleRules.mergingDuplicates([b, a], calendar: calendar)
        #expect(result.logs == [CycleLogRecord(
            id: a.id, day: day("2026-10-01"), flow: .heavy, moods: [.happy, .tired], symptoms: [.cramps, .nausea],
            unknownMoodsRaw: ["excited", "bored"], unknownSymptomsRaw: ["hiccups"]
        )])
        #expect(result.removedIDs == [b.id])
    }

    @Test func aFlowOnlyOnOneCopySurvivesTheMerge() {
        let a = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"), note: "x")
        let b = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: day("2026-10-01"), flow: .noFlow)
        #expect(CycleRules.mergingDuplicates([a, b], calendar: calendar).logs.first?.flow == .noFlow)
    }

    @Test func withIDKeepsEveryValue() {
        let log = CycleLogRecord(day: today, lh: .positive, flow: .medium, moods: [.calm], unknownSymptomsRaw: ["hiccups"])
        let id = UUID()
        let copy = log.withID(id)
        #expect(copy.id == id)
        #expect(copy == CycleLogRecord(id: id, day: today, lh: .positive, flow: .medium, moods: [.calm], unknownSymptomsRaw: ["hiccups"]))
    }

    @Test func overlappingDuplicatePeriodsAreMergedKeepingTheEnd() {
        let open = PeriodRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, startDate: day("2026-09-03"))
        let closed = PeriodRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, startDate: day("2026-09-03"), endDate: day("2026-09-07"))
        let earlier = PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10"))
        let result = CycleRules.mergingDuplicates([open, earlier, closed], calendar: calendar)
        #expect(result.periods == [earlier, closed])
        #expect(result.removedIDs == [open.id])
    }

    @Test func mergedPeriodSpansBothCopies() {
        let first = PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-06"))
        let second = PeriodRecord(startDate: day("2026-09-05"), endDate: day("2026-09-08"))
        let result = CycleRules.mergingDuplicates([second, first], calendar: calendar)
        #expect(result.periods == [PeriodRecord(id: first.id, startDate: day("2026-09-03"), endDate: day("2026-09-08"))])
        #expect(result.removedIDs == [second.id])
    }

    @Test func separatePeriodsAreLeftAlone() {
        let periods = [
            PeriodRecord(startDate: day("2026-08-06"), endDate: day("2026-08-10")),
            PeriodRecord(startDate: day("2026-09-03")),
        ]
        let result = CycleRules.mergingDuplicates(periods, calendar: calendar)
        #expect(result.periods == periods)
        #expect(result.removedIDs.isEmpty)
    }

    @Test func sameDayLogsAreMerged() {
        let a = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, day: day("2026-10-01"), lh: .negative, note: "Tired")
        let b = CycleLogRecord(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, day: date("2026-10-01T08:00:00Z"), lh: .positive, bbtCelsius: 36.5, mucus: .eggWhite, note: "Tired")
        let other = CycleLogRecord(day: day("2026-09-30"), note: "Cramps")
        let result = CycleRules.mergingDuplicates([b, other, a], calendar: calendar)
        #expect(result.logs == [
            other,
            CycleLogRecord(id: a.id, day: day("2026-10-01"), lh: .positive, bbtCelsius: 36.5, mucus: .eggWhite, note: "Tired"),
        ])
        #expect(result.removedIDs == [b.id])
    }

    @Test func assumedPeriodIsClosedOnceItsTypicalLengthHasPassed() {
        let past = CycleRules.assumedPeriod(startingOn: date("2026-09-20T15:00:00Z"), typicalLength: 5, today: today, calendar: calendar)
        #expect(past.startDate == day("2026-09-20"))
        #expect(past.endDate == day("2026-09-24"))
        // 09-28 + 5 days → 10-02 is today: still going on.
        let ongoing = CycleRules.assumedPeriod(startingOn: day("2026-09-28"), typicalLength: 5, today: today, calendar: calendar)
        #expect(ongoing.endDate == nil)
        let yesterday = CycleRules.assumedPeriod(startingOn: day("2026-10-01"), typicalLength: 2, today: today, calendar: calendar)
        #expect(yesterday.endDate == nil)
    }

    @Test func lastPeriodPickerAllowsThePastYearUpToToday() {
        let range = CycleRules.lastPeriodRange(now: today, calendar: calendar)
        #expect(range.lowerBound == day("2025-10-02"))
        #expect(range.upperBound == date("2026-10-02T23:59:59Z"))
    }

    @Test func temperatureEntryAcceptsBothDecimalSeparators() {
        #expect(TemperatureEntry(text: "36.5") == .valid(36.5))
        #expect(TemperatureEntry(text: " 36,55 ") == .valid(36.55))
        #expect(TemperatureEntry(text: "35") == .valid(35.0))
        #expect(TemperatureEntry(text: "38.5") == .valid(38.5))
        #expect(TemperatureEntry(text: "") == .empty)
        #expect(TemperatureEntry(text: "  ") == .empty)
    }

    @Test func temperatureEntryRejectsTextAndImplausibleValues() {
        #expect(TemperatureEntry(text: "abc") == .invalid)
        #expect(TemperatureEntry(text: "34.9") == .invalid)
        #expect(TemperatureEntry(text: "38.51") == .invalid)
        #expect(TemperatureEntry(text: "98.6") == .invalid)
        #expect(TemperatureEntry(text: "36.5.1") == .invalid)
    }
}
