import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "contractions")

public enum ContractionFailure: Error, Equatable, Sendable {
    case loadFailed
    case saveFailed
}

/// What the Lock Screen's button meant: the state it showed when tapped.
public enum ContractionToggleAction: String, Equatable, Sendable {
    case start
    case stop
}

/// What an edit, an added missed contraction or a marker came to.
public enum ContractionEditOutcome: Equatable, Sendable {
    case saved
    /// Refused before anything was written; the sheet shows why.
    case invalid(ContractionEditError)
    /// The store failed (`ContractionCoordinator.failure` is set).
    case failed
}

/// What a tap on the big button did.
public enum ContractionToggle: Equatable, Sendable {
    /// A new contraction is running (after closing a forgotten one at
    /// start + `maxDuration`, if one was still open).
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
    /// Every stored labour marker ("Vỡ ối"), oldest first.
    public private(set) var markers: [LabourMarkerRecord] = []
    /// When "Kết thúc theo dõi" was last tapped (`SettingsKey.contractionEpisodeEndedAt`).
    public private(set) var episodeEndedAt: Date?
    /// Store errors for the screen's alert.
    public private(set) var failure: ContractionFailure?
    /// The last tap, which "Hoàn tác" reverts while `canUndo`. It is the most
    /// recent tap from either the timer screen or the Lock Screen's button
    /// (`ToggleContractionIntent`): both go through `toggle`, so "Hoàn tác" on
    /// the screen may revert a tap made on the Lock Screen a moment before.
    public private(set) var lastToggle: ContractionToggle?
    private var lastToggleAt: Date?

    private let store: ContractionRepository
    private let markerStore: LabourMarkerRepository
    private let liveActivities: ContractionLiveActivityManaging
    private let notifications: NotificationScheduler?
    private let alertText: @MainActor (ContractionAlert) -> NotificationText?
    private let defaults: UserDefaults
    private let week: @MainActor () -> GestationalWeek?
    private let undoWindow: TimeInterval
    private let now: @MainActor () -> Date
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    /// - Parameters:
    ///   - notifications: posts the one-time alert notification; nil posts none.
    ///   - alertText: the notification's text for an alert, in the current language.
    ///   - week: the real gestational week (nil when unknown), for the alert on
    ///     the Lock Screen and in the notification.
    ///   - undoWindow: how long "Hoàn tác" is offered (UI tests lengthen it).
    public init(
        store: ContractionRepository,
        markers markerStore: LabourMarkerRepository = InMemoryLabourMarkerRepository(),
        liveActivities: ContractionLiveActivityManaging,
        notifications: NotificationScheduler? = nil,
        alertText: @escaping @MainActor (ContractionAlert) -> NotificationText? = { _ in nil },
        defaults: UserDefaults,
        week: @escaping @MainActor () -> GestationalWeek? = { nil },
        undoWindow: TimeInterval = ContractionRules.undoWindow,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.markerStore = markerStore
        self.liveActivities = liveActivities
        self.notifications = notifications
        self.alertText = alertText
        self.defaults = defaults
        self.week = week
        self.undoWindow = undoWindow
        self.now = now
        episodeEndedAt = defaults.object(forKey: SettingsKey.contractionEpisodeEndedAt) as? Date
    }

    public var liveActivitiesAvailable: Bool { liveActivities.isAvailable }

    /// The running contraction, if any.
    public var running: ContractionRecord? {
        contractions.last.flatMap { $0.isRunning ? $0 : nil }
    }

    /// When "Hoàn tác" stops being offered: the undo window after the last tap.
    /// Nil when there is nothing to undo.
    public var undoDeadline: Date? {
        guard lastToggle != nil, let lastToggleAt else { return nil }
        return lastToggleAt.addingTimeInterval(undoWindow)
    }

    /// True until `undoDeadline` (`ContractionRules.undoWindow` after a tap).
    public var canUndo: Bool {
        guard let undoDeadline else { return false }
        return now() <= undoDeadline
    }

