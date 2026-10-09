import Foundation
import Testing
@testable import KickCore

struct BackupSettingsTests {
    /// The table covers `ownedKeys` minus the partner keys and onboarding, exactly,
    /// so a key added later cannot be forgotten by the backup.
    @Test func tableCoversOwnedKeysMinusTheExclusions() {
        let expected = Set(AppDataReset.ownedKeys).subtracting([
            SettingsKey.partnerSkippedOnboarding,
            SettingsKey.partnerPublishedSnapshot,
            SettingsKey.partnerCachedSnapshot,
            SettingsKey.partnerPendingZoneDeletion,
            SettingsKey.hasCompletedOnboarding,
        ])
        #expect(Set(BackupSettings.table.keys) == expected)
        #expect(BackupSettings.excludedKeys.isDisjoint(with: BackupSettings.table.keys))
        #expect(Set(BackupSettings.table.keys).union(BackupSettings.excludedKeys) == Set(AppDataReset.ownedKeys))
    }

    @Test func lastBackupAtIsOwnedAndADate() {
        #expect(AppDataReset.ownedKeys.contains(SettingsKey.lastBackupAt))
        #expect(BackupSettings.table[SettingsKey.lastBackupAt] == .date)
    }

    @Test func tableUsesTheTypesTheAppStores() {
        #expect(BackupSettings.table[SettingsKey.reminderEnabled] == .bool)
        #expect(BackupSettings.table[SettingsKey.reminderHour] == .int)
        #expect(BackupSettings.table[SettingsKey.typicalCycleLength] == .int)
        #expect(BackupSettings.table[SettingsKey.dueDate] == .double)
        #expect(BackupSettings.table[SettingsKey.maternalHeightCm] == .double)
        #expect(BackupSettings.table[SettingsKey.appMode] == .string)
        #expect(BackupSettings.table[SettingsKey.appLanguage] == .string)
    }

    @Test func readTakesOnlyStoredTableKeys() {
        let defaults = makeTestDefaults()
        defaults.set(true, forKey: SettingsKey.reminderEnabled)
        defaults.set(21, forKey: SettingsKey.reminderHour)
        defaults.set(1_800_000_000.5, forKey: SettingsKey.dueDate)
        defaults.set("tryingToConceive", forKey: SettingsKey.appMode)
        defaults.set(date("2026-10-01T10:00:00Z"), forKey: SettingsKey.lastBackupAt)
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        defaults.set(Data([1, 2]), forKey: SettingsKey.partnerCachedSnapshot)
        defaults.set("x", forKey: "someOtherAppKey")

        let values = BackupSettings.read(from: defaults)

        #expect(values == [
            SettingsKey.reminderEnabled: .bool(true),
            SettingsKey.reminderHour: .int(21),
            SettingsKey.dueDate: .double(1_800_000_000.5),
            SettingsKey.appMode: .string("tryingToConceive"),
            SettingsKey.lastBackupAt: .date(date("2026-10-01T10:00:00Z")),
        ])
    }

    @Test func restoreReplacesOwnedKeysAndCompletesOnboarding() {
        let defaults = makeTestDefaults()
        defaults.set(true, forKey: SettingsKey.cycleShowsFertilityTests)
        defaults.set(Data([1]), forKey: SettingsKey.partnerPublishedSnapshot)
        defaults.set(false, forKey: SettingsKey.hasCompletedOnboarding)
        defaults.set("keep", forKey: "someOtherAppKey")

        BackupSettings.restore([
            SettingsKey.reminderEnabled: .bool(true),
            SettingsKey.reminderMinute: .int(30),
            SettingsKey.maternalPreWeightKg: .double(52.5),
            SettingsKey.appMode: .string("pregnant"),
            SettingsKey.lastBackupAt: .date(date("2026-10-01T10:00:00Z")),
            // Not in the table: never written.
            SettingsKey.partnerSkippedOnboarding: .bool(true),
            "someOtherAppKey": .string("overwritten"),
            // Wrong type for the key: never written.
            SettingsKey.reminderHour: .string("late"),
        ], to: defaults)

        #expect(defaults.bool(forKey: SettingsKey.reminderEnabled))
        #expect(defaults.integer(forKey: SettingsKey.reminderMinute) == 30)
        #expect(defaults.double(forKey: SettingsKey.maternalPreWeightKg) == 52.5)
        #expect(defaults.string(forKey: SettingsKey.appMode) == "pregnant")
        #expect(defaults.object(forKey: SettingsKey.lastBackupAt) as? Date == date("2026-10-01T10:00:00Z"))
        #expect(defaults.object(forKey: SettingsKey.cycleShowsFertilityTests) == nil)
        #expect(defaults.object(forKey: SettingsKey.partnerPublishedSnapshot) == nil)
        #expect(defaults.object(forKey: SettingsKey.partnerSkippedOnboarding) == nil)
        #expect(defaults.object(forKey: SettingsKey.reminderHour) == nil)
        #expect(defaults.bool(forKey: SettingsKey.hasCompletedOnboarding))
        #expect(defaults.string(forKey: "someOtherAppKey") == "keep")
    }

    @Test func readThenRestoreRoundTrips() {
        let source = makeTestDefaults()
        source.set(false, forKey: SettingsKey.kickHapticsEnabled)
        source.set(30, forKey: SettingsKey.typicalCycleLength)
        source.set("vi", forKey: SettingsKey.appLanguage)
        source.set(165.0, forKey: SettingsKey.maternalHeightCm)
        let target = makeTestDefaults()

        BackupSettings.restore(BackupSettings.read(from: source), to: target)

        #expect(BackupSettings.read(from: target) == BackupSettings.read(from: source))
        #expect(target.object(forKey: SettingsKey.kickHapticsEnabled) as? Bool == false)
    }
}

struct BackupSummaryTests {
    @Test func countsDatesAndMode() {
        let summary = BackupCodecTests.sampleDocument().summary
        #expect(summary.createdAt == BackupCodecTests.created)
        #expect(summary.sessions == 1)
        #expect(summary.periods == 2)
        #expect(summary.cycleLogs == 1)
        #expect(summary.weights == 1)
        #expect(summary.appointments == 1)
        #expect(summary.mode == .pregnant)
        #expect(summary.dateRange == date("2026-09-01T00:00:00Z")...date("2026-10-20T08:00:00Z"))
        #expect(!summary.isEmpty)
    }

    @Test func missingModeMeansPregnantAndEmptyHasNoRange() {
        let document = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.0",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [],
            settings: [:]
        )
        #expect(document.summary.mode == .pregnant)
        #expect(document.summary.dateRange == nil)
        #expect(document.summary.isEmpty)
    }

    @Test func modeComesFromTheSettings() {
        let document = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.0",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [],
            settings: [SettingsKey.appMode: .string("tryingToConceive")]
        )
        #expect(document.summary.mode == .tryingToConceive)
    }
}
