import Foundation

/// The language chosen in the app (onboarding, Profile): follow the device, or
/// force Vietnamese or English. Stored in `AppGroup.defaults` so the widget and
/// Live Activity use the same language.
public enum AppLanguage: String, Sendable, CaseIterable {
    case system
    case vi
    case en

    public static func load(from defaults: UserDefaults) -> AppLanguage {
        defaults.string(forKey: SettingsKey.appLanguage).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    public static func save(_ language: AppLanguage, to defaults: UserDefaults) {
        defaults.set(language.rawValue, forKey: SettingsKey.appLanguage)
    }

    /// The stored choice in the shared App Group.
    public static var current: AppLanguage { load(from: AppGroup.defaults) }

    /// The language actually shown: `system` takes the first of the device's
    /// languages that is Vietnamese or English, else English.
    public func resolved(preferredLanguages: [String]) -> ContentLanguage {
        switch self {
        case .system: ContentLanguage(preferredLanguages: preferredLanguages)
        case .vi: .vi
        case .en: .en
        }
    }

    /// Locale for dates, numbers and pickers: the resolved language in the
    /// device's region ("vi_VN", "en_US"), or the bare language without a region.
    public func locale(preferredLanguages: [String], regionCode: String?) -> Locale {
        let language = resolved(preferredLanguages: preferredLanguages).rawValue
        guard let regionCode, !regionCode.isEmpty else { return Locale(identifier: language) }
        return Locale(identifier: "\(language)_\(regionCode)")
    }

    /// A Gregorian calendar in that locale and `timeZone`. Weeks start on Monday
    /// in Vietnamese whatever the region; in English the region decides.
    public func calendar(preferredLanguages: [String], regionCode: String?, timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale(preferredLanguages: preferredLanguages, regionCode: regionCode)
        calendar.timeZone = timeZone
        if resolved(preferredLanguages: preferredLanguages) == .vi {
            calendar.firstWeekday = 2
        }
        return calendar
    }

    /// The `<language>.lproj` bundle inside `base` holding the compiled string
    /// catalog, or `base` itself when there is none (it then falls back to its
    /// own localization).
    public func localizationBundle(in base: Bundle, preferredLanguages: [String]) -> Bundle {
        let language = resolved(preferredLanguages: preferredLanguages).rawValue
        guard let path = base.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else {
            return base
        }
        return bundle
    }
}
