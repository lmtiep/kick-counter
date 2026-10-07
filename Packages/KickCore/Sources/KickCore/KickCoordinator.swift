import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "coordinator")

public enum KickFailure: Equatable, Sendable {
    case loadFailed
    case saveFailed
}

/// Single entry point for counting actions, used by the UI and by AddKickIntent.
/// Keeps the repository, the overdue notification and the Live Activity in step.
///
/// Every Live Activity call is scoped to a session id, and every side-effect
/// sequence re-checks `activeSessionID` after each `await` before touching that
/// session's Live Activity or overdue alert again, so a session that completes,
/// is cancelled, or is superseded while a side effect is in flight can't corrupt
/// another session's state (see task-6-fix-round-1.md for the defects this guards
/// against).
@MainActor
@Observable
public final class KickCoordinator {
    public static let completedActivityLinger: TimeInterval = 15 * 60

    public private(set) var activeSession: SessionState?
    public private(set) var activeSessionID: UUID?
    public private(set) var completedSession: SessionState?
    public private(set) var failure: KickFailure?

    private let store: SessionRepository
    private let notifications: NotificationScheduler
    private let liveActivities: LiveActivityManaging
    @ObservationIgnored private var overdueText: NotificationText
    private let now: @MainActor () -> Date

    /// The session whose Live Activity `start` call is currently in flight, so
    /// `load()` never races it into starting a second activity for the same session.
    private var startingSessionID: UUID?
    /// The in-flight `load()` reconciliation, so concurrent callers await the
    /// same run instead of each starting their own.
    private var loadTask: Task<Void, Never>?

    public init(
        store: SessionRepository,
        notifications: NotificationScheduler,
        liveActivities: LiveActivityManaging,
        overdueText: NotificationText,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.liveActivities = liveActivities
        self.overdueText = overdueText
        self.now = now
    }

    public var liveActivitiesAvailable: Bool { liveActivities.isAvailable }

    /// Refreshes state from the store and reconciles the Live Activity and the
    /// overdue alert. Call on launch and whenever the app becomes active.
    /// Concurrent calls share a single in-flight reconciliation.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        do {
            guard let fetched = try store.activeSession() else {
                await reconcileNoActiveSession()
                return
            }
            if SessionEngine.isAbandoned(fetched.state, now: now()) {
                // If cancelling the abandoned session failed, the store still holds
                // it as active: stop here rather than running the no-active-session
                // reconciliation, which would end Live Activities and sweep this
                // still-legitimate session's overdue alert out from under it.
                guard await cancelAbandoned(fetched) else { return }
                // A new session may have started while `cancelAbandoned` awaited its
                // Live Activity teardown; don't clobber it with the "no session" path.
                guard activeSessionID == nil else { return }
                await reconcileNoActiveSession()
                return
            }
            let record = fetched
            publish(record)
            let sessionID = record.id
            if liveActivities.isAvailable {
                let age = now().timeIntervalSince(record.state.startedAt)
                if !liveActivities.hasActivity(for: sessionID), startingSessionID != sessionID {
                    // Never (re)start a Live Activity for a session this old; iOS has
                    // already ended it, and it will auto-cancel via `abandonAfter`.
                    if age < SessionRules.liveActivityMaxAge {
                        await startLiveActivity(sessionID: sessionID, startedAt: record.state.startedAt, initialCount: record.state.count)
                    }
                } else if liveActivities.hasActivity(for: sessionID) {
                    await liveActivities.update(sessionID: sessionID, count: record.state.count, completedAt: nil)
                }
            }
            // The session may have completed, been cancelled, or been superseded
            // by a new one while the Live Activity call above was in flight; don't
            // touch another session's overdue alert.
            guard activeSessionID == sessionID else { return }

            await notifications.cancelOverdueAlerts(except: sessionID)
            guard activeSessionID == sessionID else { return }