    /// The screen's numbers and alert at `date` (default: now). `week` is nil
    /// when the pregnancy week is unknown.
    public func stats(week: GestationalWeek?, at date: Date? = nil) -> ContractionStats {
        ContractionStats(
            contractions: contractions, now: date ?? now(), week: week, episodeEndedAt: episodeEndedAt, markers: markers
        )
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

    /// Starts a contraction, or stops the running one. A contraction running
    /// longer than `maxDuration` is one whose stop was forgotten: the screen
    /// already shows "Bắt đầu", so the tap closes it at start + `maxDuration`
    /// and starts a new one.
    ///
    /// `action` is what the Lock Screen's button showed (nil from the screen):
    /// a stop closes even a forgotten contraction without starting another, and
    /// an action that no longer matches the state (a start while one runs, a
    /// stop with none) does nothing and returns nil. Nil also when the store failed.
    ///
    /// When the alert turns on with this tap, posts its notification once (`notifyAlert`).
    @discardableResult
    public func toggle(_ action: ContractionToggleAction? = nil) async -> ContractionToggle? {
        guard refresh() else { return nil }
        let time = now()
        let week = week()
        let alertBefore = stats(week: week, at: time).alert
        let result: ContractionToggle?
        if let open = running {
            let forgotten = ContractionRules.isForgotten(open, now: time)
            if action == .stop || (action == nil && !forgotten) {
                result = stop(open, at: time)
            } else if forgotten {
                result = write { try store.save(ContractionRules.closingForgotten(open)) } ? start(at: time) : nil
            } else {
                // A start from an out-of-date Lock Screen while one runs.
                await syncLiveActivity()
                return nil
            }
        } else if action == .stop {
            // A stop from an out-of-date Lock Screen with none running.
            await syncLiveActivity()
            return nil
        } else {
            result = start(at: time)
        }
        lastToggle = result
        lastToggleAt = result == nil ? nil : time
        refresh()
        await syncLiveActivity()
        if result != nil {
            await notifyAlert(before: alertBefore, week: week, at: time)
        }
        return result
    }

    /// "Hoàn tác": reverts the last tap while `canUndo`, once. The last tap is
    /// the most recent one from the screen or the Lock Screen (see `lastToggle`).
    /// False when there was nothing to undo or the store failed.
    @discardableResult
    public func undoLast() async -> Bool {
        guard canUndo, let toggle = lastToggle else { return false }
        lastToggle = nil
        lastToggleAt = nil
        let reverted: Bool
        switch toggle {
        case .started(let record):
            // Only the new contraction: a forgotten one closed by the same tap stays closed.
            reverted = write { try store.delete(ids: [record.id]) }
        case .stopped(let record):
            var reopened = record
            reopened.endedAt = nil
            reverted = write { try store.save(reopened) }
        case .discarded(let record):
            reverted = write { try store.save(record) }
        }
        refresh()
        await syncLiveActivity()
        return reverted
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
    /// Every contraction is kept. Also run by the Lock Screen's "Kết thúc"
    /// (`EndContractionTrackingIntent`), which cannot ask for confirmation:
    /// that is safe because nothing is lost and the 5-1-1 alert's run
    /// (`ContractionStats.alertRun`) ignores the end mark.
    /// Changes nothing and returns false when the store cannot be read or the
    /// running contraction cannot be stopped.
    @discardableResult
    public func endEpisode() async -> Bool {
        let time = now()
        guard refresh() else { return false }
        if let open = running, stop(open, at: time) == nil { return false }
        episodeEndedAt = time
        defaults.set(time, forKey: SettingsKey.contractionEpisodeEndedAt)
        lastToggle = nil
        lastToggleAt = nil
        refresh()
        await syncLiveActivity()
        return true
    }

    // MARK: - Editing (edit spec 2026-11-06)

    /// Moves a completed contraction to `start`...`end`. The live-timing rules
    /// apply (`ContractionEditRules`); nothing is written when they refuse.
    /// A running contraction is not editable: stop it first.
    @discardableResult
    public func update(id: UUID, start: Date, end: Date) async -> ContractionEditOutcome {
        await change { contractions, time in
            guard let current = contractions.first(where: { $0.id == id }), !current.isRunning else {
                return .invalid(.notEditable)
            }
            if let error = ContractionEditRules.validate(id: id, start: start, end: end, existing: contractions, now: time) {
                return .invalid(error)
            }
            var edited = current
            edited.startedAt = start
            edited.endedAt = end
            return write { try store.save(edited) } ? .saved : .failed
        }
    }

    /// Adds a contraction she did not time: it joins the episode its time falls in.
    @discardableResult
    public func addMissed(start: Date, duration: TimeInterval) async -> ContractionEditOutcome {
        await change { contractions, time in
            let end = start.addingTimeInterval(duration)
            if let error = ContractionEditRules.validate(id: nil, start: start, end: end, existing: contractions, now: time) {
                return .invalid(error)
            }
            let record = ContractionRecord(startedAt: start, endedAt: end)
            return write { try store.save(record) } ? .saved : .failed
        }
    }

    /// "Vỡ ối": records when the water broke.
    @discardableResult
    public func markWaterBroke(at time: Date) async -> ContractionEditOutcome {
        await changeMarkers { _, now in
            if let error = ContractionEditRules.validateMarker(at: time, now: now) { return .invalid(error) }
            let record = LabourMarkerRecord(at: time)
            return write { try markerStore.save(record) } ? .saved : .failed
        }
    }

    @discardableResult
    public func updateMarker(id: UUID, at time: Date) async -> ContractionEditOutcome {
        await changeMarkers { markers, now in
            guard var marker = markers.first(where: { $0.id == id }) else { return .invalid(.notEditable) }
            if let error = ContractionEditRules.validateMarker(at: time, now: now) { return .invalid(error) }
            marker.at = time
            return write { try markerStore.save(marker) } ? .saved : .failed
        }
    }

    public func deleteMarker(id: UUID) async {
        await changeMarkers { _, _ in
            write { try markerStore.delete(ids: [id]) } ? .saved : .failed
        }
    }

    /// Runs `edit` on the freshly read contractions, then recomputes: reads the
    /// store again, reconciles the Live Activity and posts the alert's
    /// notification when this edit newly turned it on (never when it turned it off).
    private func change(
        _ edit: ([ContractionRecord], Date) -> ContractionEditOutcome
    ) async -> ContractionEditOutcome {
        guard refresh() else { return .failed }
        let time = now()
        let week = week()
        let alertBefore = stats(week: week, at: time).alert
        let outcome = edit(contractions, time)
        guard outcome == .saved else { return outcome }
        lastToggle = nil
        lastToggleAt = nil
        refresh()
        await syncLiveActivity()
        await notifyAlert(before: alertBefore, week: week, at: time)
        return outcome
    }

    private func changeMarkers(
        _ edit: ([LabourMarkerRecord], Date) -> ContractionEditOutcome
    ) async -> ContractionEditOutcome {
        guard refresh() else { return .failed }
        let outcome = edit(markers, now())
        if outcome == .saved { refresh() }
        return outcome
    }

    /// Partner mode, or the app left pregnancy mode: ends every contraction Live
    /// Activity, keeping the contractions and the episode. `load()` shows the
    /// current episode again when pregnancy mode comes back.
    public func endLiveActivity() async {
        let previous = syncTask
        let task = Task {
            await previous?.value
            await self.liveActivities.endAll()
        }
        syncTask = task
        await task.value
    }

    /// "Delete all data" emptied the store and the defaults underneath: forgets
    /// everything shown and ends the Live Activity. Call right after.
    public func resetAfterDataDeletion() async {
        contractions = []
        markers = []
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

    private func start(at time: Date) -> ContractionToggle? {
        let record = ContractionRecord(startedAt: time)
        return write { try store.save(record) } ? .started(record) : nil
    }

    /// Ends `open` at `time`: at start + `maxDuration` when forgotten, or drops
    /// it as a mis-tap. A clock moved backwards ends it at its start (a mis-tap).
    @discardableResult
    private func stop(_ open: ContractionRecord, at time: Date) -> ContractionToggle? {
        if ContractionRules.isForgotten(open, now: time) {
            let closed = ContractionRules.closingForgotten(open)
            return write { try store.save(closed) } ? .stopped(closed) : nil
        }
        var closed = open
        closed.endedAt = max(time, open.startedAt)
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
            markers = try markerStore.markers()
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

    /// Posts the alert's notification when this tap turned it on (from none),
    /// once per run of contractions and alert (`SettingsKey.contractionAlertNotified`),
    /// only when notifications are already allowed: never a permission prompt.
    private func notifyAlert(before: ContractionAlert, week: GestationalWeek?, at time: Date) async {
        let after = stats(week: week, at: time)
        guard before == .none, after.alert != .none, let notifications, let text = alertText(after.alert) else { return }
        let run = after.alertRun?.id.uuidString ?? after.alert.rawValue
        let key = "\(run):\(after.alert.rawValue)"
        guard defaults.string(forKey: SettingsKey.contractionAlertNotified) != key,
              await notifications.isAuthorized(),
              defaults.string(forKey: SettingsKey.contractionAlertNotified) != key
        else { return }
        defaults.set(key, forKey: SettingsKey.contractionAlertNotified)
        do {
            try await notifications.postNow(id: NotificationScheduler.contractionAlertID(run), text: text)
        } catch {
            logger.error("Posting the contraction alert failed: \(error.localizedDescription)")
            defaults.removeObject(forKey: SettingsKey.contractionAlertNotified)
        }
    }

    /// Shows the current episode, or ends every contraction activity without one.
    private func applyLiveActivity() async {
        let stats = stats(week: week())
        guard let episode = stats.currentEpisode else {
            await liveActivities.endAll()
            return
        }
        guard liveActivities.isAvailable else { return }
        let state = Self.activityState(for: episode, alert: stats.alert)
        let staleDate = episode.lastStartedAt.addingTimeInterval(ContractionRules.episodeGap)
        if liveActivities.hasActivity(for: episode.id) {
            await liveActivities.update(episodeID: episode.id, state: state, staleDate: staleDate)
        } else {
            await liveActivities.start(episodeID: episode.id, startedAt: episode.startedAt, state: state, staleDate: staleDate)
        }
    }

    static func activityState(for episode: ContractionEpisode, alert: ContractionAlert) -> ContractionActivityState {
        let last = episode.entries[episode.entries.count - 1]
        return ContractionActivityState(
            runningSince: last.isRunning ? last.startedAt : nil,
            count: episode.count,
            lastInterval: last.interval,
            lastDuration: episode.completed.last?.duration,
            restingSince: last.isRunning ? nil : last.record.endedAt,
            alert: alert
        )
    }
}
