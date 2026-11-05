import Foundation
import Testing

/// `Widgets/FruitArt.xcassets` holds copies of the app's `Fruit-W##.imageset` folders
/// (actool does not follow symlinks): they must stay identical.
struct WidgetArtTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func files(in directory: URL) throws -> [String: Data] {
        let manager = FileManager.default
        var result: [String: Data] = [:]
        for name in try manager.contentsOfDirectory(atPath: directory.path) {
            result[name] = try Data(contentsOf: directory.appendingPathComponent(name))
        }
        return result
    }

    @Test func widgetFruitArtMatchesTheApps() throws {
        let app = repoRoot.appendingPathComponent("App/Images.xcassets")
        let widget = repoRoot.appendingPathComponent("Widgets/FruitArt.xcassets")
        let appSets = try FileManager.default.contentsOfDirectory(atPath: app.path).filter { $0.hasPrefix("Fruit-W") }.sorted()
        let widgetSets = try FileManager.default.contentsOfDirectory(atPath: widget.path).filter { $0.hasPrefix("Fruit-W") }.sorted()
        #expect(!appSets.isEmpty)
        #expect(widgetSets == appSets)
        for name in appSets where widgetSets.contains(name) {
            #expect(try files(in: app.appendingPathComponent(name)) == files(in: widget.appendingPathComponent(name)), "\(name) differs")
        }
    }
}
