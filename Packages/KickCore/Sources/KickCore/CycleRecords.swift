import Foundation

/// A logged period (value snapshot of the SwiftData `PeriodEntry`). Dates are
/// the start of a calendar day; `endDate` is the last day of bleeding.
public struct PeriodRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var startDate: Date
    /// nil while the period is still going on.
    public var endDate: Date?

    public init(id: UUID = UUID(), startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }

    public var isOpen: Bool { endDate == nil }
}

public enum LHResult: String, Sendable, CaseIterable {
    case positive
    case negative
}

public enum CervicalMucus: String, Sendable, CaseIterable {
    case dry
    case sticky
    case creamy
    case eggWhite
}

/// What was logged for one day (value snapshot of the SwiftData `CycleLog`):
/// ovulation signals, flow, moods and symptoms of both modes, and a note.
public struct CycleLogRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Start of the calendar day.
    public var day: Date
    public var lh: LHResult?
    /// Basal body temperature, 35.0–38.5 °C.
    public var bbtCelsius: Double?
    public var mucus: CervicalMucus?
    public var note: String
    public var flow: MenstrualFlow?
    /// Enum order, no repeats (`CycleRules.normalized`).
    public var moods: [Mood]
    /// Both modes' symptoms, enum order, no repeats.
    public var symptoms: [Symptom]
    /// Stored values this build does not know, written back unchanged.
    public var unknownMoodsRaw: [String]
    public var unknownSymptomsRaw: [String]

    public init(
        id: UUID = UUID(),
        day: Date,
        lh: LHResult? = nil,
        bbtCelsius: Double? = nil,
        mucus: CervicalMucus? = nil,
        note: String = "",
        flow: MenstrualFlow? = nil,
        moods: [Mood] = [],
        symptoms: [Symptom] = [],
        unknownMoodsRaw: [String] = [],
        unknownSymptomsRaw: [String] = []
    ) {
        self.id = id
        self.day = day
        self.lh = lh
        self.bbtCelsius = bbtCelsius
        self.mucus = mucus
        self.note = note
        self.flow = flow
        self.moods = moods
        self.symptoms = symptoms
        self.unknownMoodsRaw = unknownMoodsRaw
        self.unknownSymptomsRaw = unknownSymptomsRaw
    }

    /// The same values under another id (a store keeps the id it already has).
    public func withID(_ id: UUID) -> CycleLogRecord {
        CycleLogRecord(
            id: id, day: day, lh: lh, bbtCelsius: bbtCelsius, mucus: mucus, note: note,
            flow: flow, moods: moods, symptoms: symptoms,
            unknownMoodsRaw: unknownMoodsRaw, unknownSymptomsRaw: unknownSymptomsRaw
        )
    }

    /// Nothing logged: saving an empty log removes that day's log. Values this
    /// build cannot read count as something, so they are never dropped.
    public var isEmpty: Bool {
        lh == nil && bbtCelsius == nil && mucus == nil && flow == nil
            && moods.isEmpty && symptoms.isEmpty && unknownMoodsRaw.isEmpty && unknownSymptomsRaw.isEmpty
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The symptoms of one mode, as that mode's sheet shows them.
    public func symptoms(for mode: AppMode) -> [Symptom] {
        symptoms.filter { $0.mode == mode }
    }

    /// Replaces one mode's symptoms; the other mode's stay as they are.
    public mutating func setSymptoms(_ selected: some Sequence<Symptom>, for mode: AppMode) {
        let chosen = Array(selected).filter { $0.mode == mode }
        symptoms = RawList.ordered(symptoms.filter { $0.mode != mode } + chosen)
    }
}

public enum CycleRepositoryError: Error, Equatable, Sendable {
    case futureDate
    case endBeforeStart
    case overlapsExistingPeriod
    case invalidTemperature
    case notFound
}

/// Storage for periods and day logs. Implementations validate every write with
/// `CycleRules` and merge iCloud duplicates on read; reminders are kept in step
/// by `CycleCoordinator`.
@MainActor
public protocol CycleRepository: AnyObject {
    /// Every period, oldest first, with overlapping duplicates merged.
    func periods() throws -> [PeriodRecord]
    /// Every day log, oldest first, at most one per day.
    func logs() throws -> [CycleLogRecord]
    /// Throws `CycleRepositoryError` when the period is in the future, ends before
    /// it starts, or overlaps another period.
    func addPeriod(_ period: PeriodRecord, today: Date) throws
    /// Same checks as `addPeriod`; throws `.notFound` for an unknown id.
    func updatePeriod(_ period: PeriodRecord, today: Date) throws
    /// No-op when no period has that id (it may already be gone via iCloud).
    func deletePeriod(id: UUID) throws
    /// Inserts or replaces the log for `log.day` (keeping the stored id); an empty
    /// log removes it. Throws `.futureDate` or `.invalidTemperature`.
    func saveLog(_ log: CycleLogRecord, today: Date) throws
}

