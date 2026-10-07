import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct KickCoordinatorTests {
    let t0 = date("2026-09-01T20:00:00Z")
    let overdueText = NotificationText(title: "Overdue", body: "Call your doctor")
    let repository: FakeSessionRepository
    let center: FakeNotificationCenter
    let live: FakeLiveActivities
    let clock: TestClock
    let coordinator: KickCoordinator

    init() {
        let repository = FakeSessionRepository()
        let center = FakeNotificationCenter()
        let live = FakeLiveActivities()
        let clock = TestClock(date("2026-09-01T20:00:00Z"))
        self.repository = repository
        self.center = center
        self.live = live
        self.clock = clock
        coordinator = Self.makeCoordinator(repository, center, live, clock)
    }

    private static func makeCoordinator(
        _ repository: FakeSessionRepository,
        _ center: FakeNotificationCenter,
        _ live: FakeLiveActivities,
        _ clock: TestClock
    ) -> KickCoordinator {
        KickCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            liveActivities: live,
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { clock.now }
        )
    }

    private func kick(times: Int) async {
        for _ in 0..<times {
            await coordinator.recordKick()
            clock.advance(60)
        }
    }

    @Test func firstKickStartsSessionLiveActivityAndOverdueAlert() async throws {
        let outcome = await coordinator.recordKick()
        #expect(outcome == .added(count: 1))
        let id = try #require(coordinator.activeSessionID)
        #expect(coordinator.activeSession?.count == 1)
        #expect(live.started.count == 1)
        #expect(live.started[0].id == id)
        #expect(center.added.map(\.identifier) == [NotificationScheduler.overdueID(for: id)])
    }

    @Test func liveActivityIsSkippedWhenUnavailable() async {
        live.isAvailable = false
        await coordinator.recordKick()
        #expect(live.started.isEmpty)
        #expect(coordinator.activeSession?.count == 1)
    }

    @Test func overdueAlertIsSkippedWhenNotificationsDenied() async {
        center.status = .denied
        await coordinator.recordKick()
        #expect(center.added.isEmpty)
        #expect(coordinator.activeSession?.count == 1)
    }

    @Test func laterKicksUpdateLiveActivity() async {
        await kick(times: 3)
        #expect(live.updates.map(\.count) == [2, 3])
        #expect(live.updates.allSatisfy { $0.completedAt == nil })
    }

    @Test func tenthKickCompletesAndCleansUp() async throws {
        await kick(times: 9)
        let id = try #require(coordinator.activeSessionID)
        let outcome = await coordinator.recordKick()

        #expect(outcome == .completed(duration: 9 * 60))
        #expect(coordinator.activeSession == nil)
        #expect(coordinator.activeSessionID == nil)
        #expect(coordinator.completedSession?.count == 10)
        #expect(center.removed.contains(NotificationScheduler.overdueID(for: id)))
        #expect(live.updates.last?.sessionID == id)
        #expect(live.updates.last?.count == 10)
        #expect(live.updates.last?.completedAt == t0.addingTimeInterval(9 * 60))
        #expect(live.ended.map(\.sessionID) == [id])
        #expect(live.ended.map(\.dismissAfter) == [KickCoordinator.completedActivityLinger])
    }

    @Test func debouncedTapChangesNothing() async {
        await coordinator.recordKick()
        clock.advance(0.2)
        #expect(await coordinator.recordKick() == .ignoredDebounce)
        #expect(coordinator.activeSession?.count == 1)
        #expect(live.updates.isEmpty)
    }

    @Test func saveFailureIsReported() async {
        repository.failNextWrite = true
        #expect(await coordinator.recordKick() == .ignoredInactive)
        #expect(coordinator.failure == .saveFailed)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func undoUpdatesStateAndLiveActivity() async {
        await kick(times: 3)
        await coordinator.undo()
        #expect(coordinator.activeSession?.count == 2)
        #expect(live.updates.last?.count == 2)
    }

    @Test func cancelEndsEverything() async throws {
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        await coordinator.cancelSession()
        #expect(coordinator.activeSession == nil)
        #expect(center.removed.contains(NotificationScheduler.overdueID(for: id)))
        #expect(live.ended.map(\.sessionID) == [id])
        #expect(live.ended.map(\.dismissAfter) == [0])
    }

    @Test func loadRestoresActiveSessionAndRestartsMissingLiveActivity() async {
        await kick(times: 2)
        live.activeIDs.removeAll()   // e.g. user dismissed it, or the app was killed

        let restored = Self.makeCoordinator(repository, center, live, clock)
        await restored.load()
        #expect(restored.activeSession?.count == 2)
        #expect(live.started.count == 2)
        #expect(live.started.last?.count == 2)
    }

    @Test func loadWithoutSessionEndsStrayActivities() async {
        await coordinator.load()
        #expect(live.endAllCount == 1)
    }

    /// Phase 8: a partner iPhone gets no kick reminders, 2-hour alerts or Live
    /// Activities; the session and the reminder setting are kept for leaving.
    @Test func partnerModeSilencesKickRemindersAndLiveActivities() async throws {
        #expect(await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: overdueText))
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        #expect(Set(center.added.map(\.identifier)) == [NotificationScheduler.dailyReminderID, NotificationScheduler.overdueID(for: id)])

        await coordinator.silenceForPartnerMode()
        #expect(center.added.isEmpty)
        #expect(center.removed.contains(NotificationScheduler.dailyReminderID))
        #expect(center.removed.contains(NotificationScheduler.overdueID(for: id)))
        #expect(live.endAllCount == 1)
        #expect(coordinator.activeSessionID == id)
    }

    @Test func overdueReflectsElapsedTime() async {
        await coordinator.recordKick()
        #expect(coordinator.isOverdue(at: t0.addingTimeInterval(7199)) == false)
        #expect(coordinator.isOverdue(at: t0.addingTimeInterval(7200)))
    }

    @Test func dailyReminderRequiresAuthorization() async {
        center.status = .notDetermined
        center.grantOnRequest = false
        let ok = await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: overdueText)
        #expect(ok == false)
        #expect(center.added.isEmpty)
    }

    @Test func dailyReminderSchedulesAndCancels() async {
        #expect(await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: overdueText))
        #expect(center.added.map(\.identifier) == [NotificationScheduler.dailyReminderID])
        #expect(await coordinator.setDailyReminder(enabled: false, hour: 20, minute: 0, text: overdueText))
        #expect(center.added.isEmpty)
    }

    // MARK: - Fix round 1: re-entrancy safety

    /// Finding 1(a): a non-session-scoped `end` resuming after a new session
    /// started would tear down the new session's activity. With session-scoped
    /// calls, session A's completion, however delayed, must never touch B.
    @Test func completingSessionDoesNotAffectNewlyStartedSession() async throws {
        await kick(times: 9)
        let idA = try #require(coordinator.activeSessionID)

        live.holdUpdate = true
        async let completion: KickOutcome = coordinator.recordKick() // 10th kick: completes A, suspends in `update`
        defer { live.releaseUpdate() }
        try await waitUntil(live.updatePending)

        clock.advance(60)
        let secondOutcome = await coordinator.recordKick() // starts session B
        let idB = try #require(coordinator.activeSessionID)
        #expect(idB != idA)
        #expect(secondOutcome == .added(count: 1))
        #expect(live.hasActivity(for: idB))

        live.releaseUpdate()
        let outcome = await completion
        #expect(outcome == .completed(duration: 9 * 60))

        #expect(live.hasActivity(for: idB))
        #expect(!live.ended.contains { $0.sessionID == idB })
        #expect(!live.updates.contains { $0.sessionID == idB && $0.completedAt != nil })
    }

    /// Finding 1(b): a kick landing while `start` is in flight used to be
    /// dropped (no activity yet) and never recovered. The re-check after
    /// `start` resumes must push the real count.
    @Test func kickWhileStartIsHeldUpdatesLiveActivityAfterRelease() async throws {
        live.holdStart = true
        async let first: KickOutcome = coordinator.recordKick() // kick 1, suspends in `start`
        defer { live.releaseStart() }
        try await waitUntil(live.startPending)

        clock.advance(1)
        let second = await coordinator.recordKick() // kick 2, arrives while start is in flight
        #expect(second == .added(count: 2))

        live.releaseStart()
        let firstOutcome = await first
        #expect(firstOutcome == .added(count: 1))

        let id = try #require(coordinator.activeSessionID)
        #expect(live.updates.last?.sessionID == id)
        #expect(live.updates.last?.count == 2)
    }

    /// Finding 2: a session that completes while authorization is pending must
    /// not schedule a false overdue alert once authorization finally resolves.
    @Test func sessionCompletingWhileAuthorizationIsHeldSchedulesNoAlert() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let first: KickOutcome = coordinator.recordKick() // kick 1, suspends requesting authorization
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)
        let idA = try #require(coordinator.activeSessionID)

        for _ in 0..<9 {
            clock.advance(60)
            await coordinator.recordKick() // kicks 2...10, the 10th completes the session
        }
        #expect(coordinator.activeSession == nil)

        center.releaseRequestAuthorization()
        _ = await first

        #expect(!center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: idA) })
    }

    /// Finding 2: same as above, but the session is cancelled instead of completed.
    @Test func sessionCancelledWhileAuthorizationIsHeldSchedulesNoAlert() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let first: KickOutcome = coordinator.recordKick() // kick 1, suspends requesting authorization
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)
        let idA = try #require(coordinator.activeSessionID)

        await coordinator.cancelSession()
        #expect(coordinator.activeSession == nil)

        center.releaseRequestAuthorization()
        _ = await first

        #expect(!center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: idA) })
    }

    /// Finding 3: `load()` must not start a second activity when one already
    /// exists; it should instead push the current count.
    @Test func loadWithExistingActivityUpdatesInsteadOfRestarting() async throws {
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        let startedCountBefore = live.started.count
        let updatesCountBefore = live.updates.count

        await coordinator.load()

        #expect(live.started.count == startedCountBefore)
        #expect(live.updates.count == updatesCountBefore + 1)
        #expect(live.updates.last?.sessionID == id)
        #expect(live.updates.last?.count == 2)
    }

    /// Finding 3: `load()` must reconcile the overdue alert — (re)scheduling it
    /// for the active session and removing any orphaned `overdue-*` requests.
    @Test func loadSchedulesOverdueAlertAndRemovesOrphans() async throws {
        await kick(times: 1)
        let id = try #require(coordinator.activeSessionID)
        center.added.removeAll() // simulate the alert never having been (re)delivered
        let strayID = NotificationScheduler.overdueID(for: UUID())
        center.added.append(UNNotificationRequest(identifier: strayID, content: UNMutableNotificationContent(), trigger: nil))

        await coordinator.load()

        let addedIDs = Set(center.added.map(\.identifier))
        #expect(addedIDs.contains(NotificationScheduler.overdueID(for: id)))
        #expect(!addedIDs.contains(strayID))
    }

    /// Finding 3: two concurrent `load()` calls must not race each other into
    /// starting two activities for the same missing session.
    @Test func concurrentLoadsStartExactlyOneActivity() async throws {
        await kick(times: 2)
        let id = try #require(coordinator.activeSessionID)
        live.activeIDs.removeAll()
        live.started.removeAll()
        live.holdStart = true

        async let loadA: Void = coordinator.load()
        defer { live.releaseStart() }
        try await waitUntil(live.startPending)
        async let loadB: Void = coordinator.load()

        live.releaseStart()
        _ = await loadA
        _ = await loadB

        #expect(live.started.count == 1)
        #expect(live.started.first?.id == id)
    }

    /// Finding 3: `load()` must never prompt the user for notification
    /// authorization — only (re)schedule when already authorized.
    @Test func loadNeverPromptsForAuthorization() async throws {
        center.status = .notDetermined
        _ = try repository.addKick(at: t0) // seed an active session directly, bypassing the coordinator
        #expect(center.requestCount == 0)

        await coordinator.load()

        #expect(center.requestCount == 0)
    }

    // MARK: - Fix round 2: performLoad() re-entrancy safety

    /// Finding 3 (round 2): `load()` starting a missing activity must re-check
    /// the session afterward like `startSideEffects` does. If the session is
    /// cancelled while that `start` is in flight, the just-created activity
    /// must be torn down again instead of left orphaned, and no overdue alert
    /// should be scheduled.
    @Test func loadCancelledWhileStartIsHeldLeavesNoActivityOrAlert() async throws {
        let seeded = try repository.addKick(at: t0) // active session, no Live Activity yet
        let id = seeded.record.id

        live.holdStart = true

        async let loadTask: Void = coordinator.load()
        defer { live.releaseStart() }
        try await waitUntil(live.startPending)

        await coordinator.cancelSession()

        live.releaseStart()
        await loadTask

        #expect(coordinator.activeSession == nil)
        #expect(live.activeIDs.isEmpty)
        #expect(!center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: id) })
    }

    /// Finding 3 (round 2): a session that completes while `load()` is
    /// suspended reconciling its overdue alert (after `cancelOverdueAlerts`,
    /// waiting on `isAuthorized()`) must not have a false alert scheduled for
    /// it once `load()` resumes.
    @Test func loadSchedulesNoAlertWhenSessionCompletesWhileSuspended() async throws {
        await kick(times: 9)
        let id = try #require(coordinator.activeSessionID)

        center.holdAuthorizationStatus = true

        async let loadTask: Void = coordinator.load()
        defer { center.releaseAuthorizationStatus() }
        try await waitUntil(center.authorizationStatusPending)

        clock.advance(60)
        await coordinator.recordKick() // 10th kick completes the session
        #expect(coordinator.activeSession == nil)

        center.releaseAuthorizationStatus()
        await loadTask

        #expect(!center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: id) })
    }

    /// Finding 3 (round 2): a new session starting while a no-session `load()`
    /// is suspended inside `endAll()` must keep its own overdue alert — `load()`
    /// must not blindly `cancelOverdueAlerts(except: nil)` once it resumes.
    @Test func loadWithNoSessionSuspendedInEndAllDoesNotDeleteNewSessionsAlert() async throws {
        live.holdEndAll = true

        async let loadTask: Void = coordinator.load() // no active session: endAll(), held
        defer { live.releaseEndAll() }
        try await waitUntil(live.endAllPending)

        await coordinator.recordKick() // starts session Y, schedules its overdue alert
        let idY = try #require(coordinator.activeSessionID)

        live.releaseEndAll()
        await loadTask

        #expect(center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: idY) })
    }

    /// Finding 3 (round 2): `load()`'s own `start` (for an active session found
    /// in the store with no Live Activity yet) must get the same post-start
    /// count correction as `startSideEffects`. Without it, a kick landing while
    /// that `start` is in flight is silently dropped (no activity yet) and the
    /// Live Activity is left showing a stale count.
    @Test func loadStartedActivityGetsCountCorrectionAfterDroppedKick() async throws {
        _ = try repository.addKick(at: t0)
        clock.advance(60)
        let seeded = try repository.addKick(at: clock.now) // active session, count 2, no Live Activity yet
        let id = seeded.record.id
        #expect(seeded.record.state.count == 2)

        live.holdStart = true

        async let loadTask: Void = coordinator.load()
        defer { live.releaseStart() }
        try await waitUntil(live.startPending)

        clock.advance(60)
        let outcome = await coordinator.recordKick() // 3rd kick: its own `update` is dropped, no activity yet
        #expect(outcome == .added(count: 3))
        #expect(live.droppedUpdates.contains { $0.sessionID == id && $0.count == 3 })

        live.releaseStart()
        await loadTask

        #expect(live.started.count == 1)
        #expect(live.updates.last?.sessionID == id)
        #expect(live.updates.last?.count == 3)
    }

    // MARK: - Fix round 3: test hygiene (no hangs)

    // MARK: - Abandoned sessions auto-expire

    /// Item 1a: a 13h-old active session is auto-cancelled by `load()`; no Live
    /// Activity is (re)started and its overdue alert is removed.
    @Test func loadCancelsAbandonedSession() async throws {
        let seeded = try repository.addKick(at: t0) // active session, no Live Activity yet
        let id = seeded.record.id
        center.added.append(UNNotificationRequest(
            identifier: NotificationScheduler.overdueID(for: id), content: UNMutableNotificationContent(), trigger: nil
        ))
        clock.advance(13 * 60 * 60)

        await coordinator.load()

        #expect(coordinator.activeSession == nil)
        #expect(coordinator.activeSessionID == nil)
        #expect(try repository.activeSession() == nil)
        #expect(live.started.isEmpty)
        #expect(!center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: id) })
    }

    /// Item 3a: `load()` on a 13h-old active session whose cancel fails must
    /// stop before running no-active-session reconciliation — it must not end
    /// Live Activities or sweep the (still-legitimate) overdue alert, and the
    /// repository must still hold the active session.
    @Test func loadStopsAfterFailedAbandonedCancel() async throws {
        let seeded = try repository.addKick(at: t0)
        let id = seeded.record.id
        center.added.append(UNNotificationRequest(
            identifier: NotificationScheduler.overdueID(for: id), content: UNMutableNotificationContent(), trigger: nil
        ))
        clock.advance(13 * 60 * 60)
        repository.failNextCancel = true

        await coordinator.load()

        #expect(coordinator.failure == .saveFailed)
        #expect(live.endAllCount == 0)
        #expect(center.added.contains { $0.identifier == NotificationScheduler.overdueID(for: id) })
        #expect(try repository.activeSession()?.id == id)
    }

    /// Item 3b: `recordKick()` on a 13h-old active session whose cancel fails
    /// must not add the kick to the stale session or start a new one.
    @Test func recordKickStopsAfterFailedAbandonedCancel() async throws {
        let seeded = try repository.addKick(at: t0)
        let id = seeded.record.id
        clock.advance(13 * 60 * 60)
        repository.failNextCancel = true

        let outcome = await coordinator.recordKick()

        #expect(outcome == .ignoredInactive)
        #expect(coordinator.failure == .saveFailed)
        #expect(try repository.activeSession()?.id == id)
        #expect(try repository.activeSession()?.state.count == 1)
    }

    /// Item 1b: `recordKick()` on a 13h-old active session cancels it and starts
    /// a brand-new session with normal side effects, scoped only to the new id.
    @Test func recordKickCancelsAbandonedSessionAndStartsNewOne() async throws {
        let seeded = try repository.addKick(at: t0) // old session
        let oldID = seeded.record.id
        clock.advance(13 * 60 * 60)

        let outcome = await coordinator.recordKick()

        #expect(outcome == .added(count: 1))
        let newID = try #require(coordinator.activeSessionID)
        #expect(newID != oldID)
        #expect(coordinator.activeSession?.count == 1)
        #expect(try repository.activeSession()?.id == newID)
        #expect(live.started.map(\.id) == [newID])
        #expect(center.added.map(\.identifier) == [NotificationScheduler.overdueID(for: newID)])
    }

    /// Item 1c: a 9h-old active session with no Live Activity (iOS already
    /// ended it at 8h) must not get a new one started by `load()`.
    @Test func loadDoesNotRestartLiveActivityPastMaxAge() async throws {
        let seeded = try repository.addKick(at: t0)
        let id = seeded.record.id
        clock.advance(9 * 60 * 60)

        await coordinator.load()

        #expect(live.started.isEmpty)
        #expect(coordinator.activeSessionID == id)
        #expect(coordinator.activeSession?.status == .active)
    }

    /// Item 1d (regression guard): a 3h-old active session with no Live
    /// Activity still gets one started by `load()`.
    @Test func loadStillRestartsLiveActivityWellBeforeMaxAge() async throws {
        let seeded = try repository.addKick(at: t0)
        let id = seeded.record.id
        clock.advance(3 * 60 * 60)

        await coordinator.load()

        #expect(live.started.map(\.id) == [id])
    }

    /// Literal regression test for the `startingSessionID` gate in
    /// `performLoad`: a `load()` call must not start a second activity while
    /// the first kick's own `start` is still in flight. This already passes on
    /// the prior HEAD (fix round 1 already shared `startingSessionID` between
    /// `startSideEffects` and `performLoad`); it's added as explicit coverage
    /// per the round-3 review, not because it currently fails.
    @Test func loadDoesNotStartSecondActivityWhileFirstKickStartIsInFlight() async throws {
        live.holdStart = true

        async let firstKick: KickOutcome = coordinator.recordKick() // starts session, suspends in `start`
        defer { live.releaseStart() }
        try await waitUntil(live.startPending)

        await coordinator.load()

        live.releaseStart()
        let outcome = await firstKick
        #expect(outcome == .added(count: 1))

        #expect(live.started.count == 1)
    }
}
