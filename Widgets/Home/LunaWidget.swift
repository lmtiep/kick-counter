import KickCore
import KickData
import SwiftUI
import WidgetKit

struct LunaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the App Group on the device, read-only, and answers with one entry per
/// local midnight for the next days (`WidgetTimelinePlan`). A read that fails (before
/// the first unlock, a store that will not open) keeps the last good data or the
/// neutral state and asks again in 15 minutes. The app reloads it after every change.
struct LunaProvider: TimelineProvider {
    /// The last input read successfully by this process.
    private static let lastGood = LastGood()

    func placeholder(in context: Context) -> LunaEntry {
        LunaEntry(date: .now, snapshot: LunaWidgetSamples.snapshot(.pregnancy, now: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (LunaEntry) -> Void) {
        let now = Date()
        completion(context.isPreview
            ? LunaEntry(date: now, snapshot: LunaWidgetSamples.snapshot(.pregnancy, now: now))
            : Self.plan(now: now).entries.map { LunaEntry(date: $0.date, snapshot: $0.snapshot) }[0])
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LunaEntry>) -> Void) {
        let plan = Self.plan(now: Date())
        completion(Timeline(
            entries: plan.entries.map { LunaEntry(date: $0.date, snapshot: $0.snapshot) },
            policy: .after(plan.reloadAfter)
        ))
    }

    private static func plan(now: Date) -> WidgetTimelinePlan {
        let calendar = Calendar.current
        let plan = WidgetTimelinePlan.make(
            read: WidgetReader.read(now: now, calendar: calendar),
            lastGood: lastGood.value,
            now: now,
            calendar: calendar
        )
        if let remembered = plan.remembered { lastGood.value = remembered }
        return plan
    }

    private final class LastGood: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: WidgetInput?
        var value: WidgetInput? {
            get { lock.lock(); defer { lock.unlock() }; return stored }
            set { lock.lock(); defer { lock.unlock() }; stored = newValue }
        }
    }
}

/// Names the widget aloud (VoiceOver) — or, while its data is redacted on a locked
/// phone, only "Luna Mom". The medium pregnancy widget has a link (the kick line), so
/// its parts stay separate elements; the others read as one sentence.
struct LunaWidgetAccessible: View {
    let snapshot: WidgetSnapshot
    let layout: WidgetLayout
    @Environment(\.redactionReasons) private var redactionReasons

    private var hasLink: Bool {
        if layout == .medium, case .pregnancy(let content) = snapshot.content, content.kicks != .hidden { return true }
        return false
    }

    var body: some View {
        if redactionReasons.contains(.privacy) {
            LunaWidgetContent(snapshot: snapshot, layout: layout)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.widgetName)
        } else if hasLink {
            LunaWidgetContent(snapshot: snapshot, layout: layout)
                .accessibilityElement(children: .contain)
        } else {
            LunaWidgetContent(snapshot: snapshot, layout: layout)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(WidgetSpeech.label(for: snapshot))
        }
    }
}

struct LunaWidgetEntryView: View {
    let entry: LunaEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        // Every family hides its data while the phone is locked (StandBy shows the
        // small one); only the name and the "open the app" line stay.
        LunaWidgetAccessible(snapshot: entry.snapshot, layout: WidgetLayout(family))
            .privacySensitive(entry.snapshot.content != .needsSetup)
            .widgetURL(WidgetLink.today.url)
            .containerBackground(for: .widget) { WidgetBackground() }
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
