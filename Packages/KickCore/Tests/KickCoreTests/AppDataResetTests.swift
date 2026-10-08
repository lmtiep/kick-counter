import Foundation
import Testing
@testable import KickCore

struct AppDataResetTests {
    @Test func clearDefaultsRemovesOwnedKeysOnly() {
        let defaults = makeTestDefaults()
        for key in AppDataReset.ownedKeys {
            defaults.set("value", forKey: key)
        }
        defaults.set("keep", forKey: "someOtherAppKey")

        AppDataReset.clearDefaults(defaults)

        for key in AppDataReset.ownedKeys {
            #expect(defaults.object(forKey: key) == nil, "\(key) was not cleared")
        }
        #expect(defaults.string(forKey: "someOtherAppKey") == "keep")
    }

    @Test func ownedKeysHaveNoDuplicates() {
        #expect(Set(AppDataReset.ownedKeys).count == AppDataReset.ownedKeys.count)
    }

    /// Every key declared in `enum SettingsKey` (parsed from `Settings.swift`) is owned,
    /// so a key added later cannot survive "Xoá toàn bộ dữ liệu" by accident.
    @Test func ownedKeysCoverEverySettingsKey() throws {
        let declared = try settingsKeyValues()
        #expect(declared.count >= 20, "parsing Settings.swift found too few keys: \(declared)")
        let missing = declared.subtracting(AppDataReset.ownedKeys)
        #expect(missing.isEmpty, "keys missing from AppDataReset.ownedKeys: \(missing.sorted())")
    }

    @Test func ownedKeysIncludeModeOnboardingLanguageAndPartnerState() {
        let owned = Set(AppDataReset.ownedKeys)
        for key in [
            SettingsKey.appMode, SettingsKey.hasCompletedOnboarding, SettingsKey.appLanguage,
            SettingsKey.partnerCachedSnapshot, SettingsKey.partnerPublishedSnapshot,
            SettingsKey.cycleGoal, SettingsKey.reminderEnabled, SettingsKey.dueDate,
        ] {
            #expect(owned.contains(key), "\(key)")
        }
    }

    private struct ParseFailed: Error {}

    /// The string values of `public static let … = "…"` inside `enum SettingsKey { … }`.
    private func settingsKeyValues() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // KickCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // KickCore package
            .appendingPathComponent("Sources/KickCore/Settings.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        guard let start = source.range(of: "public enum SettingsKey {") else { throw ParseFailed() }
        let body = source[start.upperBound...]
        guard let end = body.range(of: "\n}") else { throw ParseFailed() }
        let pattern = /public static let \w+ = "([^"]+)"/
        return Set(body[..<end.lowerBound].matches(of: pattern).map { String($0.output.1) })
    }
}
