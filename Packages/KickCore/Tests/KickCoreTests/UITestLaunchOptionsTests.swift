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

struct UITestSessionSeedOptionTests {
    @Test func seedSessionsNeedsUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedSessions"]).seedSessions)
        #expect(UITestLaunchOptions(arguments: ["-seedSessions"]).seedSessions == false)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting"]).seedSessions == false)
    }
}

struct UITestPartnerOptionTests {
    @Test func parsesTheSharingAndPartnerStatesWhenUITesting() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingSharing", "joined", "-uiTestingPartner", "stopped"])
        #expect(options.sharing == .joined)
        #expect(options.partner == .stopped)
    }

    @Test func ignoresThemWithoutUITestingOrWhenUnknown() {
        #expect(UITestLaunchOptions(arguments: ["-uiTestingSharing", "joined"]).sharing == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTestingPartner", "snapshot"]).partner == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingSharing", "shared"]).sharing == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingPartner"]).partner == nil)
    }
}
