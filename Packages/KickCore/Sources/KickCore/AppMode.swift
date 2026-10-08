import Foundation

/// Which half of the app the mother sees: cycle tracking while trying to
/// conceive, or the pregnancy journey (phases 1–2). `partner` is the read-only
/// view of a journey someone shared through iCloud (phase 8).
public enum AppMode: String, Sendable, CaseIterable {
    case tryingToConceive
    case pregnant
    case partner

    /// The stored mode. Users from before phase 3 have none stored and stay
    /// pregnant; new users pick one in onboarding before seeing any tab.
    public static func load(from defaults: UserDefaults) -> AppMode {
        defaults.string(forKey: SettingsKey.appMode).flatMap(AppMode.init(rawValue:)) ?? .pregnant
    }

    public static func save(_ mode: AppMode, to defaults: UserDefaults) {
        defaults.set(mode.rawValue, forKey: SettingsKey.appMode)
    }

    /// Accepting a partner invitation: remembers the current mode (unless it
    /// already is partner mode) and switches to partner mode.
    public static func enterPartner(in defaults: UserDefaults) {
        let current = load(from: defaults)
        if current != .partner {
            defaults.set(current.rawValue, forKey: SettingsKey.previousAppMode)
        }
        save(.partner, to: defaults)
    }

    /// Leaving partner mode: back to the remembered mode (pregnant when none
    /// was remembered). Returns the restored mode.
    @discardableResult
    public static func leavePartner(in defaults: UserDefaults) -> AppMode {
        let previous = defaults.string(forKey: SettingsKey.previousAppMode)
            .flatMap(AppMode.init(rawValue:))
            .flatMap { $0 == .partner ? nil : $0 } ?? .pregnant
        defaults.removeObject(forKey: SettingsKey.previousAppMode)
        save(previous, to: defaults)
        return previous
    }

    /// Partner mode hidden (`AppFeatures.cloudSync` off, phase 12 spec §3.2): a stored
    /// partner mode is treated as "not onboarded". Leaves partner mode for the remembered
    /// mode (pregnant when none) and resets `hasCompletedOnboarding`, so onboarding asks
    /// for a goal again; nothing else is touched. Returns whether the mode was partner.
    @discardableResult
    public static func hidePartnerMode(in defaults: UserDefaults) -> Bool {
        guard load(from: defaults) == .partner else { return false }
        leavePartner(in: defaults)
        defaults.set(false, forKey: SettingsKey.hasCompletedOnboarding)
        return true
    }
}
