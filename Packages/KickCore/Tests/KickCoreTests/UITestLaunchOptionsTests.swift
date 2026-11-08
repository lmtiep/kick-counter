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

    @Test func parsesTheNotReadyPartnerState() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingPartner", "notReadyYet"]).partner == .notReadyYet)
    }

    @Test func ignoresThemWithoutUITestingOrWhenUnknown() {
        #expect(UITestLaunchOptions(arguments: ["-uiTestingSharing", "joined"]).sharing == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTestingPartner", "snapshot"]).partner == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingSharing", "shared"]).sharing == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingPartner"]).partner == nil)
    }
}

struct UITestCycleGoalOptionTests {
    @Test func parsesTheGoalAndContraceptionWhenUITesting() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycleGoal", "tracking", "-seedContraception", "pill"])
        #expect(options.seedCycleGoal == .tracking)
        #expect(options.seedContraception == .pill)
    }

    @Test func ignoresThemWithoutUITestingOrWhenUnknown() {
        #expect(UITestLaunchOptions(arguments: ["-seedCycleGoal", "tracking"]).seedCycleGoal == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedCycleGoal", "avoiding"]).seedCycleGoal == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedContraception", "patch"]).seedContraception == nil)
    }
}

/// Phase 12: the partner UI behind `AppFeatures.cloudSync`, and a stored mode seed.
struct UITestPartnerUIOptionTests {
    @Test func partnerUIIsForcedOnlyWithUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingPartnerUI"]).forcesPartnerUI)
        #expect(UITestLaunchOptions(arguments: ["-uiTestingPartnerUI"]).forcesPartnerUI == false)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting"]).forcesPartnerUI == false)
    }

    @Test func seedAppModeParsesAKnownModeWhenUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedAppMode", "partner"]).seedAppMode == .partner)
        #expect(UITestLaunchOptions(arguments: ["-seedAppMode", "partner"]).seedAppMode == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedAppMode", "dad"]).seedAppMode == nil)
    }
}

/// Phase 15: a backup file opened at launch, the way an opened `.lunamom` file is.
struct UITestRestoreFileOptionTests {
    @Test func restoreFileIsReadOnlyWithUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingRestoreFile", "sample.lunamom"]).restoreFile == "sample.lunamom")
        #expect(UITestLaunchOptions(arguments: ["-uiTestingRestoreFile", "sample.lunamom"]).restoreFile == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting"]).restoreFile == nil)
    }
}

struct UITestRestoreOnReactivateOptionTests {
    @Test func reactivationFlagNeedsUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingRestoreOnReactivate"]).restoresFileOnReactivate)
        #expect(!UITestLaunchOptions(arguments: ["-uiTestingRestoreOnReactivate"]).restoresFileOnReactivate)
    }

    @Test func seedLastBackupDaysAgoIsReadOnlyWithUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedLastBackupDaysAgo", "45"]).seedLastBackupDaysAgo == 45)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedLastBackupDaysAgo", "-3"]).seedLastBackupDaysAgo == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedLastBackupDaysAgo", "x"]).seedLastBackupDaysAgo == nil)
        #expect(UITestLaunchOptions(arguments: ["-seedLastBackupDaysAgo", "45"]).seedLastBackupDaysAgo == nil)
    }

    @Test func seedPillParsesTypeAndOffset() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-seedPill", "21+7:11"])
        #expect(options.seedPill?.type == .withBreak)
        #expect(options.seedPill?.offsetDays == 11)
        #expect(UITestLaunchOptions(arguments: ["-seedPill", "28:3"]).seedPill == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedPill", "35:3"]).seedPill == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedPill", "28:-1"]).seedPill == nil)
        let settings = options.seedPill?.settings(today: date("2026-10-12T12:00:00Z"), calendar: utcCalendar)
        #expect(settings?.packStartDay == CalendarDay(year: 2026, month: 10, day: 1))
        #expect(settings?.enabled == true)
        #expect(settings?.pack(calendar: utcCalendar)?.pillNumber(on: date("2026-10-12T12:00:00Z")) == 12)
    }

    @Test func seedPregnancyEndedParsesBranchAndDays() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-seedPregnancyEnded", "loss:21"])
        #expect(options.seedPregnancyEnded == PregnancyEndSeed(branch: .loss, daysAgo: 21))
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedPregnancyEnded", "birth:0"]).seedPregnancyEnded?.branch == .birth)
        #expect(UITestLaunchOptions(arguments: ["-seedPregnancyEnded", "loss:21"]).seedPregnancyEnded == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedPregnancyEnded", "other:3"]).seedPregnancyEnded == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedPregnancyEnded", "loss:-1"]).seedPregnancyEnded == nil)
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-seedCareLowStreak", "1"]).seedCareLowStreak == 1)
        #expect(UITestLaunchOptions(arguments: ["-seedCareLowStreak", "1"]).seedCareLowStreak == nil)
    }

    @Test func seedPregnancyEndedStateAndMemory() {
        let seed = PregnancyEndSeed(branch: .birth, daysAgo: 21)
        let now = date("2026-10-02T12:00:00Z")
        let state = seed.state(now: now, calendar: utcCalendar)
        #expect(state.endDate == date("2026-09-11T00:00:00Z"))
        #expect(state.branch == .birth)
        #expect(state.firstPeriodConfirmedID == nil)
        let content = seed.memory(now: now, calendar: utcCalendar)
        #expect(content.branch == .birth)
        #expect(content.end == state.endDate)
        #expect(content.start! < content.end)
        #expect(!content.notes.isEmpty && !content.appointments.isEmpty && !content.weights.isEmpty && !content.kickDays.isEmpty)
    }
}

struct UITestContractionClockOptionTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func parsesTheStartTimeWhenUITesting() {
        let options = UITestLaunchOptions(arguments: ["-uiTesting", "-contractionClockStart", "10:30"])
        #expect(options.contractionClockStart == ContractionClockStart(hour: 10, minute: 30))
    }

    @Test func ignoresTheStartTimeWithoutUITestingOrWhenInvalid() {
        #expect(UITestLaunchOptions(arguments: ["-contractionClockStart", "10:30"]).contractionClockStart == nil)
        for bad in ["24:00", "10:60", "10", "ten:30", "-1:30", "10:30:00"] {
            #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-contractionClockStart", bad]).contractionClockStart == nil)
        }
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-contractionClockStart"]).contractionClockStart == nil)
    }

    /// The clock reads the start time on launch day, then ticks with the real clock.
    @Test func offsetMovesLaunchToTheStartTimeOfTheSameDay() {
        let start = ContractionClockStart(hour: 10, minute: 30)
        let launch = date("2026-11-07T13:39:14Z")
        let offset = start.offset(launch: launch, calendar: utc)
        #expect(launch.addingTimeInterval(offset) == date("2026-11-07T10:30:00Z"))
        #expect(launch.addingTimeInterval(65 + offset) == date("2026-11-07T10:31:05Z"))
        // Launched just after midnight: still 10:30 that day, ahead of the real clock.
        let early = date("2026-11-07T00:10:00Z")
        #expect(early.addingTimeInterval(start.offset(launch: early, calendar: utc)) == date("2026-11-07T10:30:00Z"))
    }
}
