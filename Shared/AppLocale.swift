import Foundation
import KickCore

/// The language, locale and calendar chosen in the app (spec §2.2). Everything
/// shown — strings (`L10n`), dates and numbers (`Formatting`), the calendar
/// grid — goes through here instead of the device's settings. Shared with the
/// widget extension, which reads the same choice from the App Group.
enum AppLocale {
    /// The language the app shows: Vietnamese or English.
    static var language: ContentLanguage {
        AppLanguage.current.resolved(preferredLanguages: Locale.preferredLanguages)
    }

    static var locale: Locale {
        AppLanguage.current.locale(
            preferredLanguages: Locale.preferredLanguages,
            regionCode: Locale.current.region?.identifier
        )
    }

    /// Gregorian, in the device time zone, weeks starting on Monday in Vietnamese.
    static var calendar: Calendar {
        AppLanguage.current.calendar(
            preferredLanguages: Locale.preferredLanguages,
            regionCode: Locale.current.region?.identifier,
            timeZone: .current
        )
    }
}
