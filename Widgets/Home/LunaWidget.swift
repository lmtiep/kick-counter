import KickCore
import KickData
import SwiftData
import SwiftUI
import WidgetKit

struct LunaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the App Group on the device, read-only, and answers with one entry per
/// local midnight for the next days. The app reloads it after every change.
struct LunaProvider: TimelineProvider {
    private static let days = 3

    func placeholder(in context: Context) -> LunaEntry {
        LunaEntry(date: .now, snapshot: LunaWidgetSamples.snapshot(.pregnancy, now: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (LunaEntry) -> Void) {
        let now = Date()
        completion(context.isPreview
            ? LunaEntry(date: now, snapshot: LunaWidgetSamples.snapshot(.pregnancy, now: now))
            : Self.entries(from: now, count: 1)[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LunaEntry>) -> Void) {
        let entries = Self.entries(from: Date(), count: Self.days)
        completion(Timeline(entries: entries, policy: .after(entries.last?.snapshot.refreshDate ?? Date().addingTimeInterval(3600))))
    }

    private static func entries(from start: Date, count: Int) -> [LunaEntry] {
        let calendar = Calendar.current
        var input = load(now: start, calendar: calendar)
        var entries: [LunaEntry] = []
        var date = start
        for _ in 0..<count {
            let snapshot = WidgetSnapshot.make(input, now: date, calendar: calendar)
            entries.append(LunaEntry(date: date, snapshot: snapshot))
            date = snapshot.refreshDate
            // Tomorrow has no kick count yet.
            input.kicksToday = nil
        }
        return entries
    }

    /// Anything unreadable shows the neutral "open the app" state.
    private static func load(now: Date, calendar: Calendar) -> WidgetInput {
        let defaults = AppGroup.defaults
        do {
            let container = try WidgetReader.makeContainer()
            return try WidgetReader.input(context: ModelContext(container), defaults: defaults, now: now, calendar: calendar)
        } catch {
            return WidgetInput(mode: AppMode.load(from: defaults), hasCompletedOnboarding: false)
        }
    }
}

struct LunaWidgetEntryView: View {
    let entry: LunaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let layout = WidgetLayout(family)
        LunaWidgetContent(snapshot: entry.snapshot, layout: layout)
            // Redacted while the phone is locked.
            .privacySensitive(layout.isAccessory)
            .widgetURL(WidgetLink.today.url)
            .containerBackground(for: .widget) { WidgetBackground() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetSpeech.label(for: entry.snapshot))
    }
}

struct LunaWidget: Widget {
    static let kind = "LunaMomWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: LunaProvider()) { entry in
            LunaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(L10n.widgetName)
        .description(L10n.widgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
