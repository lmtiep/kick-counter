import Foundation

/// Coalesces changes into one upload (phase 8 spec §3.3): a publish is due
/// once `quietPeriod` has passed since the last change. Becoming active counts
/// as a change at most once every `activeRefreshInterval`. Pure value; the
/// caller passes the time.
public struct PartnerPublishScheduler: Equatable, Sendable {
    public static let quietPeriod: TimeInterval = 5
    public static let activeRefreshInterval: TimeInterval = 6 * 60 * 60

    public private(set) var lastChange: Date?
    public private(set) var lastPublished: Date?

    /// `lastPublished`: the last successful upload, kept across launches by the caller.
    public init(lastPublished: Date? = nil) {
        self.lastPublished = lastPublished
    }

    public var hasPendingChange: Bool { lastChange != nil }

    public mutating func noteChange(at now: Date) {
        lastChange = now
    }

    /// The app became active: a change unless something was published in the last six hours.
    public mutating func noteBecameActive(at now: Date) {
        if let lastPublished, now.timeIntervalSince(lastPublished) < Self.activeRefreshInterval { return }
        noteChange(at: now)
    }

    /// Seconds still to wait, 0 when a publish is due now, nil when nothing is pending.
    public func delay(at now: Date) -> TimeInterval? {
        guard let lastChange else { return nil }
        return max(0, Self.quietPeriod - now.timeIntervalSince(lastChange))
    }

    public func isDue(at now: Date) -> Bool {
        delay(at: now) == 0
    }

    /// An upload starts: the pending change is taken. A change noted while the
    /// upload runs is pending again and gets its own publish.
    public mutating func startPublishing() {
        lastChange = nil
    }

    /// The upload succeeded. A failed upload calls nothing: the next trigger publishes again.
    public mutating func didPublish(at now: Date) {
        lastPublished = now
    }
}