/// Validation and duplicate merging shared by `CycleStore` and the test fake.
public enum CycleRules {
    public static let temperatureRange: ClosedRange<Double> = 35.0...38.5
    /// An open period is assumed to last at most this many days; past that the
    /// Cycle tab suggests logging the end (spec §6).
    public static let longPeriodDays = 10

    public static func normalized(_ period: PeriodRecord, calendar: Calendar) -> PeriodRecord {
        PeriodRecord(
            id: period.id,
            startDate: calendar.startOfDay(for: period.startDate),
            endDate: period.endDate.map { calendar.startOfDay(for: $0) }
        )
    }

    public static func normalized(_ log: CycleLogRecord, calendar: Calendar) -> CycleLogRecord {
        var copy = log
        copy.day = calendar.startOfDay(for: log.day)
        copy.note = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.moods = RawList.ordered(log.moods)
        copy.symptoms = RawList.ordered(log.symptoms)
        return copy
    }

    /// The days a period covers, both ends included: up to its end day, or — while
    /// open — up to today, but no more than `longPeriodDays` days.
    public static func dayRange(of period: PeriodRecord, today: Date, calendar: Calendar) -> ClosedRange<Date> {
        let start = calendar.startOfDay(for: period.startDate)
        let end: Date
        if let endDate = period.endDate {
            end = calendar.startOfDay(for: endDate)
        } else {
            let cap = calendar.date(byAdding: .day, value: longPeriodDays - 1, to: start) ?? start
            end = min(calendar.startOfDay(for: today), cap)
        }
        return start...max(start, end)
    }

    /// Checks a new or edited period against the others (`existing` may include
    /// the period itself; it is skipped by id).
    public static func validate(_ period: PeriodRecord, existing: [PeriodRecord], today: Date, calendar: Calendar) throws {
        let candidate = normalized(period, calendar: calendar)
        let todayStart = calendar.startOfDay(for: today)
        guard candidate.startDate <= todayStart else { throw CycleRepositoryError.futureDate }
        if let end = candidate.endDate {
            guard end >= candidate.startDate else { throw CycleRepositoryError.endBeforeStart }
            guard end <= todayStart else { throw CycleRepositoryError.futureDate }
        }
        let range = dayRange(of: candidate, today: today, calendar: calendar)
        for other in existing where other.id != candidate.id {
            if dayRange(of: other, today: today, calendar: calendar).overlaps(range) {
                throw CycleRepositoryError.overlapsExistingPeriod
            }
        }
    }

    /// The period that a day log may end on `day` (phase 13 final review): the
    /// nearest period starting before `day` (so none starts in between), when
    /// `day` is at most its `longPeriodDays`-th day and, for a closed period,
    /// after its last day. Ending it there lengthens it; nil when none can be.
    /// `CycleCoordinator.endPeriod` still checks overlaps.
    public static func extendablePeriod(before day: Date, in periods: [PeriodRecord], calendar: Calendar) -> PeriodRecord? {
        let target = calendar.startOfDay(for: day)
        guard let nearest = periods
            .filter({ calendar.startOfDay(for: $0.startDate) < target })
            .max(by: { $0.startDate < $1.startDate })
        else { return nil }
        let start = calendar.startOfDay(for: nearest.startDate)
        guard let lastAllowed = calendar.date(byAdding: .day, value: longPeriodDays - 1, to: start),
              target <= lastAllowed
        else { return nil }
        if let end = nearest.endDate, calendar.startOfDay(for: end) >= target { return nil }
        return nearest
    }

    /// The period to store when the mother only knows its first day (onboarding,
    /// "add last period"): it lasted her typical length if that is already over,
    /// otherwise it is still going on.
    public static func assumedPeriod(startingOn start: Date, typicalLength: Int, today: Date, calendar: Calendar) -> PeriodRecord {
        let first = calendar.startOfDay(for: start)
        let last = calendar.date(byAdding: .day, value: typicalLength - 1, to: first) ?? first
        return PeriodRecord(startDate: first, endDate: last < calendar.startOfDay(for: today) ? last : nil)
    }

