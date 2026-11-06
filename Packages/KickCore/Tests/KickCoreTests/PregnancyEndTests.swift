import Foundation
import Testing
@testable import KickCore

/// 1.1 item 4 (spec §4.2, §4.6): the ended state in App Group defaults and the
/// pregnancy's date range.
struct PregnancyEndTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    /// Midnight of that day in Asia/Ho_Chi_Minh (UTC+7).
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00+07:00") }

    @Test func stateRoundTripsThroughDefaults() {
        let defaults = makeTestDefaults()
        #expect(PregnancyEndState.load(from: defaults) == nil)
        let id = UUID()
        let state = PregnancyEndState(
            branch: .loss, endDate: day("2026-10-20"), rangeStart: day("2026-02-01"), firstPeriodConfirmedID: id, calendar: calendar
        )
        state.save(to: defaults)
        #expect(PregnancyEndState.load(from: defaults) == state)

        let paused = PregnancyEndState(branch: .birth, endDate: day("2026-11-01"))
        paused.save(to: defaults)
        #expect(PregnancyEndState.load(from: defaults) == paused)
        #expect(defaults.object(forKey: SettingsKey.pregnancyEndFirstPeriodID) == nil)
    }

    @Test func clearRemovesEveryKey() {
        let defaults = makeTestDefaults()
        PregnancyEndState(branch: .birth, endDate: day("2026-10-20"), firstPeriodConfirmedID: UUID()).save(to: defaults)
        PregnancyEndState.saveDeclinedPeriods([UUID(), UUID()], to: defaults)
        #expect(PregnancyEndState.declinedPeriods(in: defaults).count == 2)
        PregnancyEndState.clear(defaults)
        #expect(PregnancyEndState.load(from: defaults) == nil)
        for key in PregnancyEndState.keys {
            #expect(defaults.object(forKey: key) == nil, "\(key)")
        }
        #expect(PregnancyEndState.keys.contains(SettingsKey.pregnancyEndDeclinedPeriods))
        #expect(PregnancyEndState.keys.contains(SettingsKey.pregnancyEndRangeStart))
    }

    @Test func unknownBranchLoadsAsNil() {
        let defaults = makeTestDefaults()
        defaults.set("other", forKey: SettingsKey.pregnancyEndBranch)
        defaults.set(day("2026-10-20").timeIntervalSince1970, forKey: SettingsKey.pregnancyEndDate)
        #expect(PregnancyEndState.load(from: defaults) == nil)
    }

    @Test func endDateIsStoredAsTheStartOfTheDay() {
        let state = PregnancyEndState(branch: .loss, endDate: date("2026-10-20T15:30:00+07:00"), calendar: calendar)
        #expect(state.endDate == day("2026-10-20"))
    }

    @Test func rangeUsesLMPWhenPresent() throws {
        let profile = PregnancyProfile(source: .lmp, dueDate: day("2027-04-07"), lmpDate: day("2026-07-01"))
        let range = try #require(PregnancyRange.make(
            profile: profile, endDate: day("2026-09-30"), fallbackStarts: [day("2026-05-01")], calendar: calendar
        ))
        #expect(range.lowerBound == day("2026-07-01"))
    }

    @Test func rangeUsesDueDateMinus280() throws {
        let profile = PregnancyProfile(source: .dueDate, dueDate: day("2027-04-07"), lmpDate: nil)
        let range = try #require(PregnancyRange.make(
            profile: profile, endDate: day("2026-09-30"), fallbackStarts: [], calendar: calendar
        ))
        #expect(range.lowerBound == day("2026-07-01"))
    }

    @Test func rangeFallsBackToEarliestRecord() throws {
        let profile = PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil)
        let range = try #require(PregnancyRange.make(
            profile: profile, endDate: day("2026-09-30"),
            fallbackStarts: [date("2026-08-10T09:00:00+07:00"), date("2026-08-02T21:00:00+07:00")],
            calendar: calendar
        ))
        #expect(range.lowerBound == day("2026-08-02"))
    }

    @Test func rangeIsNilWithNoDatesAndNoRecords() {
        let profile = PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil)
        #expect(PregnancyRange.make(profile: profile, endDate: day("2026-09-30"), fallbackStarts: [], calendar: calendar) == nil)
    }

    @Test func rangeEndIsTheEndDay() throws {
        let profile = PregnancyProfile(source: .dueDate, dueDate: day("2027-04-07"), lmpDate: nil)
        let range = try #require(PregnancyRange.make(
            profile: profile, endDate: date("2026-09-30T08:00:00+07:00"), fallbackStarts: [], calendar: calendar
        ))
        #expect(range.contains(date("2026-09-30T23:59:00+07:00")))
        #expect(!range.contains(day("2026-10-01")))
    }

    @Test func rangeStartNeverAfterTheEnd() throws {
        // A due date entered much later than the real one: the range still holds the end day.
        let profile = PregnancyProfile(source: .dueDate, dueDate: day("2027-12-01"), lmpDate: nil)
        let range = try #require(PregnancyRange.make(
            profile: profile, endDate: day("2026-09-30"), fallbackStarts: [], calendar: calendar
        ))
        #expect(range.lowerBound == day("2026-09-30"))
    }
}
