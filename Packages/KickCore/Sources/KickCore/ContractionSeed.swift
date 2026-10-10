import Foundation

/// "m:ss" for contraction lengths and intervals (phase 20 spec §4.2), "h:mm:ss"
/// from one hour. Rounded to the second.
public enum ContractionClock {
    public static func text(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, rest)
        }
        return String(format: "%d:%02d", minutes, rest)
    }
}

/// Sample contractions for UI tests and screenshots (`-uiTesting -seedContractions
/// <scenario>`), relative to the real clock (the timer never uses the pinned one).
/// Both include a past episode the day before, for the history.
public enum ContractionSeed: String, CaseIterable, Sendable {
    /// Every 5 minutes for 64 minutes, 60 s each: the 5-1-1 card from week 37.
    case fiveOneOne = "511"
    /// Five contractions in the last 45 minutes, 50 s each: the urgent card before week 37.
    case preterm

    public func records(now: Date) -> [ContractionRecord] {
        let current: [ContractionRecord] = switch self {
        case .fiveOneOne:
            stride(from: 64.0, through: 4, by: -5).map { minutesAgo in
                Self.record(now: now, minutesAgo: minutesAgo, seconds: 60)
            }
        case .preterm:
            [45.0, 35, 25, 15, 5].map { Self.record(now: now, minutesAgo: $0, seconds: 50) }
        }
        let yesterday: Double = 26 * 60
        let pastMinutesAgo: [Double] = [yesterday, yesterday - 9, yesterday - 17]
        let past = pastMinutesAgo.map { Self.record(now: now, minutesAgo: $0, seconds: 40) }
        return past + current
    }

    private static func record(now: Date, minutesAgo: Double, seconds: TimeInterval) -> ContractionRecord {
        let start = now.addingTimeInterval(-minutesAgo * 60)
        return ContractionRecord(startedAt: start, endedAt: start.addingTimeInterval(seconds))
    }
}
