import Foundation

/// What the widget could read from the App Group.
public enum WidgetRead: Equatable, Sendable {
    case input(WidgetInput)
    /// Unreadable or not there (before the first unlock, a store that fails to open).
    case unavailable
}

public struct WidgetTimelineEntry: Equatable, Sendable {
    public let date: Date
    public let snapshot: WidgetSnapshot
}

/// The widget's timeline: one entry per local midnight when the read worked; a single
/// entry and a retry in 15 minutes when it did not (showing the last good data when
/// there is some, else the neutral "open the app" state).
public struct WidgetTimelinePlan: Equatable, Sendable {
    public static let days = 3
    public static let retryInterval: TimeInterval = 15 * 60

    public let entries: [WidgetTimelineEntry]
    /// When WidgetKit should ask again.
    public let reloadAfter: Date
    /// The input to keep as "last good" for a later failed read (nil: keep the old one).
    public let remembered: WidgetInput?

    public static func make(
        read: WidgetRead,
        lastGood: WidgetInput?,
        now: Date,
        calendar: Calendar = .current
    ) -> WidgetTimelinePlan {
        switch read {
        case .input(let input):
            let entries = entries(from: input, now: now, count: days, calendar: calendar)
            return WidgetTimelinePlan(
                entries: entries,
                reloadAfter: entries.last?.snapshot.refreshDate ?? now.addingTimeInterval(retryInterval),
                remembered: input
            )
        case .unavailable:
            let input = lastGood ?? WidgetInput(mode: .pregnant, hasCompletedOnboarding: false)
            let snapshot = WidgetSnapshot.make(input, now: now, calendar: calendar)
            return WidgetTimelinePlan(
                entries: [WidgetTimelineEntry(date: now, snapshot: snapshot)],
                reloadAfter: now.addingTimeInterval(retryInterval),
                remembered: nil
            )
        }
    }

    /// `count` entries: now, then each following midnight. Tomorrow has no kick count yet.
    public static func entries(from input: WidgetInput, now: Date, count: Int, calendar: Calendar = .current) -> [WidgetTimelineEntry] {
        var input = input
        var entries: [WidgetTimelineEntry] = []
        var date = now
        for _ in 0..<count {
            let snapshot = WidgetSnapshot.make(input, now: date, calendar: calendar)
            entries.append(WidgetTimelineEntry(date: date, snapshot: snapshot))
            date = snapshot.refreshDate
            input.kicksToday = nil
        }
        return entries
    }
}
