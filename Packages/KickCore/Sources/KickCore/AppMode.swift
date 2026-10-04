import Foundation

/// Which half of the app the mother sees: cycle tracking while trying to
/// conceive, or the pregnancy journey (phases 1–2).
public enum AppMode: String, Sendable, CaseIterable {
    case tryingToConceive
    case pregnant

    /// The stored mode. Users from before phase 3 have none stored and stay
    /// pregnant; new users pick one in onboarding before seeing any tab.
    public static func load(from defaults: UserDefaults) -> AppMode {
        defaults.string(forKey: SettingsKey.appMode).flatMap(AppMode.init(rawValue:)) ?? .pregnant
    }

    public static func save(_ mode: AppMode, to defaults: UserDefaults) {
        defaults.set(mode.rawValue, forKey: SettingsKey.appMode)
    }
}
