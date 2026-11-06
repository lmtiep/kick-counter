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
    /// "Vỡ ối" markers that fall in this episode (`ContractionStats`), oldest first.
    public internal(set) var markers: [LabourMarkerRecord] = []

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
    /// Markers of this day that belong to no episode, oldest first.
    public let markers: [LabourMarkerRecord]
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
    /// The newest run of consecutive contractions (starts at most `episodeGap`
    /// apart), whatever the episode-ended mark: the 5-1-1 span is measured over
    /// it, so a mis-tapped "Kết thúc theo dõi" never hides the alert. The mark
    /// only decides what the list and the Live Activity show.
    public let alertRun: ContractionEpisode?
    public let alert: ContractionAlert
    /// The markers the timer screen lists: those in the current episode and
    /// the recent ones in none (made after "Kết thúc theo dõi", or before the
    /// first contraction), oldest first.
    public let currentMarkers: [LabourMarkerRecord]
    /// Markers in no episode and not current: the history shows them by day.
    public let pastLooseMarkers: [LabourMarkerRecord]
    /// The newest "Vỡ ối" made within `ContractionRules.markerWindow` of `now`
    /// that is current: the emphasised safety card shows and the button hides.
    public let activeWaterBroke: LabourMarkerRecord?

    /// `week` is nil when the pregnancy week is unknown. `episodeEndedAt` is
    /// when "Kết thúc theo dõi" was last tapped: contractions that start after
    /// it begin a new episode, and the one it ended is no longer current.
    public init(
        contractions: [ContractionRecord], now: Date, week: GestationalWeek?, episodeEndedAt: Date? = nil,
        markers: [LabourMarkerRecord] = []
    ) {
        let records = ContractionRules.normalized(contractions, now: now)
        let (episodes, loose) = Self.attach(
            markers, to: Self.episodes(records, now: now, endedAt: episodeEndedAt), endedAt: episodeEndedAt
        )
        self.episodes = episodes

        if let last = episodes.last,
           episodeEndedAt.map({ last.lastStartedAt > $0 }) ?? true,
           last.endedAt == nil || now.timeIntervalSince(last.lastStartedAt) <= ContractionRules.episodeGap {
            currentEpisode = last
        } else {
            currentEpisode = nil
        }
        running = currentEpisode?.entries.last.flatMap { $0.isRunning ? $0 : nil }
        let markerWindowStart = now.addingTimeInterval(-ContractionRules.markerWindow)
        let recentLoose = loose.filter { marker in
            marker.at >= markerWindowStart && (episodeEndedAt.map { marker.at > $0 } ?? true)
        }
        currentMarkers = ((currentEpisode?.markers ?? []) + recentLoose).sorted { $0.at < $1.at }
        activeWaterBroke = currentMarkers.last { $0.isWaterBroke && $0.at >= markerWindowStart }
        pastLooseMarkers = loose.filter { marker in !recentLoose.contains { $0.id == marker.id } }

        let windowStart = now.addingTimeInterval(-ContractionRules.window)
        let inWindow = episodes.flatMap(\.completed).filter { $0.startedAt >= windowStart }
        let lastHour = ContractionSummary(
            count: inWindow.count,
            averageDuration: ContractionEpisode.mean(inWindow.map(\.duration)),
            averageInterval: inWindow.count < 2 ? nil
                : inWindow[inWindow.count - 1].startedAt.timeIntervalSince(inWindow[0].startedAt) / Double(inWindow.count - 1)
        )
        self.lastHour = lastHour
        let alertRun = episodeEndedAt == nil ? episodes.last : Self.episodes(records, now: now, endedAt: nil).last
        self.alertRun = alertRun
        alert = Self.alert(lastHour: lastHour, run: alertRun, week: week)
    }

    /// Every episode except the current one, newest first.
    public var pastEpisodes: [ContractionEpisode] {
        episodes.reversed().filter { $0.id != currentEpisode?.id }
    }

    /// The past episodes, and the markers in no episode, grouped by the day of
    /// the episode's first start (or the marker's time) in `calendar`, newest
    /// day first.
    public func pastEpisodesByDay(calendar: Calendar) -> [ContractionDay] {
        var episodesByDay: [CalendarDay: [ContractionEpisode]] = [:]
        for episode in pastEpisodes {
            episodesByDay[CalendarDay(episode.startedAt, calendar: calendar), default: []].append(episode)
        }
        var markersByDay: [CalendarDay: [LabourMarkerRecord]] = [:]
        for marker in pastLooseMarkers {
            markersByDay[CalendarDay(marker.at, calendar: calendar), default: []].append(marker)
        }
        let days = Set(episodesByDay.keys).union(markersByDay.keys).sorted(by: >)
        return days.map { ContractionDay(day: $0, episodes: episodesByDay[$0] ?? [], markers: markersByDay[$0] ?? []) }
    }

    /// Puts each known marker in the episode nearest to it (within
    /// `episodeGap` of the episode's first or last start); the rest are loose.
    /// A marker made after "Kết thúc theo dõi" never joins an episode that mark ended.
    private static func attach(
        _ markers: [LabourMarkerRecord], to episodes: [ContractionEpisode], endedAt: Date?
    ) -> (episodes: [ContractionEpisode], loose: [LabourMarkerRecord]) {
        var attached = Array(repeating: [LabourMarkerRecord](), count: episodes.count)
        var loose: [LabourMarkerRecord] = []
        for marker in markers.filter(\.isWaterBroke).sorted(by: { $0.at < $1.at }) {
            var best: (index: Int, distance: TimeInterval)?
            for (index, episode) in episodes.enumerated() {
                if let endedAt, marker.at > endedAt, episode.lastStartedAt <= endedAt { continue }
                let distance = marker.at < episode.startedAt
                    ? episode.startedAt.timeIntervalSince(marker.at)
                    : max(0, marker.at.timeIntervalSince(episode.lastStartedAt))
                // Before the first contraction: up to a day (the labour may start slowly);
                // after the last: while the episode would still go on.
                let limit = marker.at < episode.startedAt ? ContractionRules.markerWindow : ContractionRules.episodeGap
                guard distance <= limit else { continue }
                if best == nil || distance <= best!.distance { best = (index, distance) }
            }
            if let best { attached[best.index].append(marker) } else { loose.append(marker) }
        }
        let joined = zip(episodes, attached).map { episode, markers in
            var episode = episode
            episode.markers = markers
            return episode
        }
        return (joined, loose)
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

    private static func alert(lastHour: ContractionSummary, run: ContractionEpisode?, week: GestationalWeek?) -> ContractionAlert {
        if let week, week.weeks < ContractionRules.termWeek {
            return lastHour.count >= ContractionRules.pretermMinCount ? .pretermRegular : .none
        }
        guard let run, run.span >= ContractionRules.fiveOneOneMinSpan,
              lastHour.count >= ContractionRules.fiveOneOneMinCount,
              let interval = lastHour.averageInterval, interval <= ContractionRules.fiveOneOneMaxAverageInterval,
              let duration = lastHour.averageDuration, duration >= ContractionRules.fiveOneOneMinAverageDuration
        else { return .none }
        return .fiveOneOne
    }
}
