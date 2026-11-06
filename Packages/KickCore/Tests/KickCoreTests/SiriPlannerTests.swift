import Testing
@testable import KickCore

struct SiriPlannerTests {
    private func state(
        mode: AppMode = .pregnant,
        onboarded: Bool = true,
        running: Bool = false,
        episode: Bool = false,
        ended: Bool = false
    ) -> SiriState {
        SiriState(mode: mode, onboarded: onboarded,
                  contractionRunning: running, contractionEpisodeActive: episode, pregnancyEnded: ended)
    }

    @Test(arguments: SiriCommand.allCases, [AppMode.tryingToConceive, .partner])
    func onlyPregnancyModeActs(command: SiriCommand, mode: AppMode) {
        #expect(SiriPlanner.plan(command, state(mode: mode, running: true, episode: true)) == .needsPregnancyMode)
    }

    @Test(arguments: SiriCommand.allCases)
    func notOnboardedNeverActs(command: SiriCommand) {
        #expect(SiriPlanner.plan(command, state(onboarded: false)) == .needsPregnancyMode)
    }

    @Test func recordKickAlwaysRecordsOne() {
        #expect(SiriPlanner.plan(.recordKick, state()) == .recordKick)
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

    /// Review fix 3: after a pregnancy ended, a neutral answer that never mentions pregnancy mode.
    @Test(arguments: SiriCommand.allCases)
    func afterAnEndingTheAnswerIsNeutral(command: SiriCommand) {
        #expect(SiriPlanner.plan(command, state(mode: .tryingToConceive, running: true, episode: true, ended: true)) == .trackingCycle)
        #expect(SiriPlanner.plan(command, state(mode: .tryingToConceive, onboarded: false, ended: true)) == .trackingCycle)
    }

    @Test func pregnantAgainActsAsUsual() {
        // The ended state is cleared when she is pregnant again; even if not, pregnancy mode acts.
        #expect(SiriPlanner.plan(.recordKick, state(ended: true)) == .recordKick)
    }
}
