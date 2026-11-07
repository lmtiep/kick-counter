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

    @Test func recordKickStartsSessionAndLiveActivity() async {
        let result = await siri.run(.recordKick)
        #expect(result == .kickRecorded)
        #expect(kicks.activeSession?.count == 1)
        #expect(kickLive.started.count == 1)
    }

    @Test func recordKickAddsToTheRunningSession() async {
        await siri.run(.recordKick)
        clock.advance(60)
        #expect(await siri.run(.recordKick) == .kickRecorded)
        #expect(kicks.activeSession?.count == 2)
        #expect(kickLive.updates.last?.count == 2)
        #expect(kickLive.started.count == 1)
    }

    @Test func recordKickReportsAFailedSave() async {
        kickStore.failNextWrite = true
        let result = await siri.run(.recordKick)
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

    @Test func stopContractionsAfterTheEpisodeGapChangesNothing() async {
        await siri.run(.timeContraction)
        clock.advance(60)
        await siri.run(.timeContraction)
        clock.advance(3 * 60 * 60)
        #expect(await siri.run(.stopContractions) == .nothingToEnd)
        #expect(contractions.episodeEndedAt == nil)
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
        #expect(await siri.run(.recordKick) == .needsPregnancyMode)
        #expect(kicks.activeSession == nil)
    }

    /// Review fix 3: after a pregnancy ended Siri answers neutrally and starts nothing.
    @Test func afterAnEndingSiriIsNeutral() async {
        AppMode.save(.tryingToConceive, to: defaults)
        PregnancyEndState(branch: .loss, endDate: date("2026-09-01T00:00:00Z")).save(to: defaults)
        for command in SiriCommand.allCases {
            #expect(await siri.run(command) == .trackingCycle)
        }
        #expect(kicks.activeSession == nil)
        #expect(contractions.contractions.isEmpty)
    }
}
