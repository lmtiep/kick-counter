import Foundation
import Testing
@testable import KickCore

struct UITestLaunchOptionsTests {
    @Test func parsesFixedNowAndSeedDueDateWhenUITesting() {
        let options = UITestLaunchOptions(arguments: [
            "KickCounter", "-uiTesting", "-fixedNow", "2026-10-02T12:00:00Z", "-seedDueDate", "2027-01-19T12:00:00Z",
        ])
        #expect(options.isUITesting)
        #expect(options.fixedNow == date("2026-10-02T12:00:00Z"))
        #expect(options.seedDueDate == date("2027-01-19T12:00:00Z"))
    }

    @Test func ignoresDatesWithoutUITesting() {
        let options = UITestLaunchOptions(arguments: ["KickCounter", "-fixedNow", "2026-10-02T12:00:00Z"])
        #expect(options == UITestLaunchOptions(arguments: []))
        #expect(options.isUITesting == false)
        #expect(options.fixedNow == nil)
    }

    @Test func invalidOrMissingValuesAreNil() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-fixedNow", "tomorrow"]).fixedNow == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedDueDate"]).seedDueDate == nil)
    }
}

struct UITestCycleSeedOptionTests {
    @Test func parsesTheCycleScenarioWhenUITesting() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycles", "fertile"])
        #expect(options.seedCycles == .fertile)
    }

    @Test func ignoresTheCycleScenarioWithoutUITestingOrWhenUnknown() {
        #expect(UITestLaunchOptions(arguments: ["-seedCycles", "fertile"]).seedCycles == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycles", "twins"]).seedCycles == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycles"]).seedCycles == nil)
    }
}

struct UITestOverdueSessionOptionTests {
    @Test func seedOverdueSessionNeedsUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedOverdueSession"]).seedOverdueSession)
        #expect(UITestLaunchOptions(arguments: ["-seedOverdueSession"]).seedOverdueSession == false)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting"]).seedOverdueSession == false)
    }
}
