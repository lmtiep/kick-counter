import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "contractions")

public enum ContractionFailure: Error, Equatable, Sendable {
    case loadFailed
    case saveFailed
}

/// What a tap on the big button did.
public enum ContractionToggle: Equatable, Sendable {
    /// A new contraction is running.
    case started(ContractionRecord)
    /// The running contraction ended (at the tap, or at start + `maxDuration`
    /// when the stop was forgotten).
    case stopped(ContractionRecord)
    /// The running contraction lasted under `minDuration`: dropped as a mis-tap.
    /// The record is as it was while running.
    case discarded(ContractionRecord)
}

/// The contraction timer (phase 20 spec §3.3): the single entry point for the
/// timer screen and for `ToggleContractionIntent`. It keeps the store, the
/// "episode ended" mark and the Live Activity in step.
///
/// Live Activity changes run one after another, each from the state current
/// when it runs, so a tap during an in-flight ActivityKit request never starts
/// a second activity or leaves an older state showing.
@MainActor
@Observable
public final class ContractionCoordinator {
    /// Every stored contraction, oldest start first.
    public private(set) var contractions: [ContractionRecord] = []
    /// When "Kết thúc theo dõi" was last tapped (`SettingsKey.contractionEpisodeEndedAt`).
    public private(set) var episodeEndedAt: Date?
    /// Store errors for the screen's alert.
    public private(set) var failure: ContractionFailure?
    /// The last tap, which "Hoàn tác" reverts while `canUndo`.
    public private(set) var lastToggle: ContractionToggle?
    private var lastToggleAt: Date?

    private let store: ContractionRepository
    private let liveActivities: ContractionLiveActivityManaging
    private let defaults: UserDefaults
    private let now: @MainActor () -> Date
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    public init(
        store: ContractionRepository,
        liveActivities: ContractionLiveActivityManaging,
        defaults: UserDefaults,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.liveActivities = liveActivities
        self.defaults = defaults
        self.now = now
        episodeEndedAt = defaults.object(forKey: SettingsKey.contractionEpisodeEndedAt) as? Date
    }

    public var liveActivitiesAvailable: Bool { liveActivities.isAvailable }

    /// The running contraction, if any.
    public var running: ContractionRecord? {
        contractions.last.flatMap { $0.isRunning ? $0 : nil }
    }

    /// True for `ContractionRules.undoWindow` seconds after a tap.
    public var canUndo: Bool {
        guard lastToggle != nil, let lastToggleAt else { return false }
        return now().timeIntervalSince(lastToggleAt) <= ContractionRules.undoWindow
    }

    /// The screen's numbers and alert at `date` (default: now). `week` is nil
    /// when the pregnancy week is unknown.
    public func stats(week: GestationalWeek?, at date: Date? = nil) -> ContractionStats {
        ContractionStats(contractions: contractions, now: date ?? now(), week: week, episodeEndedAt: episodeEndedAt)
    }

    /// Re-reads the store and the episode mark, closes a forgotten contraction
    /// and reconciles the Live Activity (ending it after 2 hours without a new
    /// contraction). Call on launch and whenever the app becomes active.
    public func load() async {
        episodeEndedAt = defaults.object(forKey: SettingsKey.contractionEpisodeEndedAt) as? Date
        guard refresh() else { return }
        if let open = running, ContractionRules.isForgotten(open, now: now()) {
            write { try store.save(ContractionRules.closingForgotten(open)) }
            refresh()
        }
        await syncLiveActivity()
    }

    /// Starts a contraction, or stops the running one. Nil when the store failed.
    @discardableResult
    public func toggle() async -> ContractionToggle? {
        guard refresh() else { return nil }
        let time = now()
        let result: ContractionToggle?
        if let open = running {
            result = stop(open, at: time)
        } else {
            let record = ContractionRecord(startedAt: time)
            result = write { try store.save(record) } ? .started(record) : nil
        }
        lastToggle = result
        lastToggleAt = result == nil ? nil : time
        refresh()
        await syncLiveActivity()
        return result
    }

