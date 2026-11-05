import CoreText
import KickCore
import SwiftUI
import UIKit
import XCTest

/// Renders the widget to PNG for every sample, language, appearance and size
/// (spec "Testing"). The test bundle carries the same strings, fonts and fruit art as
/// the widget extension. PNGs go to the folder in
/// the `WIDGET_PREVIEW_DIR` environment variable (pass it as
/// `TEST_RUNNER_WIDGET_PREVIEW_DIR`) and are attached to the test result.
@MainActor
final class WidgetPreviewRenderTests: XCTestCase {
    private struct Size {
        let name: String
        let layout: WidgetLayout
        let width: CGFloat
        let height: CGFloat
    }

    private let sizes = [
        Size(name: "small", layout: .small, width: 158, height: 158),
        Size(name: "medium", layout: .medium, width: 338, height: 158),
        Size(name: "rectangular", layout: .accessoryRectangular, width: 172, height: 76),
        Size(name: "circular", layout: .accessoryCircular, width: 76, height: 76),
        Size(name: "inline", layout: .accessoryInline, width: 234, height: 28),
    ]

    private var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["WIDGET_PREVIEW_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func previewView(_ snapshot: WidgetSnapshot, size: Size, scheme: ColorScheme) -> some View {
        let layout = size.layout
        return ZStack {
            if layout.isAccessory {
                // A dark wallpaper, as behind Lock Screen widgets.
                LinearGradient(colors: [Color(red: 0.25, green: 0.2, blue: 0.35), Color(red: 0.1, green: 0.1, blue: 0.2)], startPoint: .top, endPoint: .bottom)
            } else {
                WidgetBackground()
            }
            LunaWidgetContent(snapshot: snapshot, layout: layout)
                .padding(layout.isAccessory ? (layout == .accessoryInline ? 0 : 8) : 16)
                .foregroundStyle(layout.isAccessory ? Color.white : Color.primary)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: layout.isAccessory ? 14 : 24, style: .continuous))
        .environment(\.colorScheme, layout.isAccessory ? .dark : scheme)
        .environment(\.dynamicTypeSize, .large)
    }

    override func setUp() async throws {
        let bundle = Bundle(for: Self.self)
        L10n.resourceBundle = bundle
        for name in ["Regular", "Medium", "SemiBold", "Bold"] {
            let url = try XCTUnwrap(bundle.url(forResource: "BeVietnamPro-\(name)", withExtension: "ttf"))
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    func testRendersEverySampleInEveryLanguageAppearanceAndSize() throws {
        XCTAssertNotNil(UIFont(name: "BeVietnamPro-Bold", size: 12), "the fonts are registered")
        let defaults = AppGroup.defaults
        let previous = defaults.string(forKey: SettingsKey.appLanguage)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsKey.appLanguage) } else { defaults.removeObject(forKey: SettingsKey.appLanguage) }
        }
        // Fixed day: Oct 2 2026, noon.
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 12))!
        if let directory = outputDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        var rendered = 0
        for language in ["vi", "en"] {
            defaults.set(language, forKey: SettingsKey.appLanguage)
            for kind in LunaWidgetSamples.Kind.allCases {
                let snapshot = LunaWidgetSamples.snapshot(kind, now: now, calendar: calendar)
                for scheme in [ColorScheme.light, .dark] {
                    for size in sizes {
                        let renderer = ImageRenderer(content: previewView(snapshot, size: size, scheme: scheme))
                        renderer.scale = 3
                        let image = try XCTUnwrap(renderer.uiImage, "\(kind) \(size.name)")
                        XCTAssertEqual(image.size.width, size.width, "\(kind) \(size.name)")
                        guard let data = image.pngData() else { return XCTFail("no PNG") }
                        let name = "\(language)-\(scheme == .dark ? "dark" : "light")-\(size.name)-\(kind)"
                        if let directory = outputDirectory {
                            try data.write(to: directory.appendingPathComponent("\(name).png"))
                        }
                        rendered += 1
                    }
                }
            }
        }
        XCTAssertEqual(rendered, 2 * LunaWidgetSamples.Kind.allCases.count * 2 * sizes.count)
    }
}
