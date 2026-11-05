import Testing
@testable import KickCore

struct SiriPlannerTests {
    private func state(
        mode: AppMode = .pregnant,
        onboarded: Bool = true,
        kickSession: Bool = false,
        running: Bool = false,
        episode: Bool = false
    ) -> SiriState {
        SiriState(mode: mode, onboarded: onboarded, kickSessionActive: kickSession,
                  contractionRunning: running, contractionEpisodeActive: episode)
    }

    @Test(arguments: SiriCommand.allCases, [AppMode.tryingToConceive, .partner])
    func onlyPregnancyModeActs(command: SiriCommand, mode: AppMode) {
        #expect(SiriPlanner.plan(command, state(mode: mode, kickSession: true, running: true, episode: true)) == .needsPregnancyMode)
    }

    @Test(arguments: SiriCommand.allCases)
    func notOnboardedNeverActs(command: SiriCommand) {
        #expect(SiriPlanner.plan(command, state(onboarded: false)) == .needsPregnancyMode)
    }

    @Test func startKicksStartsWhenNoSession() {
        #expect(SiriPlanner.plan(.startKicks, state()) == .recordKick)
    }

    @Test func startKicksDoesNotAddWhileRunning() {
        #expect(SiriPlanner.plan(.startKicks, state(kickSession: true)) == .kickAlreadyRunning)
    }

    @Test(arguments: [false, true])
    func timeContractionAlwaysToggles(running: Bool) {
        #expect(SiriPlanner.plan(.timeContraction, state(running: running, episode: running)) == .toggleContraction)
    }

    @Test(arguments: [(true, true), (false, true)])
    func stopEndsRunningOrActiveEpisode(running: Bool, episode: Bool) {
        #expect(SiriPlanner.plan(.stopContractions, state(running: running, episode: episode)) == .endContractionTracking)
    }

    @Test func stopWithNothingToEnd() {
        #expect(SiriPlanner.plan(.stopContractions, state()) == .nothingToEnd)
    }
}
