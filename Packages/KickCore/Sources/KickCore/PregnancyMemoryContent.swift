import Foundation

/// The kick sessions of one day, as a memory keeps them.
public struct KickDay: Codable, Equatable, Sendable {
    /// Start of the local day the sessions started.
    public var day: Date
    public var sessionCount: Int
    public var totalKicks: Int
    /// The quickest completed session, in seconds.
    public var bestDuration: TimeInterval?

    public init(day: Date, sessionCount: Int, totalKicks: Int, bestDuration: TimeInterval?) {
        self.day = day
        self.sessionCount = sessionCount
        self.totalKicks = totalKicks
        self.bestDuration = bestDuration
    }
}

/// One contraction episode, as a memory keeps it.
public struct ContractionEpisodeSummary: Codable, Equatable, Sendable {
    public var start: Date
    public var count: Int
    public var averageDuration: TimeInterval?
    public var averageInterval: TimeInterval?

    public init(start: Date, count: Int, averageDuration: TimeInterval?, averageInterval: TimeInterval?) {
        self.start = start
        self.count = count
        self.averageDuration = averageDuration
        self.averageInterval = averageInterval
    }
}

public struct MemoryAppointment: Codable, Equatable, Sendable {
    public var date: Date
    public var title: String
    public var note: String

    public init(date: Date, title: String, note: String) {
        self.date = date
        self.title = title
        self.note = note
    }
}

public struct MemoryWeight: Codable, Equatable, Sendable {
    public var day: Date
    public var kg: Double

    public init(day: Date, kg: Double) {
        self.day = day
        self.kg = kg
    }
}

/// A day she wrote or picked something in pregnancy mode. Moods and symptoms
/// are the stored raw values (`Mood`, `Symptom`), so unknown ones survive.
public struct MemoryNote: Codable, Equatable, Sendable {
    public var day: Date
    public var text: String
    public var moods: [String]
    public var pregnancySymptoms: [String]

    public init(day: Date, text: String, moods: [String], pregnancySymptoms: [String]) {
        self.day = day
        self.text = text
        self.moods = moods
        self.pregnancySymptoms = pregnancySymptoms
    }
}

/// The frozen journey a `PregnancyMemory` keeps (spec §4.3, §4.6), stored as
/// JSON. The same content for both branches (owner decision); only `branch` differs.
public struct PregnancyMemoryContent: Codable, Equatable, Sendable {
    /// The payload format; bump only with a decoder that still reads 1.
    public var version: Int
    public var branch: PregnancyEndBranch
    /// The pregnancy's first day; nil when nothing told it.
    public var start: Date?
    /// The day it ended.
    public var end: Date
    /// Completed weeks at the end (0…42); nil without an LMP or due date.
    public var furthestWeek: Int?
    /// Oldest first.
    public var kickDays: [KickDay]
    public var contractionEpisodes: [ContractionEpisodeSummary]
    public var appointments: [MemoryAppointment]
    public var weights: [MemoryWeight]
    public var notes: [MemoryNote]

    public init(
        branch: PregnancyEndBranch,
        start: Date?,
        end: Date,
        furthestWeek: Int?,
        kickDays: [KickDay] = [],
        contractionEpisodes: [ContractionEpisodeSummary] = [],
        appointments: [MemoryAppointment] = [],
        weights: [MemoryWeight] = [],
        notes: [MemoryNote] = []
    ) {
        version = 1
        self.branch = branch
        self.start = start
        self.end = end
        self.furthestWeek = furthestWeek
        self.kickDays = kickDays
        self.contractionEpisodes = contractionEpisodes
        self.appointments = appointments
        self.weights = weights
        self.notes = notes
    }

    /// Nothing but the dates: the detail page shows only its header.
    public var isEmpty: Bool {
        kickDays.isEmpty && contractionEpisodes.isEmpty && appointments.isEmpty && weights.isEmpty && notes.isEmpty
    }

    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// ISO-8601 dates with milliseconds, sorted keys.
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = try? Date(text, strategy: dateStyle) { return date }
            return try Date(text, strategy: .iso8601)
        }
        return decoder
    }
}

/// Builds the memory from the raw rows (spec §4.6). Pure: the archive in
/// KickData saves it and deletes the rows in one transaction.
public enum PregnancyMemoryBuilder {
    /// Never more than this many completed weeks.
    public static let maxWeek = 42

