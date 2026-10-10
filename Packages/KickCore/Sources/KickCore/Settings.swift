import Foundation

public enum AppGroup {
    public static let identifier = "group.com.lmtiep.kickcounter"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Keys for preferences stored in `AppGroup.defaults` (read via @AppStorage).
public enum SettingsKey {
    public static let reminderEnabled = "reminderEnabled"
    public static let reminderHour = "reminderHour"
    public static let reminderMinute = "reminderMinute"
    /// `timeIntervalSince1970`; 0 means "not set".
    public static let dueDate = "dueDate"
    /// `"dueDate"` or `"lmp"`: which date the mother entered. `dueDate` stays the source of truth.
    public static let pregnancyDateSource = "pregnancyDateSource"
    /// First day of the last period, `timeIntervalSince1970`; 0 means "not set".
    public static let lmpDate = "lmpDate"
    public static let hasCompletedOnboarding = "hasCompletedOnboarding"
    /// `"tryingToConceive"`, `"pregnant"` or `"partner"`. Missing means pregnant (everyone before phase 3).
    public static let appMode = "appMode"
    /// The mode to restore when leaving partner mode (`AppMode.leavePartner`).
    public static let previousAppMode = "previousAppMode"
    /// True when accepting a partner invitation skipped onboarding; leaving partner mode shows it.
    public static let partnerSkippedOnboarding = "partnerSkippedOnboarding"
    /// The mother's last uploaded `PartnerSnapshot` (JSON), so a relaunch does not upload it again.
    public static let partnerPublishedSnapshot = "partnerPublishedSnapshot"
    /// The partner's one cached `PartnerSnapshot` (JSON); removed when the share is gone or on leaving.
    public static let partnerCachedSnapshot = "partnerCachedSnapshot"
    /// True while stopping sharing has not deleted the share zone yet; the next status check retries.
    public static let partnerPendingZoneDeletion = "partnerPendingZoneDeletion"
    /// Days, 21–45 (default 28): used until enough cycles are logged.
    public static let typicalCycleLength = "typicalCycleLength"
    /// Days, 2–10 (default 5).
    public static let typicalPeriodLength = "typicalPeriodLength"
    /// Fertile-window, period and late-period reminders. Missing means on.
    public static let cycleRemindersEnabled = "cycleRemindersEnabled"
    /// `CycleGoal` raw value (`"tracking"`, `"conceiving"`). Missing means conceiving (everyone before phase 9).
    public static let cycleGoal = "cycleGoal"
    /// `Contraception` raw value. Missing means not asked (treated like none).
    public static let contraception = "contraception"
    /// `CycleRegularity` raw value. Missing means unknown.
    public static let cycleRegularity = "cycleRegularity"
    /// Shows the LH test and BBT rows while tracking. Missing means off.
    public static let cycleShowsFertilityTests = "cycleShowsFertilityTests"
    /// `AppLanguage` raw value (`"system"`, `"vi"`, `"en"`). Missing means `system`.
    public static let appLanguage = "appLanguage"
    /// A short vibration on every counted tap. Missing means on.
    public static let kickHapticsEnabled = "kickHapticsEnabled"
    /// Pre-pregnancy weight in kg, 30–200; 0 means "not set" (`MaternalProfile`).
    public static let maternalPreWeightKg = "maternalPreWeightKg"
    /// Height in cm, 120–220; 0 means "not set".
    public static let maternalHeightCm = "maternalHeightCm"
    /// `Date` of the last backup file shared from Profile (phase 15). Missing means never.
    public static let lastBackupAt = "lastBackupAt"
    /// The daily pill reminder (phase 17). Missing means off.
    public static let pillReminderEnabled = "pillReminderEnabled"
    /// `PillPackType` raw value (`"21+7"` or `"28"`). Missing means `"21+7"`.
    public static let pillPackType = "pillPackType"
    /// First day of the current pack as a calendar date, yyyymmdd (`CalendarDay.key`); missing means not set.
    public static let pillPackStart = "pillPackStart"
    /// Missing means 21.
    public static let pillReminderHour = "pillReminderHour"
    /// Missing means 0.
    public static let pillReminderMinute = "pillReminderMinute"
    /// `Date` "Kết thúc theo dõi" was last tapped on the contraction timer (phase 20):
    /// contractions after it begin a new episode. Missing means never.
    public static let contractionEpisodeEndedAt = "contractionEpisodeEndedAt"
    /// `"<run id>:<ContractionAlert raw value>"` of the last contraction alert
    /// notification (phase 20): the same alert is not posted again for that run.
    public static let contractionAlertNotified = "contractionAlertNotified"
}

public enum SettingsDefault {
    public static let reminderHour = 20
    public static let reminderMinute = 0
}