            // Never prompt from load(): only (re)schedule when already authorized.
            guard await notifications.isAuthorized() else { return }
            guard activeSessionID == sessionID else { return }
            do {
                try await notifications.scheduleOverdueAlert(
                    sessionID: sessionID, startedAt: record.state.startedAt, now: now(), text: overdueText
                )
                if activeSessionID != sessionID {
                    notifications.cancelOverdueAlert(sessionID: sessionID)
                }
            } catch {
                logger.error("Scheduling overdue alert during load failed: \(error.localizedDescription)")
            }
        } catch {
            logger.error("Loading active session failed: \(error.localizedDescription)")
            failure = .loadFailed
        }
    }

    /// Ends any stray Live Activities and orphaned overdue alerts when no
    /// session is active — the state load() and cancelling an abandoned
    /// session both converge on.
    private func reconcileNoActiveSession() async {
        await liveActivities.endAll()
        // A new session may have started (and scheduled its own overdue alert)
        // while `endAll` was in flight; don't wipe it out from under it.
        guard activeSessionID == nil else { return }
        await notifications.cancelOverdueAlerts(except: nil)
    }

    /// Cancels a session that's been active for `SessionRules.abandonAfter`
    /// without being finished or cancelled — e.g. the mother forgot about it —
    /// so it doesn't linger forever showing a stale Live Activity/overdue banner
    /// and doesn't swallow the next day's first kick.
    /// Returns `false` (and sets `failure = .saveFailed`) if the cancel itself
    /// failed, so callers can stop instead of treating the session as gone.
    @discardableResult
    private func cancelAbandoned(_ record: SessionRecord) async -> Bool {
        do {
            _ = try store.cancelActive(at: now())
        } catch {
            logger.error("Cancelling abandoned session failed: \(error.localizedDescription)")
            failure = .saveFailed
            return false
        }
        notifications.cancelOverdueAlert(sessionID: record.id)
        publish(nil)
        await liveActivities.end(sessionID: record.id, dismissAfter: 0)
        return true
    }

    /// Cancels the active session first if it's abandoned, so a kick that
    /// arrives after `SessionRules.abandonAfter` starts a fresh session
    /// instead of extending the forgotten one. Returns `false` if an abandoned
    /// session was found but failed to cancel, so the caller must not touch it.
    private func expireAbandonedSessionIfNeeded() async -> Bool {
        guard let record = try? store.activeSession(), SessionEngine.isAbandoned(record.state, now: now()) else { return true }
        return await cancelAbandoned(record)
    }

    @discardableResult
    public func recordKick() async -> KickOutcome {
        // If an abandoned session failed to cancel, it's still active in the
        // store: stop rather than adding this kick to the 13-hour-old session.
        guard await expireAbandonedSessionIfNeeded() else { return .ignoredInactive }
        let time = now()
        let result: KickResult
        do {
            result = try store.addKick(at: time)
        } catch {
            logger.error("Saving kick failed: \(error.localizedDescription)")
            failure = .saveFailed
            return .ignoredInactive
        }

        let record = result.record
        switch result.outcome {
        case .added(let count):
            publish(record)
            if result.didStartSession {
                await startSideEffects(for: record, at: time)
            } else {
                await liveActivities.update(sessionID: record.id, count: count, completedAt: nil)
            }
        case .completed:
            publish(nil)
            completedSession = record.state
            notifications.cancelOverdueAlert(sessionID: record.id)
            await liveActivities.update(sessionID: record.id, count: record.state.count, completedAt: record.state.endedAt)
            await liveActivities.end(sessionID: record.id, dismissAfter: Self.completedActivityLinger)
        case .ignoredDebounce, .ignoredInactive:
            break
        }
        return result.outcome
    }

    public func undo() async {
        do {
            guard let record = try store.undoLastKick() else { return }
            publish(record)
            await liveActivities.update(sessionID: record.id, count: record.state.count, completedAt: nil)
        } catch {
            logger.error("Undo failed: \(error.localizedDescription)")
            failure = .saveFailed
        }
    }

    public func cancelSession() async {
        do {
            guard let record = try store.cancelActive(at: now()) else { return }
            notifications.cancelOverdueAlert(sessionID: record.id)
            publish(nil)
            await liveActivities.end(sessionID: record.id, dismissAfter: 0)
        } catch {
            logger.error("Cancel failed: \(error.localizedDescription)")
            failure = .saveFailed
        }
    }

    public func dismissCompletion() {
        completedSession = nil
    }

    public func clearFailure() {
        failure = nil
    }

    public func isOverdue(at date: Date) -> Bool {
        activeSession.map { SessionEngine.isOverdue($0, now: date) } ?? false
    }

    /// Returns false if the reminder could not be scheduled (usually: permission denied).
    public func setDailyReminder(enabled: Bool, hour: Int, minute: Int, text: NotificationText) async -> Bool {
        guard enabled else {
            notifications.cancelDailyReminder()
            return true
        }
        guard await notifications.requestAuthorizationIfNeeded() else { return false }
        do {
            try await notifications.scheduleDailyReminder(hour: hour, minute: minute, text: text)
            return true
        } catch {
            logger.error("Scheduling daily reminder failed: \(error.localizedDescription)")
            return false
        }
    }

    /// The app language changed: the active session's 2-hour alert is scheduled
    /// again with the new text. Never prompts; does nothing without permission.
    public func updateOverdueText(_ text: NotificationText) async {
        overdueText = text
        guard let sessionID = activeSessionID, let startedAt = activeSession?.startedAt else { return }
        guard await notifications.isAuthorized(), activeSessionID == sessionID else { return }
        do {
            try await notifications.scheduleOverdueAlert(sessionID: sessionID, startedAt: startedAt, now: now(), text: text)
            if activeSessionID != sessionID {
                notifications.cancelOverdueAlert(sessionID: sessionID)
            }
        } catch {
            logger.error("Rescheduling the overdue alert failed: \(error.localizedDescription)")
        }
    }

    /// Partner mode (phase 8): this iPhone follows someone else's pregnancy, so
    /// the daily kick reminder, every 2-hour alert and every kick Live Activity
    /// stop. The stored session and the reminder setting are kept: leaving
    /// partner mode goes back through `load()` and `setDailyReminder`.
    public func silenceForPartnerMode() async {
        // A reconciliation in flight could restart what is about to end.
        if let loadTask { await loadTask.value }
        notifications.cancelDailyReminder()
        await liveActivities.endAll()
        await notifications.cancelOverdueAlerts(except: nil)
    }

    public func notificationsAuthorized() async -> Bool {
        await notifications.isAuthorized()
    }

    /// Onboarding's "Turn on reminders" (phase 9): asks only if never asked.
    @discardableResult
    public func requestNotificationPermission() async -> Bool {
        await notifications.requestAuthorizationIfNeeded()
    }

    private func publish(_ record: SessionRecord?) {
        activeSession = record?.state
        activeSessionID = record?.id
    }

    private func startSideEffects(for record: SessionRecord, at time: Date) async {
        let sessionID = record.id

        if liveActivities.isAvailable {
            await startLiveActivity(sessionID: sessionID, startedAt: record.state.startedAt, initialCount: record.state.count)
        }

        guard await notifications.requestAuthorizationIfNeeded() else { return }
        // The session may have completed or been cancelled while we waited on
        // (possibly user-facing) authorization; don't schedule a false alert.
        guard activeSessionID == sessionID else { return }
        do {
            try await notifications.scheduleOverdueAlert(
                sessionID: sessionID, startedAt: record.state.startedAt, now: time, text: overdueText
            )
            if activeSessionID != sessionID {
                notifications.cancelOverdueAlert(sessionID: sessionID)
            }
        } catch {
            logger.error("Scheduling overdue alert failed: \(error.localizedDescription)")
        }
    }

    /// Starts a Live Activity for `sessionID`, shared by `recordKick`'s first-kick
    /// path and by `load()`'s reconciliation. Tracks the in-flight request via
    /// `startingSessionID` so a concurrent `load()` doesn't race it into a second
    /// `start`; once the request resolves, corrects the activity to the current
    /// published count if it drifted while suspended, and — if the session is no
    /// longer active by then — tears the just-created activity down again instead
    /// of leaving it orphaned.
    private func startLiveActivity(sessionID: UUID, startedAt: Date, initialCount: Int) async {
        startingSessionID = sessionID
        await liveActivities.start(sessionID: sessionID, startedAt: startedAt, count: initialCount)
        if startingSessionID == sessionID { startingSessionID = nil }

        guard activeSessionID == sessionID else {
            await liveActivities.end(sessionID: sessionID, dismissAfter: 0)
            return
        }
        if let current = activeSession?.count, current != initialCount {
            await liveActivities.update(sessionID: sessionID, count: current, completedAt: nil)
        }
    }
}
