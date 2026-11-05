import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// 1.1 item 4 (spec §4.2, §4.6): the order the ending runs in, and stopping
/// the kick counter and the contraction timer.
@MainActor
struct PregnancyEndingPlanTests {
    @Test func archiveComesFirst() {
        for keep in [PregnancyEndingKeep.memory(title: "Bông"), .noMemoryDeleteData] {
            let steps = PregnancyEndingPlan.steps(keep: keep)
            #expect(steps.first == .archive, "\(keep)")
            #expect(steps.last == .switchToCycle, "\(keep)")
        }
    }

    @Test func noMemoryKeepDataSkipsArchive() {
        #expect(!PregnancyEndingPlan.steps(keep: .noMemoryKeepData).contains(.archive))
        #expect(PregnancyEndingKeep.noMemoryKeepData.memoryTitle == nil)
        #expect(!PregnancyEndingKeep.noMemoryKeepData.deletesRawData)
        #expect(PregnancyEndingKeep.noMemoryDeleteData.deletesRawData)
        #expect(PregnancyEndingKeep.memory(title: "x").deletesRawData)
        #expect(PregnancyEndingKeep.memory(title: "x").memoryTitle == "x")
    }

    @Test func everyPathEndsActivitiesForcedAndCancelsReminders() {
        for keep in [PregnancyEndingKeep.memory(title: ""), .noMemoryKeepData, .noMemoryDeleteData] {
            let steps = PregnancyEndingPlan.steps(keep: keep)
            for step in [PregnancyEndingStep.stopKickCounting, .stopContractions, .endLiveActivities(force: true), .cancelPregnancyReminders] {
                #expect(steps.contains(step), "\(keep) \(step)")
            }
            #expect(!steps.contains(.endLiveActivities(force: false)))
            // Everything stops before the mode changes.
            #expect(steps.firstIndex(of: .cancelPregnancyReminders)! < steps.firstIndex(of: .switchToCycle)!)
            #expect(steps.firstIndex(of: .endLiveActivities(force: true))! < steps.firstIndex(of: .switchToCycle)!)
        }
    }

    // MARK: - The kick counter

    private func kickCoordinator(_ repository: FakeSessionRepository, _ center: FakeNotificationCenter,
                                 _ live: FakeLiveActivities, _ clock: TestClock) -> KickCoordinator {
        KickCoordinator(
            store: repository, notifications: NotificationScheduler(center: center), liveActivities: live,
            overdueText: NotificationText(title: "Overdue", body: "Body"), now: { clock.now }
        )
    }

    @Test func forceEndAllEndsTheDoneActivity() async {
        let repository = FakeSessionRepository()
        let center = FakeNotificationCenter()
        let live = FakeLiveActivities()
        let clock = TestClock(date("2026-09-01T20:00:00Z"))
        let coordinator = kickCoordinator(repository, center, live, clock)
        for _ in 0..<10 {
            await coordinator.recordKick()
            clock.advance(60)
        }
        #expect(coordinator.completedSession != nil)
        #expect(live.lingeringIDs.count == 1, "the Done! card lingers on the Lock Screen")

        // A plain endAll leaves it (it carries its own dismissal)…
        await live.endAll()
        #expect(live.lingeringIDs.count == 1)
        // …ending the pregnancy does not.
        await coordinator.stopForPregnancyEnd()
        #expect(live.lingeringIDs.isEmpty)
        #expect(live.activeIDs.isEmpty)
        #expect(live.forcedEndAllCount == 1)
        #expect(coordinator.completedSession == nil)
    }

    @Test func stopForPregnancyEndCancelsTheSessionAndItsReminders() async throws {
        let repository = FakeSessionRepository()
        let center = FakeNotificationCenter()
        let live = FakeLiveActivities()
        let clock = TestClock(date("2026-09-01T20:00:00Z"))
        let coordinator = kickCoordinator(repository, center, live, clock)
        #expect(await coordinator.setDailyReminder(enabled: true, hour: 20, minute: 0, text: NotificationText(title: "t", body: "b")))
        await coordinator.recordKick()
        let sessionID = try #require(coordinator.activeSessionID)
        #expect(Set(center.added.map(\.identifier)) == [NotificationScheduler.dailyReminderID, NotificationScheduler.overdueID(for: sessionID)])

        await coordinator.stopForPregnancyEnd()

        #expect(coordinator.activeSession == nil)
        #expect(try repository.activeSession() == nil)
        #expect(repository.sessions[sessionID]?.status == .cancelled)
        #expect(center.added.isEmpty)
        #expect(live.activeIDs.isEmpty)
    }

    // MARK: - The contraction timer

    @Test func stopContractionsClosesTheRunningOneAndRemovesTheAlert() async throws {
        let store = FakeContractionRepository()
        let live = FakeContractionLiveActivities()
        let center = FakeNotificationCenter()
        let defaults = makeTestDefaults()
        let clock = TestClock(date("2026-09-01T20:00:00Z"))
        let coordinator = ContractionCoordinator(
            store: store, liveActivities: live, notifications: NotificationScheduler(center: center),
            defaults: defaults, now: { clock.now }
        )
        await coordinator.load()
        _ = await coordinator.toggle()
        clock.advance(50)
        #expect(coordinator.running != nil)
        defaults.set("run-1:fiveOneOne", forKey: SettingsKey.contractionAlertNotified)

        await coordinator.stopForPregnancyEnd()

        #expect(coordinator.running == nil)
        #expect(try store.contractions().allSatisfy { !$0.isRunning })
        #expect(live.endAllCount >= 1)
        #expect(coordinator.stats(week: nil).currentEpisode == nil)
        #expect(center.removedDelivered.contains(NotificationScheduler.contractionAlertID("run-1")))
        #expect(center.removed.contains(NotificationScheduler.contractionAlertID("run-1")))
        #expect(defaults.object(forKey: SettingsKey.contractionAlertNotified) == nil)
    }
}
