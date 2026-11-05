import Foundation
import Testing
@testable import KickCore

struct WidgetSnapshotTests {
    let calendar = utcCalendar

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }
    private func noon(_ iso: String) -> Date { date("\(iso)T12:00:00Z") }

    /// A closed 5-day period starting on each day, oldest first (28-day cycles when 28 days apart).
    private func periods(_ starts: String...) -> [PeriodRecord] {
        starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
    }

    private func cycleInput(
        goal: CycleGoal,
        contraception: Contraception? = nil,
        periods: [PeriodRecord],
        logs: [CycleLogRecord] = []
    ) -> WidgetInput {
        WidgetInput(
            mode: .tryingToConceive,
            hasCompletedOnboarding: true,
            preferences: CyclePreferences(goal: goal, contraception: contraception),
            periods: periods,
            logs: logs
        )
    }

    private func pregnancyInput(due: String?, kicks: Int? = nil) -> WidgetInput {
        WidgetInput(mode: .pregnant, hasCompletedOnboarding: true, dueDate: due.map(day), kicksToday: kicks)
    }

    private func make(_ input: WidgetInput, _ now: String) -> WidgetSnapshot {
        WidgetSnapshot.make(input, now: noon(now), calendar: calendar)
    }

    /// A due date that puts `now` `elapsed` days into the pregnancy.
    private func due(elapsed: Int, now: String) -> String {
        let value = calendar.date(byAdding: .day, value: 280 - elapsed, to: day(now))!
        return ISO8601DateFormatter().string(from: value).prefix(10).description
    }

    // MARK: - Needs setup

    @Test func notOnboardedNeedsSetup() {
        let input = WidgetInput(mode: .pregnant, hasCompletedOnboarding: false, dueDate: day("2027-01-19"))
        #expect(make(input, "2026-10-02").content == .needsSetup)
    }

    @Test func partnerModeIsNeutral() {
        let input = WidgetInput(mode: .partner, hasCompletedOnboarding: true, dueDate: day("2027-01-19"))
        #expect(make(input, "2026-10-02").content == .needsSetup)
    }

    @Test func pregnantWithoutDueDateNeedsSetup() {
        #expect(make(pregnancyInput(due: nil), "2026-10-02").content == .needsSetup)
    }

    @Test func dueDateThatIsNotAPregnancyNeedsSetup() {
        #expect(make(pregnancyInput(due: "2028-01-01"), "2026-10-02").content == .needsSetup)
    }

    @Test func cycleModeWithoutPeriodsNeedsSetup() {
        #expect(make(cycleInput(goal: .tracking, periods: []), "2026-10-02").content == .needsSetup)
        #expect(make(cycleInput(goal: .conceiving, periods: []), "2026-10-02").content == .needsSetup)
    }

    // MARK: - Cycle tracking

    @Test func trackingCountsDaysToTheNextPeriod() throws {
        // Period started Oct 1, 28-day cycle: next on Oct 29.
        let snapshot = make(cycleInput(goal: .tracking, periods: periods("2026-09-03", "2026-10-01")), "2026-10-19")
        guard case .cycle(let cycle) = snapshot.content else { Issue.record("expected cycle"); return }
        #expect(cycle.headline == .upcoming(days: 10))
        #expect(cycle.nextPeriodDate == day("2026-10-29"))
        #expect(cycle.cycleDay == 19)
        #expect(cycle.expectsWithdrawalBleed == false)
        #expect(!cycle.ring.isEmpty)
    }

    @Test func trackingDuringAPeriodShowsTheDay() throws {
        let snapshot = make(cycleInput(goal: .tracking, periods: periods("2026-10-01")), "2026-10-02")
        guard case .cycle(let cycle) = snapshot.content else { Issue.record("expected cycle"); return }
        #expect(cycle.headline == .onPeriod(day: 2))
    }

    @Test func trackingWhenLateShowsDaysLate() throws {
        // Next period was due Oct 29; today Nov 1 -> 3 days late.
        let snapshot = make(cycleInput(goal: .tracking, periods: periods("2026-09-03", "2026-10-01")), "2026-11-01")
        guard case .cycle(let cycle) = snapshot.content else { Issue.record("expected cycle"); return }
        #expect(cycle.headline == .late(days: 3))
    }

    @Test func trackingOnTheDueDay() throws {
        let snapshot = make(cycleInput(goal: .tracking, periods: periods("2026-09-03", "2026-10-01")), "2026-10-29")
        guard case .cycle(let cycle) = snapshot.content else { Issue.record("expected cycle"); return }
        #expect(cycle.headline == .dueToday)
    }

    @Test func hormonalContraceptionCallsItAnExpectedBleed() throws {
        let input = cycleInput(goal: .tracking, contraception: .pill, periods: periods("2026-10-01"))
        guard case .cycle(let cycle) = make(input, "2026-10-10").content else { Issue.record("expected cycle"); return }
        #expect(cycle.expectsWithdrawalBleed)
        #expect(!cycle.ring.contains { $0.kind == .fertile || $0.kind == .ovulation })
    }

    // MARK: - Trying to conceive

    // Period Oct 1 (28-day default): next Oct 29, ovulation Oct 15, window Oct 10 - Oct 16.
    private let conceiving = [PeriodRecord(startDate: date("2026-10-01T00:00:00Z"), endDate: date("2026-10-05T00:00:00Z"))]

    private func fertility(_ now: String, periods: [PeriodRecord]? = nil) -> WidgetSnapshot.FertilityContent? {
        let snapshot = make(cycleInput(goal: .conceiving, periods: periods ?? conceiving), now)
        guard case .fertility(let content) = snapshot.content else { return nil }
        return content
    }

    @Test func ovulationDayIsNamed() {
        #expect(fertility("2026-10-15")?.status == .ovulationDay)
    }

    @Test func fertileDaysAreHigh() {
        #expect(fertility("2026-10-12")?.status == .high)
        // The day before ovulation is the "peak" day of the forecast but not the ovulation day.
        #expect(fertility("2026-10-14")?.status == .high)
    }

    @Test func daysOutsideTheWindowAreLow() {
        #expect(fertility("2026-10-08")?.status == .low)
        #expect(fertility("2026-10-20")?.status == .low)
    }

    @Test func aLoggedPeriodDayIsPeriod() {
        #expect(fertility("2026-10-03")?.status == .period)
    }

    @Test func lateOverridesTheFertileStatuses() {
        #expect(fertility("2026-11-02")?.status == .late(days: 4))
    }

    @Test func fertilityCarriesCycleDayWindowAndAWeekStrip() throws {
        let content = try #require(fertility("2026-10-12"))
        #expect(content.cycleDay == 12)
        #expect(content.fertileWindow == day("2026-10-10")...day("2026-10-16"))
        #expect(content.strip.count == 7)
        #expect(content.strip.first?.date == day("2026-10-12"))
        #expect(content.strip.first?.isToday == true)
        #expect(content.strip.map(\.status) == [.fertile, .fertile, .peak, .peak, .fertile, .low, .low])
    }

    @Test func conceivingIgnoresAStoredContraception() {
        let input = cycleInput(goal: .conceiving, contraception: .pill, periods: conceiving)
        guard case .fertility(let content) = make(input, "2026-10-12").content else { Issue.record("expected fertility"); return }
        #expect(content.status == .high)
    }

    // MARK: - Pregnancy

    private func pregnancy(elapsed: Int, kicks: Int? = nil) -> WidgetSnapshot.PregnancyContent? {
        let now = "2026-10-02"
        let snapshot = make(pregnancyInput(due: due(elapsed: elapsed, now: now), kicks: kicks), now)
        guard case .pregnancy(let content) = snapshot.content else { return nil }
        return content
    }

    @Test func weekThirtyHasSeventyDaysToGo() {
        let content = pregnancy(elapsed: 30 * 7 + 3)
        #expect(content?.weeks == 30)
        #expect(content?.days == 3)
        #expect(content?.daysRemaining == 67)
        #expect(content?.daysPastDue == 0)
        #expect(content?.fruitWeek == 30)
    }

    @Test func exactlyWeekThirtyIsSeventyDaysToGo() {
        #expect(pregnancy(elapsed: 210)?.daysRemaining == 70)
    }

    @Test func weekFourUsesItsOwnArtwork() {
        let content = pregnancy(elapsed: 4 * 7)
        #expect(content?.weeks == 4)
        #expect(content?.fruitWeek == 4)
        #expect(content?.kicks == .hidden)
    }

    @Test func veryEarlyWeeksClampTheArtwork() {
        #expect(pregnancy(elapsed: 2 * 7)?.fruitWeek == 4)
    }

    @Test func week41IsPastDue() {
        let content = pregnancy(elapsed: 41 * 7 + 2)
        #expect(content?.weeks == 41)
        #expect(content?.daysRemaining == 0)
        #expect(content?.daysPastDue == 9)
        #expect(content?.fruitWeek == 41)
    }

    @Test func weeksAfter42ClampTheArtwork() {
        #expect(pregnancy(elapsed: 44 * 7)?.fruitWeek == 42)
    }

    @Test func dueTodayIsWeek40WithNothingLeft() {
        let content = pregnancy(elapsed: 280)
        #expect(content?.weeks == 40)
        #expect(content?.daysRemaining == 0)
        #expect(content?.daysPastDue == 0)
    }

    @Test func kicksAreHiddenBeforeWeek28() {
        #expect(pregnancy(elapsed: 27 * 7 + 6, kicks: 6)?.kicks == .hidden)
    }

    @Test func kicksShowNotCountedAtZeroOrMissing() {
        #expect(pregnancy(elapsed: 28 * 7, kicks: nil)?.kicks == .notCounted)
        #expect(pregnancy(elapsed: 28 * 7, kicks: 0)?.kicks == .notCounted)
    }

    @Test func kicksShowTodaysCount() {
        #expect(pregnancy(elapsed: 30 * 7, kicks: 6)?.kicks == .counted(6))
    }

    // MARK: - Refresh

    @Test func refreshesAtTheNextLocalMidnight() {
        let snapshot = make(pregnancyInput(due: "2027-01-19"), "2026-10-02")
        #expect(snapshot.refreshDate == day("2026-10-03"))
    }

    @Test func refreshIsAfterNowEvenAtMidnightSharp() {
        let snapshot = WidgetSnapshot.make(pregnancyInput(due: "2027-01-19"), now: day("2026-10-02"), calendar: calendar)
        #expect(snapshot.refreshDate == day("2026-10-03"))
    }

    @Test func needsSetupAlsoRefreshesAtMidnight() {
        let snapshot = make(WidgetInput(mode: .pregnant, hasCompletedOnboarding: false), "2026-10-02")
        #expect(snapshot.refreshDate == day("2026-10-03"))
    }

    @Test func refreshFollowsADaylightSavingDay() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // Nov 1 2026 is the end of DST: that day has 25 hours.
        let now = newYork.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
        let snapshot = WidgetSnapshot.make(WidgetInput(mode: .pregnant, hasCompletedOnboarding: false), now: now, calendar: newYork)
        #expect(snapshot.refreshDate == newYork.date(from: DateComponents(year: 2026, month: 11, day: 2)))
    }

    // MARK: - After a pregnancy ended (1.1 item 4)

    @Test func pausedAfterAnEnding() {
        var input = cycleInput(goal: .tracking, periods: periods("2026-01-10", "2026-02-07"))
        input.endState = PregnancyEndState(branch: .loss, endDate: day("2026-09-01"), calendar: calendar)
        #expect(make(input, "2026-10-02").content == .paused)
        // No period at all: paused too, not "set up".
        input.periods = []
        #expect(make(input, "2026-10-02").content == .paused)
    }

    @Test func resumedUsesOnlyPeriodsAfterTheEnd() {
        let after = periods("2026-09-20")
        var input = cycleInput(goal: .tracking, periods: periods("2026-01-10", "2026-02-07") + after)
        input.endState = PregnancyEndState(branch: .birth, endDate: day("2026-09-01"), firstPeriodConfirmedID: after[0].id, calendar: calendar)
        guard case .cycle(let content) = make(input, "2026-10-02").content else {
            Issue.record("expected the cycle content")
            return
        }
        // One period after the end: the typical 28 days from 09-20.
        #expect(content.nextPeriodDate == day("2026-10-18"))
    }

    @Test func endStateIgnoredOutsideTheCycleMode() {
        var input = pregnancyInput(due: due(elapsed: 100, now: "2026-10-02"))
        input.endState = PregnancyEndState(branch: .loss, endDate: day("2026-09-01"), calendar: calendar)
        guard case .pregnancy = make(input, "2026-10-02").content else {
            Issue.record("expected the pregnancy content")
            return
        }
    }
}