    /// "Hoàn tác": reverts the last tap while `canUndo`, once.
    public func undoLast() async {
        guard canUndo, let toggle = lastToggle else { return }
        lastToggle = nil
        lastToggleAt = nil
        switch toggle {
        case .started(let record):
            write { try store.delete(ids: [record.id]) }
        case .stopped(let record):
            var reopened = record
            reopened.endedAt = nil
            write { try store.save(reopened) }
        case .discarded(let record):
            write { try store.save(record) }
        }
        refresh()
        await syncLiveActivity()
    }

    public func delete(id: UUID) async {
        await delete(ids: [id])
    }

    /// Deletes these contractions (a row, or a whole episode from history).
    public func delete(ids: [UUID]) async {
        lastToggle = nil
        lastToggleAt = nil
        write { try store.delete(ids: ids) }
        refresh()
        await syncLiveActivity()
    }

    /// "Kết thúc theo dõi": stops the running contraction, ends the episode
    /// (the next contraction starts a new one) and ends the Live Activity.
    public func endEpisode() async {
        let time = now()
        if refresh(), let open = running {
            stop(open, at: time)
        }
        episodeEndedAt = time
        defaults.set(time, forKey: SettingsKey.contractionEpisodeEndedAt)
        lastToggle = nil
        lastToggleAt = nil
        refresh()
        await syncLiveActivity()
    }

    /// "Delete all data" emptied the store and the defaults underneath: forgets
    /// everything shown and ends the Live Activity. Call right after.
    public func resetAfterDataDeletion() async {
        contractions = []
        episodeEndedAt = nil
        lastToggle = nil
        lastToggleAt = nil
        failure = nil
        await syncLiveActivity()
    }

    public func clearFailure() {
        failure = nil
    }

    // MARK: - Internals

    /// Ends `open` at `time`: at start + `maxDuration` when forgotten, or drops
    /// it as a mis-tap.
    @discardableResult
    private func stop(_ open: ContractionRecord, at time: Date) -> ContractionToggle? {
        if ContractionRules.isForgotten(open, now: time) {
            let closed = ContractionRules.closingForgotten(open)
            return write { try store.save(closed) } ? .stopped(closed) : nil
        }
        var closed = open
        closed.endedAt = time
        if ContractionRules.isMisTap(closed) {
            return write { try store.delete(ids: [open.id]) } ? .discarded(open) : nil
        }
        return write { try store.save(closed) } ? .stopped(closed) : nil
    }

    @discardableResult
    private func write(_ change: () throws -> Void) -> Bool {
        do {
            try change()
            return true
        } catch {
            logger.error("Saving a contraction failed: \(error.localizedDescription)")
            failure = .saveFailed
            return false
        }
    }

    @discardableResult
    private func refresh() -> Bool {
        do {
            contractions = try store.contractions()
            if failure == .loadFailed { failure = nil }
            return true
        } catch {
            logger.error("Loading contractions failed: \(error.localizedDescription)")
            failure = .loadFailed
            return false
        }
    }

    /// Queues a Live Activity reconciliation behind any in flight and waits for it.
    private func syncLiveActivity() async {
        let previous = syncTask
        let task = Task {
            await previous?.value
            await self.applyLiveActivity()
        }
        syncTask = task
        await task.value
    }

    /// Shows the current episode, or ends every contraction activity without one.
    private func applyLiveActivity() async {
        guard let episode = stats(week: nil).currentEpisode else {
            await liveActivities.endAll()
            return
        }
        guard liveActivities.isAvailable else { return }
        let state = Self.activityState(for: episode)
        let staleDate = episode.lastStartedAt.addingTimeInterval(ContractionRules.episodeGap)
        if liveActivities.hasActivity(for: episode.id) {
            await liveActivities.update(episodeID: episode.id, state: state, staleDate: staleDate)
        } else {
            await liveActivities.start(episodeID: episode.id, startedAt: episode.startedAt, state: state, staleDate: staleDate)
        }
    }

    static func activityState(for episode: ContractionEpisode) -> ContractionActivityState {
        let last = episode.entries[episode.entries.count - 1]
        return ContractionActivityState(
            runningSince: last.isRunning ? last.startedAt : nil,
            count: episode.count,
            lastInterval: last.interval,
            lastDuration: episode.completed.last?.duration
        )
    }
}
