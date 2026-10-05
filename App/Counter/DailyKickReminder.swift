import KickCore
import SwiftUI

/// The daily kick-count reminder in one place: the kick settings sheet (opened
/// from Kicks and from Profile) edits it, and a language change re-schedules it.
@MainActor
enum DailyKickReminder {
    /// The stored switch and time, observed as one value so a time change
    /// (hour and minute written together) schedules once, not twice.
    struct Settings: Equatable {
        var enabled: Bool
        var hour: Int
        var minute: Int
    }

    /// What is stored in the app group now.
    static var stored: Settings {
        let defaults = AppGroup.defaults
        return Settings(
            enabled: defaults.bool(forKey: SettingsKey.reminderEnabled),
            hour: defaults.object(forKey: SettingsKey.reminderHour) as? Int ?? SettingsDefault.reminderHour,
            minute: defaults.object(forKey: SettingsKey.reminderMinute) as? Int ?? SettingsDefault.reminderMinute
        )
    }

    /// A `DatePicker` binding over the stored hour and minute.
    static func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? .now },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour.wrappedValue = components.hour ?? SettingsDefault.reminderHour
                minute.wrappedValue = components.minute ?? SettingsDefault.reminderMinute
            }
        )
    }

    /// Schedules the reminder, or cancels it when off. Only turning it on can
    /// ask for notification permission. Returns false when it couldn't be
    /// scheduled (usually: notifications denied); the caller then turns its
    /// switch back off.
    static func apply(_ settings: Settings, with coordinator: KickCoordinator) async -> Bool {
        await coordinator.setDailyReminder(
            enabled: settings.enabled,
            hour: settings.hour,
            minute: settings.minute,
            text: ReminderTexts.daily
        )
    }
}
