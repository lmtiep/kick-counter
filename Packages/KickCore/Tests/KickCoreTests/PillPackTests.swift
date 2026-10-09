import Foundation
import Testing
@testable import KickCore

/// Phase 17 spec §3.3: where a day falls in the pack.
struct PillPackTests {
    private let start = date("2026-10-01T00:00:00Z")

    private func pack(_ type: PillPackType, start: Date? = nil, calendar: Calendar = utcCalendar) -> PillPack {
        PillPack(type: type, start: start ?? self.start, calendar: calendar)
    }

    private func day(_ offset: Int, from base: Date? = nil) -> Date {
        utcCalendar.date(byAdding: .day, value: offset, to: base ?? start)!
    }

    @Test func typesAndPillCounts() {
        #expect(PillPackType(rawValue: "21+7") == .withBreak)
        #expect(PillPackType(rawValue: "28") == .continuous)
        #expect(PillPackType.withBreak.pillCount == 21)
        #expect(PillPackType.continuous.pillCount == 28)
    }

    @Test func dayInPackCountsFromTheStartAndRepeatsEvery28Days() {
        let pack = pack(.withBreak)
        #expect(pack.dayInPack(on: start) == 1)
        #expect(pack.dayInPack(on: start.addingTimeInterval(23 * 3600)) == 1)
        #expect(pack.dayInPack(on: day(20)) == 21)
        #expect(pack.dayInPack(on: day(21)) == 22)
        #expect(pack.dayInPack(on: day(27)) == 28)
        #expect(pack.dayInPack(on: day(28)) == 1)
        #expect(pack.dayInPack(on: day(28 * 3 + 4)) == 5)
    }

    @Test func daysBeforeTheStartAreNotInThePack() {
        let pack = pack(.continuous)
        #expect(pack.dayInPack(on: day(-1)) == nil)
        #expect(!pack.isPillDay(on: day(-1)))
        #expect(pack.pillNumber(on: day(-1)) == nil)
    }

    @Test func theStartIsTakenAtStartOfDay() {
        let pack = PillPack(type: .withBreak, start: date("2026-10-01T18:30:00Z"), calendar: utcCalendar)
        #expect(pack.start == start)
        #expect(pack.dayInPack(on: date("2026-10-01T02:00:00Z")) == 1)
    }

    @Test func aBreakPackHasNoPillOnDays22To28() {
        let pack = pack(.withBreak)
        for offset in 0..<21 {
            #expect(pack.isPillDay(on: day(offset)), "day \(offset + 1)")
            #expect(pack.pillNumber(on: day(offset)) == offset + 1)
        }
        for offset in 21..<28 {
            #expect(!pack.isPillDay(on: day(offset)), "day \(offset + 1)")
            #expect(pack.pillNumber(on: day(offset)) == nil)
        }
        // The next pack starts with pill 1 again.
        #expect(pack.isPillDay(on: day(28)))
        #expect(pack.pillNumber(on: day(28)) == 1)
        #expect(pack.pillCount == 21)
    }

    @Test func aContinuousPackHasAPillEveryDay() {
        let pack = pack(.continuous)
        for offset in 0..<56 {
            #expect(pack.isPillDay(on: day(offset)))
            #expect(pack.pillNumber(on: day(offset)) == offset % 28 + 1)
        }
        #expect(pack.pillCount == 28)
    }

    @Test func nextPackStartIsTheFollowingMultipleOf28Days() {
        let pack = pack(.withBreak)
        #expect(pack.nextPackStart(after: start) == day(28))
        #expect(pack.nextPackStart(after: day(21)) == day(28))
        #expect(pack.nextPackStart(after: day(27)) == day(28))
        #expect(pack.nextPackStart(after: day(28)) == day(56))
        #expect(pack.nextPackStart(after: day(-5)) == start)
    }

    @Test func monthBoundary() {
        let pack = pack(.withBreak, start: date("2026-10-20T00:00:00Z"))
        #expect(pack.dayInPack(on: date("2026-11-01T12:00:00Z")) == 13)
        #expect(pack.nextPackStart(after: date("2026-11-12T00:00:00Z")) == date("2026-11-17T00:00:00Z"))
        #expect(!pack.isPillDay(on: date("2026-11-10T00:00:00Z")))
        #expect(pack.isPillDay(on: date("2026-11-09T00:00:00Z")))
    }

