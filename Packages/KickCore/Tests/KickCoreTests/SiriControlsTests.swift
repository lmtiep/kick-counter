import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// The three Siri / Control commands run on the real coordinators (fakes underneath).
@MainActor
struct SiriControlsTests {
    let kickStore = FakeSessionRepository()
    let kickLive = FakeLiveActivities()
    let contractionStore = FakeContractionRepository()
    let contractionLive = FakeContractionLiveActivities()
    let defaults = makeTestDefaults()
    let clock = TestClock(date("2026-11-06T20:00:00Z"))
    let kicks: KickCoordinator
    let contractions: ContractionCoordinator
    let siri: SiriControls

    init() {
        let clock = clock
        let kicks = KickCoordinator(
            store: kickStore,
            notifications: NotificationScheduler(center: FakeNotificationCenter()),
            liveActivities: kickLive,
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor"),
            now: { clock.now }
        )
        let contractions = ContractionCoordinator(
            store: contractionStore, liveActivities: contractionLive, defaults: defaults, now: { clock.now }
        )
        self.kicks = kicks
        self.contractions = contractions
        siri = SiriControls(kicks: kicks, contractions: contractions, defaults: defaults)
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        AppMode.save(.pregnant, to: defaults)
    }

    @Test func startKicksStartsSessionAndLiveActivity() async {
        let result = await siri.run(.startKicks)
        #expect(result == .kicksStarted)
        #expect(kicks.activeSession?.count == 1)
        #expect(kickLive.started.count == 1)
    }

    @Test func startKicksTwiceKeepsOneKick() async {
        await siri.run(.startKicks)
        clock.advance(60)
        let second = await siri.run(.startKicks)
        #expect(second == .kicksAlreadyRunning)
        #expect(kicks.activeSession?.count == 1)
        #expect(kickLive.updates.allSatisfy { $0.count == 1 })
    }

    @Test func startKicksReportsAFailedSave() async {
        kickStore.failNextWrite = true
        let result = await siri.run(.startKicks)
        #expect(result == .failed)
        #expect(kicks.activeSession == nil)
    }

    @Test func timeContractionStartsThenStops() async {
        #expect(await siri.run(.timeContraction) == .contractionStarted)
        #expect(contractions.running != nil)
        clock.advance(60)
        #expect(await siri.run(.timeContraction) == .contractionStopped)
        #expect(contractions.running == nil)
        #expect(contractions.contractions.count == 1)
    }

    @Test func shortContractionIsDiscarded() async {
        await siri.run(.timeContraction)
        clock.advance(1)
        #expect(await siri.run(.timeContraction) == .contractionDiscarded)
        #expect(contractions.contractions.isEmpty)
    }

    @Test func stopContractionsEndsEpisodeAndKeepsContractions() async {
        await siri.run(.timeContraction)
        clock.advance(60)
        #expect(await siri.run(.stopContractions) == .trackingEnded)
        #expect(contractions.running == nil)
        #expect(contractions.episodeEndedAt != nil)
        #expect(contractions.contractions.count == 1)
    }

    @Test func stopContractionsWhenIdleChangesNothing() async {
        #expect(await siri.run(.stopContractions) == .nothingToEnd)
        #expect(contractions.episodeEndedAt == nil)
        // After an ended episode there is nothing to end either.
        await siri.run(.timeContraction)
        clock.advance(60)
        await siri.run(.stopContractions)
        let ended = contractions.episodeEndedAt
        clock.advance(60)
        #expect(await siri.run(.stopContractions) == .nothingToEnd)
        #expect(contractions.episodeEndedAt == ended)
    }

    @Test(arguments: [AppMode.tryingToConceive, .partner])
    func notPregnantChangesNothing(mode: AppMode) async {
        AppMode.save(mode, to: defaults)
        for command in SiriCommand.allCases {
            #expect(await siri.run(command) == .needsPregnancyMode)
        }
        #expect(kicks.activeSession == nil)
        #expect(contractions.contractions.isEmpty)
        #expect(kickLive.started.isEmpty)
    }

    @Test func notOnboardedChangesNothing() async {
        defaults.set(false, forKey: SettingsKey.hasCompletedOnboarding)
        #expect(await siri.run(.startKicks) == .needsPregnancyMode)
        #expect(kicks.activeSession == nil)
    }
}
