import Foundation

/// Why an edit, a missed contraction or a water-broke time is refused
/// (edit spec 2026-11-06). The screen shows a message per case.
public enum ContractionEditError: Error, Equatable, Sendable {
    case startInFuture
    case endInFuture
    case endNotAfterStart
    /// Under `ContractionRules.minDuration`.
    case tooShort
    /// Over `ContractionRules.maxDuration`.
    case tooLong
    /// Overlaps another contraction (touching is allowed).
    case overlapsNeighbour
    /// The contraction is running, or no longer stored.
    case notEditable
}

/// The live-timing rules, applied to a typed start and end: pure, so the
/// sheets and the coordinator agree.
public enum ContractionEditRules {
    /// `nil` when `start`...`end` is a valid contraction at `now`. `existing`
    /// is every stored contraction; `id` is the one being edited (ignored in
    /// the overlap check), nil when adding. A running neighbour counts as
    /// ending at `now`, or at start + `maxDuration` when its stop was forgotten.
    public static func validate(
        id: UUID?, start: Date, end: Date, existing: [ContractionRecord], now: Date
    ) -> ContractionEditError? {
        if start > now { return .startInFuture }
        if end > now { return .endInFuture }
        if end <= start { return .endNotAfterStart }
        let length = end.timeIntervalSince(start)
        if length < ContractionRules.minDuration { return .tooShort }
        if length > ContractionRules.maxDuration { return .tooLong }
        for other in existing where other.id != id {
            let otherEnd = other.endedAt
                ?? min(max(now, other.startedAt), other.startedAt.addingTimeInterval(ContractionRules.maxDuration))
            if start < otherEnd, end > other.startedAt { return .overlapsNeighbour }
        }
        return nil
    }

    /// A marker's time cannot be in the future.
    public static func validateMarker(at: Date, now: Date) -> ContractionEditError? {
        at > now ? .startInFuture : nil
    }

    /// The minute picked on a minute-resolution picker, with the seconds the
    /// time had before: a 45 s contraction can be moved without becoming 0 s.
    public static func keepingSeconds(of original: Date, in picked: Date, calendar: Calendar) -> Date {
        let seconds = calendar.component(.second, from: original)
        let nanos = calendar.component(.nanosecond, from: original)
        var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: picked)
        parts.second = seconds
        parts.nanosecond = nanos
        return calendar.date(from: parts) ?? picked
    }
}

/// The times in an edit sheet. Adding a missed contraction keeps its length
/// when the start moves; editing keeps the end.
public struct ContractionDraft: Equatable, Sendable {
    public private(set) var start: Date
    public private(set) var end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    /// A minute ago, a minute long: it ended just now.
    public static func missed(now: Date) -> ContractionDraft {
        ContractionDraft(start: now.addingTimeInterval(-60), end: now)
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public mutating func setStart(_ newStart: Date, keepingLength: Bool) {
        if keepingLength { end = newStart.addingTimeInterval(duration) }
        start = newStart
    }

    public mutating func setEnd(_ newEnd: Date) { end = newEnd }

    public mutating func setDuration(_ seconds: TimeInterval) { end = start.addingTimeInterval(seconds) }
}
