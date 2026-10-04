import Foundation
import Testing
@testable import KickCore

struct AppLanguageTests {
    @Test func missingOrUnknownMeansSystem() {
        let defaults = makeTestDefaults()
        #expect(AppLanguage.load(from: defaults) == .system)
        defaults.set("fr", forKey: SettingsKey.appLanguage)
        #expect(AppLanguage.load(from: defaults) == .system)
    }

    @Test func savesAndLoads() {
        let defaults = makeTestDefaults()
        AppLanguage.save(.vi, to: defaults)
        #expect(defaults.string(forKey: "appLanguage") == "vi")
        #expect(AppLanguage.load(from: defaults) == .vi)
    }

    @Test func systemFollowsTheFirstSupportedDeviceLanguage() {
        #expect(AppLanguage.system.resolved(preferredLanguages: ["vi-VN", "en-US"]) == .vi)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR", "en-GB", "vi"]) == .en)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]) == .en)
        #expect(AppLanguage.system.resolved(preferredLanguages: []) == .en)
    }

    @Test func aChosenLanguageIgnoresTheDevice() {
        #expect(AppLanguage.vi.resolved(preferredLanguages: ["en-US"]) == .vi)
        #expect(AppLanguage.en.resolved(preferredLanguages: ["vi-VN"]) == .en)
    }

    @Test func localeKeepsTheDeviceRegion() {
        #expect(AppLanguage.vi.locale(preferredLanguages: ["en-US"], regionCode: "VN").identifier == "vi_VN")
        #expect(AppLanguage.en.locale(preferredLanguages: ["vi"], regionCode: "VN").identifier == "en_VN")
        #expect(AppLanguage.system.locale(preferredLanguages: ["vi"], regionCode: nil).identifier == "vi")
    }

    @Test func vietnameseWeeksStartOnMonday() {
        let utc = TimeZone(identifier: "UTC")!
        #expect(AppLanguage.vi.calendar(preferredLanguages: [], regionCode: "US", timeZone: utc).firstWeekday == 2)
        #expect(AppLanguage.en.calendar(preferredLanguages: [], regionCode: "US", timeZone: utc).firstWeekday == 1)
        let calendar = AppLanguage.en.calendar(preferredLanguages: [], regionCode: "GB", timeZone: utc)
        #expect(calendar.firstWeekday == 2)
        #expect(calendar.timeZone == utc)
        #expect(calendar.locale?.identifier == "en_GB")
    }

    @Test func formatsInTheChosenLanguage() {
        let day = date("2026-10-04T12:00:00Z")
        let vi = AppLanguage.vi.locale(preferredLanguages: [], regionCode: "VN")
        let en = AppLanguage.en.locale(preferredLanguages: [], regionCode: "US")
        let style = Date.FormatStyle(date: .omitted, time: .omitted, timeZone: TimeZone(identifier: "UTC")!).day().month(.wide)
        #expect(day.formatted(style.locale(vi)) == "4 tháng 10")
        #expect(day.formatted(style.locale(en)) == "October 4")
    }

    @Test func looksUpStringsInTheChosenLanguagesBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppLanguageTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, value) in [("en", "Today"), ("vi", "Hôm nay")] {
            let folder = root.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try "\"tab.today\" = \"\(value)\";\n".write(
                to: folder.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8
            )
        }
        let base = try #require(Bundle(path: root.path))
        let vi = AppLanguage.vi.localizationBundle(in: base, preferredLanguages: ["en"])
        let en = AppLanguage.en.localizationBundle(in: base, preferredLanguages: ["vi"])
        let system = AppLanguage.system.localizationBundle(in: base, preferredLanguages: ["vi-VN"])
        #expect(vi.localizedString(forKey: "tab.today", value: nil, table: nil) == "Hôm nay")
        #expect(en.localizedString(forKey: "tab.today", value: nil, table: nil) == "Today")
        #expect(system.localizedString(forKey: "tab.today", value: nil, table: nil) == "Hôm nay")
    }

    @Test func missingLprojFallsBackToTheBaseBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppLanguageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let base = try #require(Bundle(path: root.path))
        #expect(AppLanguage.vi.localizationBundle(in: base, preferredLanguages: []).bundlePath == base.bundlePath)
    }
}
