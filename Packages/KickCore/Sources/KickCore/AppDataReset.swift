import Foundation

/// The preferences half of "Xoá toàn bộ dữ liệu" (the store half is `DataReset` in KickData).
public enum AppDataReset {
    /// Every `AppGroup.defaults` key the app owns: modes, onboarding, dates, reminders,
    /// cycle and maternal settings, language and partner state. `AppDataResetTests`
    /// checks this covers every `SettingsKey`.
    public static let ownedKeys: [String] = [
        SettingsKey.reminderEnabled,
        SettingsKey.reminderHour,
        SettingsKey.reminderMinute,
        SettingsKey.dueDate,
        SettingsKey.pregnancyDateSource,
        SettingsKey.lmpDate,
        SettingsKey.hasCompletedOnboarding,
        SettingsKey.appMode,
        SettingsKey.previousAppMode,
        SettingsKey.partnerSkippedOnboarding,
        SettingsKey.partnerPublishedSnapshot,
        SettingsKey.partnerCachedSnapshot,
        SettingsKey.partnerPendingZoneDeletion,
        SettingsKey.typicalCycleLength,
        SettingsKey.typicalPeriodLength,
        SettingsKey.cycleRemindersEnabled,
        SettingsKey.cycleGoal,
        SettingsKey.contraception,
        SettingsKey.cycleRegularity,
        SettingsKey.cycleShowsFertilityTests,
        SettingsKey.appLanguage,
        SettingsKey.kickHapticsEnabled,
        SettingsKey.maternalPreWeightKg,
        SettingsKey.maternalHeightCm,
    ]

    /// Removes exactly `ownedKeys` from `defaults`; any other key is left as it is.
    public static func clearDefaults(_ defaults: UserDefaults) {
        for key in ownedKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