    @Test func daylightSavingBoundaryKeepsWholeDays() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        // Clocks go back on 1 Nov 2026.
        let start = try #require(newYork.date(from: DateComponents(year: 2026, month: 10, day: 25)))
        let pack = PillPack(type: .continuous, start: start, calendar: newYork)
        let after = try #require(newYork.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 30)))
        #expect(pack.dayInPack(on: after) == 9)
        let dates = pack.upcomingReminderDates(from: start, count: 10, hour: 21, minute: 0)
        #expect(dates.count == 10)
        for reminder in dates {
            let parts = newYork.dateComponents([.hour, .minute], from: reminder)
            #expect(parts.hour == 21 && parts.minute == 0)
        }
    }

    @Test func upcomingReminderDatesSkipTheBreakWeek() {
        let pack = pack(.withBreak)
        // From pill 19: pills 19, 20, 21, then the break, then pills 1, 2 of the next pack.
        let dates = pack.upcomingReminderDates(from: day(18).addingTimeInterval(8 * 3600), count: 5, hour: 21, minute: 15)
        #expect(dates == [
            day(18).addingTimeInterval(21 * 3600 + 900),
            day(19).addingTimeInterval(21 * 3600 + 900),
            day(20).addingTimeInterval(21 * 3600 + 900),
            day(28).addingTimeInterval(21 * 3600 + 900),
            day(29).addingTimeInterval(21 * 3600 + 900),
        ])
    }

    @Test func upcomingReminderDatesInTheBreakStartWithTheNextPack() {
        let pack = pack(.withBreak)
        let dates = pack.upcomingReminderDates(from: day(23), count: 2, hour: 21, minute: 0)
        #expect(dates == [day(28).addingTimeInterval(21 * 3600), day(29).addingTimeInterval(21 * 3600)])
    }

    @Test func upcomingReminderDatesBeforeTheStartBeginAtTheStart() {
        let pack = pack(.continuous)
        let dates = pack.upcomingReminderDates(from: day(-3), count: 1, hour: 8, minute: 0)
        #expect(dates == [start.addingTimeInterval(8 * 3600)])
    }
}

struct PillReminderSettingsTests {
    @Test func defaultsWhenNothingIsStored() {
        let settings = PillReminderSettings.load(from: makeTestDefaults())
        #expect(settings == PillReminderSettings(enabled: false, packType: .withBreak, packStart: nil, hour: 21, minute: 0))
    }

    @Test func saveThenLoadRoundTrips() {
        let defaults = makeTestDefaults()
        let settings = PillReminderSettings(
            enabled: true, packType: .continuous, packStart: date("2026-10-01T00:00:00Z"), hour: 7, minute: 45
        )
        settings.save(to: defaults)
        #expect(PillReminderSettings.load(from: defaults) == settings)
        #expect(defaults.string(forKey: SettingsKey.pillPackType) == "28")
        #expect(defaults.double(forKey: SettingsKey.pillPackStart) == date("2026-10-01T00:00:00Z").timeIntervalSince1970)
        #expect(defaults.integer(forKey: SettingsKey.pillReminderHour) == 7)
    }

    @Test func clearingTheStartRemovesTheKey() {
        let defaults = makeTestDefaults()
        PillReminderSettings(enabled: true, packType: .withBreak, packStart: date("2026-10-01T00:00:00Z"), hour: 21, minute: 0)
            .save(to: defaults)
        PillReminderSettings(enabled: true, packType: .withBreak, packStart: nil, hour: 21, minute: 0).save(to: defaults)
        #expect(defaults.object(forKey: SettingsKey.pillPackStart) == nil)
    }

    @Test func outOfRangeTimesAndUnknownTypesFallBack() {
        let defaults = makeTestDefaults()
        defaults.set("35", forKey: SettingsKey.pillPackType)
        defaults.set(25, forKey: SettingsKey.pillReminderHour)
        defaults.set(-1, forKey: SettingsKey.pillReminderMinute)
        let settings = PillReminderSettings.load(from: defaults)
        #expect(settings.packType == .withBreak)
        #expect(settings.hour == 21)
        #expect(settings.minute == 0)
    }

    @Test func thePackNeedsAStart() {
        var settings = PillReminderSettings()
        #expect(settings.pack(calendar: utcCalendar) == nil)
        settings.packStart = date("2026-10-01T09:00:00Z")
        #expect(settings.pack(calendar: utcCalendar)?.start == date("2026-10-01T00:00:00Z"))
    }

    @Test func everyPillKeyIsOwnedAndBackedUpWithItsType() {
        let keys = [
            SettingsKey.pillReminderEnabled, SettingsKey.pillPackType, SettingsKey.pillPackStart,
            SettingsKey.pillReminderHour, SettingsKey.pillReminderMinute,
        ]
        for key in keys {
            #expect(AppDataReset.ownedKeys.contains(key), "\(key)")
        }
        #expect(BackupSettings.table[SettingsKey.pillReminderEnabled] == .bool)
        #expect(BackupSettings.table[SettingsKey.pillPackType] == .string)
        #expect(BackupSettings.table[SettingsKey.pillPackStart] == .double)
        #expect(BackupSettings.table[SettingsKey.pillReminderHour] == .int)
        #expect(BackupSettings.table[SettingsKey.pillReminderMinute] == .int)
    }

    @Test func backupRoundTripsThePillSettings() {
        let source = makeTestDefaults()
        PillReminderSettings(enabled: true, packType: .continuous, packStart: date("2026-10-01T00:00:00Z"), hour: 8, minute: 30)
            .save(to: source)
        let target = makeTestDefaults()
        BackupSettings.restore(BackupSettings.read(from: source), backupCreatedAt: date("2026-10-09T00:00:00Z"), to: target)
        #expect(PillReminderSettings.load(from: target) == PillReminderSettings.load(from: source))
    }
}
