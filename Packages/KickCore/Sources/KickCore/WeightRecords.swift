import Foundation

/// One logged weight (value snapshot of the SwiftData `WeightEntry`).
public struct WeightRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    /// Start of the calendar day.
    public var day: Date
    /// 30.0–200.0 kg, one decimal.
    public var kg: Double

    public init(id: UUID = UUID(), day: Date, kg: Double) {
        self.id = id
        self.day = day
        self.kg = kg
    }
}

public enum WeightRepositoryError: Error, Equatable, Sendable {
    case futureDate
    case outOfRange
}

/// Storage for the mother's weights. Implementations validate every write with
/// `WeightRules` and merge iCloud duplicates on read.
@MainActor
public protocol WeightRepository: AnyObject {
    /// Every entry, oldest first, one per day.
    func entries() throws -> [WeightRecord]
    /// Stores the entry for `entry.day`, replacing the weight already stored for
    /// that day (which keeps its id). Throws `.futureDate` or `.outOfRange`.
    func save(_ entry: WeightRecord, today: Date) throws
    /// No-op when no entry has that id (it may already be gone via iCloud).
    func delete(id: UUID) throws
}

/// Validation and duplicate merging shared by `WeightStore` and the test fake.
public enum WeightRules {
    public static let kgRange: ClosedRange<Double> = 30.0...200.0

    /// One decimal, as entered and shown.
    public static func rounded(_ kg: Double) -> Double {
        (kg * 10).rounded() / 10
    }

    public static func normalized(_ entry: WeightRecord, calendar: Calendar) -> WeightRecord {
        WeightRecord(id: entry.id, day: calendar.startOfDay(for: entry.day), kg: rounded(entry.kg))
    }

    public static func validate(_ entry: WeightRecord, today: Date, calendar: Calendar) throws {
        guard calendar.startOfDay(for: entry.day) <= calendar.startOfDay(for: today) else {
            throw WeightRepositoryError.futureDate
        }
        guard entry.kg.isFinite, kgRange.contains(rounded(entry.kg)) else {
            throw WeightRepositoryError.outOfRange
        }
    }

    /// Several entries on one day can only come from iCloud sync. Keeps the one
    /// whose id sorts first (`uuidString`) with its own weight, so every device
    /// picks the same one. Returns the entries oldest first and the ids to delete.
    public static func mergingDuplicates(_ entries: [WeightRecord], calendar: Calendar) -> (entries: [WeightRecord], removedIDs: [UUID]) {
        let byDay = Dictionary(grouping: entries.map { normalized($0, calendar: calendar) }, by: \.day)
        var kept: [WeightRecord] = []
        var removed: [UUID] = []
        for day in byDay.keys.sorted() {
            let group = byDay[day, default: []].sorted { $0.id.uuidString < $1.id.uuidString }
            guard let first = group.first else { continue }
            kept.append(first)
            removed += group.dropFirst().map(\.id)
        }
        return (kept, removed)
    }

    /// What the entry's date picker allows: from the first day of the last
    /// period (due date − 280 days) to the end of today.
    public static func dayRange(dueDate: Date, now: Date, calendar: Calendar) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let lmp = calendar.date(byAdding: .day, value: -PregnancyTimeline.pregnancyLengthDays, to: calendar.startOfDay(for: dueDate)) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return min(lmp, today)...tomorrow.addingTimeInterval(-1)
    }
}

/// What a decimal field holds ("56,2" or "56.2"), rounded to `fractionDigits`
/// and checked against `range`.
public enum DecimalEntry: Equatable, Sendable {
    case empty
    case valid(Double)
    /// Not a number, or outside the range.
    case invalid

    public init(text: String, range: ClosedRange<Double>, fractionDigits: Int = 1) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")), value.isFinite else {
            self = .invalid
            return
        }
        let scale = pow(10, Double(fractionDigits))
        let rounded = (value * scale).rounded() / scale
        self = range.contains(rounded) ? .valid(rounded) : .invalid
    }
}