    public static func make(
        branch: PregnancyEndBranch,
        profile: PregnancyProfile,
        endDate: Date,
        sessions: [SessionRecord],
        contractions: [ContractionRecord],
        appointments: [AppointmentRecord],
        weights: [WeightRecord],
        logs: [CycleLogRecord],
        calendar: Calendar
    ) -> PregnancyMemoryContent {
        let endDay = calendar.startOfDay(for: endDate)
        let range = PregnancyRange.make(
            profile: profile, endDate: endDay,
            fallbackStarts: fallbackStarts(sessions: sessions, contractions: contractions, appointments: appointments),
            calendar: calendar
        )
        return PregnancyMemoryContent(
            branch: branch,
            start: range?.lowerBound,
            end: endDay,
            furthestWeek: furthestWeek(profile: profile, endDay: endDay, calendar: calendar),
            kickDays: kickDays(sessions, calendar: calendar),
            contractionEpisodes: episodes(contractions, endDay: endDay, calendar: calendar),
            appointments: appointments
                .filter { range?.contains($0.date) ?? false }
                .sorted { $0.date < $1.date }
                .map { MemoryAppointment(date: $0.date, title: $0.title, note: $0.note) },
            weights: weights
                .filter { range?.contains($0.day) ?? false }
                .sorted { $0.day < $1.day }
                .map { MemoryWeight(day: $0.day, kg: $0.kg) },
            notes: logs
                .filter { (range?.contains($0.day) ?? false) && SymptomTimeline.showsInPregnancy($0) }
                .sorted { $0.day < $1.day }
                .map {
                    MemoryNote(
                        day: $0.day,
                        text: $0.note.trimmingCharacters(in: .whitespacesAndNewlines),
                        moods: $0.moods.map(\.rawValue) + $0.unknownMoodsRaw,
                        pregnancySymptoms: $0.symptoms(for: .pregnant).map(\.rawValue)
                    )
                }
        )
    }

    /// The range fallback when no pregnancy date is stored: kicks, contractions and appointments.
    public static func fallbackStarts(
        sessions: [SessionRecord], contractions: [ContractionRecord], appointments: [AppointmentRecord]
    ) -> [Date] {
        sessions.map(\.state.startedAt) + contractions.map(\.startedAt) + appointments.map(\.date)
    }

    /// Which raw rows the archive deletes (spec §4.6): appointments and weights
    /// inside the range. Kick sessions and contractions are all deleted; day logs never.
    public static func rowsToDelete(
        range: ClosedRange<Date>?,
        appointments: [AppointmentRecord],
        weights: [WeightRecord]
    ) -> (appointmentIDs: Set<UUID>, weightIDs: Set<UUID>) {
        guard let range else { return ([], []) }
        return (
            Set(appointments.filter { range.contains($0.date) }.map(\.id)),
            Set(weights.filter { range.contains($0.day) }.map(\.id))
        )
    }

    static func furthestWeek(profile: PregnancyProfile, endDay: Date, calendar: Calendar) -> Int? {
        let start: Date
        if let lmp = profile.lmpDate {
            start = lmp
        } else if let due = profile.dueDate {
            start = PregnancyDates.lmp(fromDueDate: due, calendar: calendar)
        } else {
            return nil
        }
        guard let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: endDay).day else { return nil }
        return min(max(days / 7, 0), maxWeek)
    }

    /// Completed sessions per local day, oldest first.
    static func kickDays(_ sessions: [SessionRecord], calendar: Calendar) -> [KickDay] {
        let completed = sessions.filter { $0.state.status == .completed }
        let byDay = Dictionary(grouping: completed) { calendar.startOfDay(for: $0.state.startedAt) }
        return byDay.keys.sorted().map { day in
            let group = byDay[day] ?? []
            return KickDay(
                day: day,
                sessionCount: group.count,
                totalKicks: group.reduce(0) { $0 + $1.state.count },
                bestDuration: group.compactMap(\.state.duration).min()
            )
        }
    }

    static func episodes(_ contractions: [ContractionRecord], endDay: Date, calendar: Calendar) -> [ContractionEpisodeSummary] {
        let latest = contractions.map { $0.endedAt ?? $0.startedAt }.max() ?? endDay
        let now = max(latest, CycleRules.nextDay(after: endDay, calendar: calendar))
        return ContractionStats(contractions: contractions, now: now, week: nil).episodes.map {
            ContractionEpisodeSummary(
                start: $0.startedAt, count: $0.count, averageDuration: $0.averageDuration, averageInterval: $0.averageInterval
            )
        }
    }
}
