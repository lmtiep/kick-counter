import Foundation
import Testing
@testable import KickCore

/// 1.1 spec "Reminder": the in-app "Đã lâu chưa sao lưu" card.
struct BackupReminderPolicyTests {
    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = utcCalendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: hour))!
        return utcCalendar.date(byAdding: .day, value: offset, to: base)!
    }

    private func shows(last: Int? = nil, firstUse: Int? = nil, snoozed: Int? = nil, now: Int, hour: Int = 12) -> Bool {
        BackupReminderPolicy.shouldShow(
            BackupReminderState(lastBackupAt: last.map { day($0) }, firstUseAt: firstUse.map { day($0) }, snoozedAt: snoozed.map { day($0) }),
            now: day(now, hour: hour),
            calendar: utcCalendar
        )
    }

    // MARK: - Backed up before

    @Test func aBackupThirtyDaysOldShowsTheCard() {
        #expect(!shows(last: 0, firstUse: 0, now: 29))
        #expect(shows(last: 0, firstUse: 0, now: 30))
        #expect(shows(last: 0, firstUse: 0, now: 200))
    }

    /// Whole calendar days: 23:59 on day 29 is still day 29.
    @Test func daysAreCalendarDays() {
        #expect(!shows(last: 0, firstUse: 0, now: 29, hour: 23))
        #expect(shows(last: 0, firstUse: 0, now: 30, hour: 0))
    }

    @Test func aRecentBackupHidesTheCardWhateverTheFirstUse() {
        #expect(!shows(last: 100, firstUse: 0, now: 110))
    }

    /// A clock set back must not show it either.
    @Test func aBackupInTheFutureDoesNotShowTheCard() {
        #expect(!shows(last: 40, firstUse: 0, now: 10))
    }

    // MARK: - Never backed up

    @Test func neverBackedUpShowsAfterFourteenDaysOfUse() {
        #expect(!shows(firstUse: 0, now: 13))
        #expect(shows(firstUse: 0, now: 14))
    }

    @Test func neverBackedUpWithoutAFirstUseDateNeverShows() {
        #expect(!shows(now: 1000))
    }

    // MARK: - "Để sau"

    @Test func snoozingHidesItForFourteenDays() {
        #expect(!shows(last: 0, firstUse: 0, snoozed: 40, now: 40))
        #expect(!shows(last: 0, firstUse: 0, snoozed: 40, now: 53))
        #expect(shows(last: 0, firstUse: 0, snoozed: 40, now: 54))
        #expect(!shows(firstUse: 0, snoozed: 14, now: 27))
        #expect(shows(firstUse: 0, snoozed: 14, now: 28))
    }

    /// Snoozed while the backup was still recent: no effect once it is old.
    @Test func anOldSnoozeDoesNotHideANewlyStaleBackup() {
        #expect(shows(last: 50, firstUse: 0, snoozed: 20, now: 80))
    }

    // MARK: - Store

    @Test func theStoreRemembersTheFirstUseOnceAndTheSnooze() {
        let defaults = makeTestDefaults()
        #expect(BackupReminderStore.load(from: defaults) == BackupReminderState())

        BackupReminderStore.recordUse(in: defaults, now: day(0))
        BackupReminderStore.recordUse(in: defaults, now: day(5))
        defaults.set(day(3), forKey: SettingsKey.lastBackupAt)
        BackupReminderStore.snooze(in: defaults, now: day(7))

        #expect(BackupReminderStore.load(from: defaults) == BackupReminderState(
            lastBackupAt: day(3), firstUseAt: day(0), snoozedAt: day(7)
        ))
    }

    /// The keys belong to this phone: delete-all clears them, a backup never carries them.
    @Test func theKeysAreOwnedAndNotBackedUp() {
        for key in [SettingsKey.backupFirstUseAt, SettingsKey.backupReminderSnoozedAt] {
            #expect(AppDataReset.ownedKeys.contains(key))
            #expect(BackupSettings.excludedKeys.contains(key))
            #expect(BackupSettings.table[key] == nil)
        }
    }

    @Test func aRestoreLeavesTheReminderQuietForThirtyDays() {
        let defaults = makeTestDefaults()
        BackupReminderStore.recordUse(in: defaults, now: day(0))
        BackupReminderStore.snooze(in: defaults, now: day(1))
        BackupSettings.restore([:], backupCreatedAt: day(60), to: defaults)
        let state = BackupReminderStore.load(from: defaults)
        #expect(state.snoozedAt == nil)
        #expect(state.lastBackupAt == day(60))
        #expect(!BackupReminderPolicy.shouldShow(state, now: day(89), calendar: utcCalendar))
    }
}