    /// What the "first day of your last period" picker allows: the past year up to today.
    public static func lastPeriodRange(now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let earliest = calendar.date(byAdding: .year, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return earliest...tomorrow.addingTimeInterval(-1)
    }

    public static func validate(_ log: CycleLogRecord, today: Date, calendar: Calendar) throws {
        guard calendar.startOfDay(for: log.day) <= calendar.startOfDay(for: today) else {
            throw CycleRepositoryError.futureDate
        }
        if let bbt = log.bbtCelsius, !temperatureRange.contains(bbt) {
            throw CycleRepositoryError.invalidTemperature
        }
    }

    /// Merges periods that overlap — only iCloud sync can create them, e.g. the
    /// same period started on two devices. An open period counts as its start day
    /// only, so this never depends on today. The merged period keeps the earliest
    /// start and the latest end (open only when every copy is open), and the id of
    /// the earliest copy. Returns the periods oldest first and the ids to delete.
    public static func mergingDuplicates(_ periods: [PeriodRecord], calendar: Calendar) -> (periods: [PeriodRecord], removedIDs: [UUID]) {
        let sorted = periods.map { normalized($0, calendar: calendar) }.sorted {
            ($0.startDate, $0.id.uuidString) < ($1.startDate, $1.id.uuidString)
        }
        var kept: [PeriodRecord] = []
        var removed: [UUID] = []
        for period in sorted {
            if var last = kept.last, period.startDate <= (last.endDate ?? last.startDate) {
                if let end = period.endDate {
                    last.endDate = max(last.endDate ?? end, end)
                }
                kept[kept.count - 1] = last
                removed.append(period.id)
            } else {
                kept.append(period)
            }
        }
        return (kept, removed)
    }

    /// Merges logs that fall on the same day (iCloud duplicates). Keeps the id
    /// that sorts first; a positive LH test wins over a negative one; the first
    /// temperature and mucus found win; distinct notes are joined by newlines;
    /// the heavier flow wins; moods, symptoms and unknown raw values are united.
    public static func mergingDuplicates(_ logs: [CycleLogRecord], calendar: Calendar) -> (logs: [CycleLogRecord], removedIDs: [UUID]) {
        let byDay = Dictionary(grouping: logs.map { normalized($0, calendar: calendar) }, by: \.day)
        var merged: [CycleLogRecord] = []
        var removed: [UUID] = []
        for day in byDay.keys.sorted() {
            let group = byDay[day, default: []].sorted { $0.id.uuidString < $1.id.uuidString }
            guard var first = group.first else { continue }
            if group.count > 1 {
                let lhs = group.compactMap(\.lh)
                first.lh = lhs.contains(.positive) ? .positive : lhs.first
                first.bbtCelsius = group.lazy.compactMap(\.bbtCelsius).first
                first.mucus = group.lazy.compactMap(\.mucus).first
                var notes: [String] = []
                for note in group.map(\.note) where !note.isEmpty && !notes.contains(note) {
                    notes.append(note)
                }
                first.note = notes.joined(separator: "\n")
                first.flow = group.compactMap(\.flow).max()
                first.moods = RawList.ordered(group.flatMap(\.moods))
                first.symptoms = RawList.ordered(group.flatMap(\.symptoms))
                first.unknownMoodsRaw = united(group.map(\.unknownMoodsRaw))
                first.unknownSymptomsRaw = united(group.map(\.unknownSymptomsRaw))
                removed += group.dropFirst().map(\.id)
            }
            merged.append(first)
        }
        return (merged, removed)
    }

    /// Every value once, in the order first seen.
    private static func united(_ lists: [[String]]) -> [String] {
        var result: [String] = []
        for value in lists.joined() where !result.contains(value) {
            result.append(value)
        }
        return result
    }
}

/// What the temperature field holds. Accepts "36.5" and "36,5".
public enum TemperatureEntry: Equatable, Sendable {
    case empty
    case valid(Double)
    /// Not a number, or outside 35.0–38.5 °C.
    case invalid

    public init(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            self = .invalid
            return
        }
        let rounded = (value * 100).rounded() / 100
        self = CycleRules.temperatureRange.contains(rounded) ? .valid(rounded) : .invalid
    }
}
