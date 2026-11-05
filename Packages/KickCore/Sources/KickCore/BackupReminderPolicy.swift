import Foundation

/// What the phone remembers for the backup reminder. Only dates.
public struct BackupReminderState: Equatable, Sendable {
    public var lastBackupAt: Date?
    public var firstUseAt: Date?
    public var snoozedAt: Date?

    public init(lastBackupAt: Date? = nil, firstUseAt: Date? = nil, snoozedAt: Date? = nil) {
        self.lastBackupAt = lastBackupAt
        self.firstUseAt = firstUseAt
        self.snoozedAt = snoozedAt
    }
}

/// When Profile shows "Đã lâu chưa sao lưu" (1.1 spec "Reminder"; in the app only,
/// never a notification). Whole calendar days, as `ReviewPromptPolicy` counts them.
public enum BackupReminderPolicy {
    /// A backup this many days old is due again.
    public static let staleAfterDays = 30
    /// Never backed up: the card waits this long after the first use.
    public static let firstReminderAfterDays = 14
    /// "Để sau" hides the card this long.
    public static let snoozeDays = 14

    public static func shouldShow(_ state: BackupReminderState, now: Date, calendar: Calendar) -> Bool {
        if let snoozed = state.snoozedAt, days(from: snoozed, to: now, calendar) < snoozeDays { return false }
        if let last = state.lastBackupAt {
            return days(from: last, to: now, calendar) >= staleAfterDays
        }
        guard let firstUse = state.firstUseAt else { return false }
        return days(from: firstUse, to: now, calendar) >= firstReminderAfterDays
    }

    static func days(from: Date, to: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}

/// Reads and writes `BackupReminderState` in the App Group defaults. The keys are
/// in `AppDataReset.ownedKeys` and `BackupSettings.excludedKeys`.
public enum BackupReminderStore {
    public static func load(from defaults: UserDefaults) -> BackupReminderState {
        BackupReminderState(
            lastBackupAt: defaults.object(forKey: SettingsKey.lastBackupAt) as? Date,
            firstUseAt: defaults.object(forKey: SettingsKey.backupFirstUseAt) as? Date,
            snoozedAt: defaults.object(forKey: SettingsKey.backupReminderSnoozedAt) as? Date
        )
    }

    /// Remembers the first time the app is used; later calls change nothing.
    public static func recordUse(in defaults: UserDefaults, now: Date) {
        guard defaults.object(forKey: SettingsKey.backupFirstUseAt) == nil else { return }
        defaults.set(now, forKey: SettingsKey.backupFirstUseAt)
    }

    /// "Để sau".
    public static func snooze(in defaults: UserDefaults, now: Date) {
        defaults.set(now, forKey: SettingsKey.backupReminderSnoozedAt)
    }
}
