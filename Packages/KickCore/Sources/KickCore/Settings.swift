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
    /// `"tryingToConceive"` or `"pregnant"`. Missing means pregnant (everyone before phase 3).
    public static let appMode = "appMode"
    /// Days, 21–45 (default 28): used until enough cycles are logged.
    public static let typicalCycleLength = "typicalCycleLength"
    /// Days, 2–10 (default 5).
    public static let typicalPeriodLength = "typicalPeriodLength"
    /// Fertile-window, period and late-period reminders. Missing means on.
    public static let cycleRemindersEnabled = "cycleRemindersEnabled"
    /// `AppLanguage` raw value (`"system"`, `"vi"`, `"en"`). Missing means `system`.
    public static let appLanguage = "appLanguage"
    /// A short vibration on every counted tap. Missing means on.
    public static let kickHapticsEnabled = "kickHapticsEnabled"
}

public enum SettingsDefault {
    public static let reminderHour = 20
    public static let reminderMinute = 0
}
