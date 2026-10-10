import Foundation

/// One contraction as the screen shows it.
public struct ContractionEntry: Equatable, Sendable, Identifiable {
    /// As counted: a forgotten one is already closed at `maxDuration`.
    public let record: ContractionRecord
    /// End − start; for the running one, now − start.
    public let duration: TimeInterval
    /// Its start − the previous contraction's start; nil for the first of an episode.
    public let interval: TimeInterval?

    public var id: UUID { record.id }
    public var startedAt: Date { record.startedAt }
    public var isRunning: Bool { record.isRunning }
}

/// Consecutive contractions whose starts are at most `ContractionRules.episodeGap` apart.
public struct ContractionEpisode: Equatable, Sendable, Identifiable {
    /// Oldest first, never empty.
    public let entries: [ContractionEntry]

    /// The first contraction's id: stable while that contraction exists.
    public var id: UUID { entries[0].id }
    public var startedAt: Date { entries[0].startedAt }
    public var lastStartedAt: Date { entries[entries.count - 1].startedAt }
    /// The last contraction's end; nil while it runs.
    public var endedAt: Date? { entries[entries.count - 1].record.endedAt }
    public var count: Int { entries.count }
    public var completed: [ContractionEntry] { entries.filter { !$0.isRunning } }
    /// Over the completed contractions.
    public var averageDuration: TimeInterval? { Self.mean(completed.map(\.duration)) }
    /// Over the completed contractions that have an interval.
    public var averageInterval: TimeInterval? { Self.mean(completed.compactMap(\.interval)) }
    /// First to last start of the completed contractions (0 with fewer than two).
    public var span: TimeInterval {
        guard let first = completed.first, let last = completed.last else { return 0 }
        return last.startedAt.timeIntervalSince(first.startedAt)
    }

    static func mean(_ values: [TimeInterval]) -> TimeInterval? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

/// Count and averages over a set of completed contractions.
public struct ContractionSummary: Equatable, Sendable {
    public var count: Int
    public var averageDuration: TimeInterval?
    /// (last start − first start) / (count − 1); nil with fewer than two.
    public var averageInterval: TimeInterval?

    public init(count: Int, averageDuration: TimeInterval?, averageInterval: TimeInterval?) {
        self.count = count
        self.averageDuration = averageDuration
        self.averageInterval = averageInterval
    }
}

/// The history's past episodes of one calendar day (the day of each episode's first start).
public struct ContractionDay: Equatable, Sendable, Identifiable {
    public let day: CalendarDay
    /// Newest first.
    public let episodes: [ContractionEpisode]
    public var id: Int { day.key }
}

/// Phase 20 spec §3.2: everything the timer screen, its alert cards and the
/// history show, from the contractions, `now` and the gestational week.
public struct ContractionStats: Equatable, Sendable {
    /// Oldest first.
    public let episodes: [ContractionEpisode]
    /// The episode the screen shows: the newest, while it has not been ended
    /// and its last start is at most `episodeGap` before `now`.
    public let currentEpisode: ContractionEpisode?
    /// The running contraction, if any (always in the current episode).
    public let running: ContractionEntry?
    /// Completed contractions that started within the last `window` (edge included),
    /// in any episode.
    public let lastHour: ContractionSummary
    public let alert: ContractionAlert

    /// `week` is nil when the pregnancy week is unknown. `episodeEndedAt` is
    /// when "Kết thúc theo dõi" was last tapped: contractions that start after
    /// it begin a new episode, and the one it ended is no longer current.
    public init(contractions: [ContractionRecord], now: Date, week: GestationalWeek?, episodeEndedAt: Date? = nil) {
        let records = ContractionRules.normalized(contractions, now: now)
        let episodes = Self.episodes(records, now: now, endedAt: episodeEndedAt)
        self.episodes = episodes

        if let last = episodes.last,
           episodeEndedAt.map({ last.lastStartedAt > $0 }) ?? true,
           last.endedAt == nil || now.timeIntervalSince(last.lastStartedAt) <= ContractionRules.episodeGap {
            currentEpisode = last
        } else {
            currentEpisode = nil
        }
        running = currentEpisode?.entries.last.flatMap { $0.isRunning ? $0 : nil }

        let windowStart = now.addingTimeInterval(-ContractionRules.window)
        let inWindow = episodes.flatMap(\.completed).filter { $0.startedAt >= windowStart }
        let lastHour = ContractionSummary(
            count: inWindow.count,
            averageDuration: ContractionEpisode.mean(inWindow.map(\.duration)),
            averageInterval: inWindow.count < 2 ? nil
                : inWindow[inWindow.count - 1].startedAt.timeIntervalSince(inWindow[0].startedAt) / Double(inWindow.count - 1)
        )
        self.lastHour = lastHour
        alert = Self.alert(lastHour: lastHour, current: currentEpisode, week: week)
    }

    /// Every episode except the current one, newest first.
    public var pastEpisodes: [ContractionEpisode] {
        episodes.reversed().filter { $0.id != currentEpisode?.id }
    }

    /// The past episodes grouped by the day of their first start in `calendar`,
    /// newest day first.
    public func pastEpisodesByDay(calendar: Calendar) -> [ContractionDay] {
        var days: [ContractionDay] = []
        for episode in pastEpisodes {
            let day = CalendarDay(episode.startedAt, calendar: calendar)
            if let last = days.last, last.day == day {
                days[days.count - 1] = ContractionDay(day: day, episodes: last.episodes + [episode])
            } else {
                days.append(ContractionDay(day: day, episodes: [episode]))
            }
        }
        return days
    }

    private static func episodes(_ records: [ContractionRecord], now: Date, endedAt marker: Date?) -> [ContractionEpisode] {
        var episodes: [[ContractionEntry]] = []
        var previous: ContractionRecord?
        for record in records {
            let duration = (record.endedAt ?? now).timeIntervalSince(record.startedAt)
            let gap = previous.map { record.startedAt.timeIntervalSince($0.startedAt) }
            let crossesMarker = marker.map { end in previous.map { $0.startedAt <= end && record.startedAt > end } ?? false } ?? false
            if let gap, gap <= ContractionRules.episodeGap, !crossesMarker {
                episodes[episodes.count - 1].append(ContractionEntry(record: record, duration: duration, interval: gap))
            } else {
                episodes.append([ContractionEntry(record: record, duration: duration, interval: nil)])
            }
            previous = record
        }
        return episodes.map { ContractionEpisode(entries: $0) }
    }

    private static func alert(lastHour: ContractionSummary, current: ContractionEpisode?, week: GestationalWeek?) -> ContractionAlert {
        if let week, week.weeks < ContractionRules.termWeek {
            return lastHour.count >= ContractionRules.pretermMinCount ? .pretermRegular : .none
        }
        guard let current, current.span >= ContractionRules.fiveOneOneMinSpan,
              lastHour.count >= ContractionRules.fiveOneOneMinCount,
              let interval = lastHour.averageInterval, interval <= ContractionRules.fiveOneOneMaxAverageInterval,
              let duration = lastHour.averageDuration, duration >= ContractionRules.fiveOneOneMinAverageDuration
        else { return .none }
        return .fiveOneOne
    }
}
