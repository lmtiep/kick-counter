import Foundation

/// One timed contraction (value snapshot of the SwiftData `Contraction`, phase 20).
/// `endedAt == nil` while it is running; at most one is running.
public struct ContractionRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date?

    public init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public var isRunning: Bool { endedAt == nil }
}

public enum ContractionError: Error, Equatable, Sendable {
    /// `endedAt` is before `startedAt`.
    case endBeforeStart
    /// Another contraction is already running.
    case alreadyRunning
}

/// What the timer screen shows above the list (spec §3.2, §4.3).
public enum ContractionAlert: String, Codable, Equatable, Sendable {
    case none
    /// Week 37 or later (or unknown): regular contractions about 5 minutes
    /// apart, about 1 minute long, for an hour.
    case fiveOneOne
    /// Before week 37: regular contractions (`pretermMinCount` in the last hour).
    case pretermRegular
}

/// Storage for the timed contractions. At most one is running.
@MainActor
public protocol ContractionRepository: AnyObject {
    /// Every contraction, oldest start first.
    func contractions() throws -> [ContractionRecord]
    /// Inserts `record`, or replaces the one with its id. Throws
    /// `ContractionError` when `ContractionRules.validate` refuses it.
    func save(_ record: ContractionRecord) throws
    /// Ids that are not stored are ignored.
    func delete(ids: [UUID]) throws
}

/// The contraction thresholds (phase 20 spec §3.2). Every value is for the
/// doctor to confirm: `docs/content-review-for-doctor.md` §18, items 96–99.
public enum ContractionRules {
    /// Consecutive contractions whose starts are at most this far apart belong
    /// to one episode. The Live Activity also ends after this long without a
    /// new contraction.
    public static let episodeGap: TimeInterval = 2 * 60 * 60
    /// The "last hour" the stats and both alerts look at (items 96, 97).
    public static let window: TimeInterval = 60 * 60
    /// From this week the 5-1-1 rule applies; before it, the preterm rule (item 97).
    public static let termWeek = 37
    /// Preterm: this many completed contractions started in the last hour (item 97).
    public static let pretermMinCount = 4
    /// 5-1-1: the average interval in the last hour is at most 5:30 (item 96).
    public static let fiveOneOneMaxAverageInterval: TimeInterval = 5 * 60 + 30
    /// 5-1-1: the average duration in the last hour is at least 45 s (item 96).
    public static let fiveOneOneMinAverageDuration: TimeInterval = 45
    /// 5-1-1: at least this many completed contractions in the last hour (item 96).
    public static let fiveOneOneMinCount = 6
    /// 5-1-1: the current episode's completed contractions span at least an
    /// hour, first start to last start (item 96).
    public static let fiveOneOneMinSpan: TimeInterval = 60 * 60
    /// A contraction running longer than this was a forgotten stop: it is
    /// closed at start + `maxDuration` (item 99).
    public static let maxDuration: TimeInterval = 5 * 60
    /// A contraction shorter than this is a mis-tap and is dropped (item 99).
    public static let minDuration: TimeInterval = 3
    /// "Hoàn tác" is offered this long after a tap (spec §4.2). UI tests may
    /// lengthen it (`-contractionUndoWindow`).
    public static let undoWindow: TimeInterval = 5

    /// The store's rules, shared by `ContractionStore` and the test fake.
    public static func validate(_ record: ContractionRecord, existing: [ContractionRecord]) throws {
        if let end = record.endedAt, end < record.startedAt { throw ContractionError.endBeforeStart }
        if record.isRunning, existing.contains(where: { $0.isRunning && $0.id != record.id }) {
            throw ContractionError.alreadyRunning
        }
    }

    /// Running for longer than `maxDuration` at `now`.
    public static func isForgotten(_ record: ContractionRecord, now: Date) -> Bool {
        record.isRunning && now.timeIntervalSince(record.startedAt) > maxDuration
    }

    /// The record closed at start + `maxDuration`.
    public static func closingForgotten(_ record: ContractionRecord) -> ContractionRecord {
        var closed = record
        closed.endedAt = record.startedAt.addingTimeInterval(maxDuration)
        return closed
    }

    /// Completed in under `minDuration`.
    public static func isMisTap(_ record: ContractionRecord) -> Bool {
        guard let end = record.endedAt else { return false }
        return end.timeIntervalSince(record.startedAt) < minDuration
    }

    /// The records the stats count, oldest first: a start in the future, an end
    /// before the start and a mis-tap are dropped; a contraction over
    /// `maxDuration` (running or not), and a running one that is not the
    /// newest, is closed at start + `maxDuration`.
    public static func normalized(_ records: [ContractionRecord], now: Date) -> [ContractionRecord] {
        let valid = records
            .filter { record in record.startedAt <= now && (record.endedAt.map { $0 >= record.startedAt } ?? true) }
            .sorted { $0.startedAt < $1.startedAt }
        return valid.enumerated().compactMap { index, record in
            let isNewest = index == valid.count - 1
            if record.isRunning {
                return isNewest && !isForgotten(record, now: now) ? record : closingForgotten(record)
            }
            if isMisTap(record) { return nil }
            if let end = record.endedAt, end.timeIntervalSince(record.startedAt) > maxDuration {
                return closingForgotten(record)
            }
            return record
        }
    }
}
