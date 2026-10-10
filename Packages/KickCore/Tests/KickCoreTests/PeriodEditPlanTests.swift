import Foundation
import Testing
@testable import KickCore

/// Phase 19: ticking period days on the calendar becomes deletes, updates and
/// adds (spec §2.2).
struct PeriodEditPlanTests {
    let calendar: Calendar
    /// 2026-10-10, mid-afternoon in Hanoi.
    let now: Date

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 15))!
    }

    private func day(_ month: Int, _ day: Int, year: Int = 2026, in calendar: Calendar? = nil) -> Date {
        (calendar ?? self.calendar).date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Every day from `first` to `last`, both included.
    private func days(_ first: Date, _ last: Date, in calendar: Calendar? = nil) -> Set<Date> {
        let calendar = calendar ?? self.calendar
        var result: Set<Date> = []
        var current = first
        while current <= last {
            result.insert(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return result
    }

    /// The plan for an edit that started from `start` (by default, the stored
    /// periods' days) and ended with `ticked`.
    private func plan(_ ticked: Set<Date>, _ periods: [PeriodRecord], from start: Set<Date>? = nil, typicalLength: Int = 5) throws -> PeriodEditPlan {
        try make(ticked, periods, from: start, typicalLength: typicalLength).get()
    }

    private func make(_ ticked: Set<Date>, _ periods: [PeriodRecord], from start: Set<Date>? = nil, typicalLength: Int = 5) -> Result<PeriodEditPlan, PeriodEditPlan.Failure> {
        PeriodEditPlan.make(
            initial: start ?? initial(periods), ticked: ticked, periods: periods,
            now: now, typicalPeriodLength: typicalLength, calendar: calendar
        )
    }

    private func initial(_ periods: [PeriodRecord]) -> Set<Date> {
        PeriodEditPlan.initialDays(periods: periods, today: now, calendar: calendar)
    }

    // MARK: - Window and initial days

    @Test func windowIsTheLastTwoYearsUpToToday() {
        let window = PeriodEditPlan.window(now: now, calendar: calendar)
        #expect(window == day(10, 10, year: 2024)...day(10, 10))
    }

    @Test func initialDaysCoverEveryStoredPeriodDay() {
        let closed = PeriodRecord(startDate: day(9, 1), endDate: day(9, 3))
        let open = PeriodRecord(startDate: day(10, 9))
        let longOpen = PeriodRecord(startDate: day(8, 1))
        let beforeWindow = PeriodRecord(startDate: day(10, 8, year: 2024), endDate: day(10, 11, year: 2024))
        let expected = days(day(9, 1), day(9, 3))
            .union(days(day(10, 9), day(10, 10)))
            .union(days(day(8, 1), day(8, 10)))
            .union(days(day(10, 8, year: 2024), day(10, 11, year: 2024)))
        #expect(initial([closed, open, longOpen, beforeWindow]) == expected)
    }

    // MARK: - No change

    @Test func untouchedTicksGiveAnEmptyPlan() throws {
        let periods = [
            PeriodRecord(startDate: day(9, 1), endDate: day(9, 5)),
            PeriodRecord(startDate: day(10, 8)),
        ]
        let result = try plan(initial(periods), periods)
        #expect(result.isEmpty)
        #expect(result == PeriodEditPlan(deletes: [], updates: [], adds: []))
    }

    @Test func anOpenPeriodPastTenDaysIsLeftAloneWhenUntouched() throws {
        // Its ticks stop at day 10, but nothing was changed: never close it silently.
        let periods = [PeriodRecord(startDate: day(9, 20))]
        #expect(try plan(initial(periods), periods).isEmpty)
    }

    @Test func anOpenPeriodPastTenDaysClosesAtTheTypicalLengthWhenANewOneRunsThroughToday() throws {
        // As `CycleCoordinator.startPeriod`: closed at the typical length (6 days here).
        let stale = PeriodRecord(startDate: day(9, 20))
        let ticked = initial([stale]).union(days(day(10, 9), day(10, 10)))
        let result = try plan(ticked, [stale], typicalLength: 6)
        #expect(result.updates == [PeriodRecord(id: stale.id, startDate: day(9, 20), endDate: day(9, 25))])
        #expect(result.adds.count == 1)
        #expect(result.adds.first?.endDate == nil)
        #expect(result.deletes.isEmpty)
    }

    @Test func aStaleOpenPeriodBeforeTheWindowAlsoCloses() throws {
        // Never two open records, even when the stale one is out of reach.
        let stale = PeriodRecord(startDate: day(10, 1, year: 2024))
        let ticked = initial([stale]).union([day(10, 10)])
        let result = try plan(ticked, [stale], typicalLength: 4)
        #expect(result.updates == [PeriodRecord(id: stale.id, startDate: day(10, 1, year: 2024), endDate: day(10, 4, year: 2024))])
        #expect(result.adds.map(\.startDate) == [day(10, 10)])
        #expect(result.adds.first?.endDate == nil)
    }

    // MARK: - Adding

    @Test func aNewRunIsAdded() throws {
        let result = try plan(days(day(8, 1), day(8, 4)), [])
        #expect(result.deletes.isEmpty)
        #expect(result.updates.isEmpty)
        #expect(result.adds.count == 1)
        #expect(result.adds.first?.startDate == day(8, 1))
        #expect(result.adds.first?.endDate == day(8, 4))
    }

    @Test func aOneDayGapMakesTwoRuns() throws {
        let ticked = days(day(8, 1), day(8, 3)).union(days(day(8, 5), day(8, 6)))
        let result = try plan(ticked, [])
        #expect(result.adds.map(\.startDate) == [day(8, 1), day(8, 5)])
        #expect(result.adds.map(\.endDate) == [day(8, 3), day(8, 6)])
    }

    @Test func aRunEndingTodayIsStoredOpen() throws {
        let result = try plan(days(day(10, 9), day(10, 10)), [])
        #expect(result.adds.count == 1)
        #expect(result.adds.first?.startDate == day(10, 9))
        #expect(result.adds.first?.endDate == nil)
    }

    @Test func aRunAcrossAMonthBoundaryIsOnePeriod() throws {
        let result = try plan(days(day(8, 30), day(9, 2)), [])
        #expect(result.adds.count == 1)
        #expect(result.adds.first?.startDate == day(8, 30))
        #expect(result.adds.first?.endDate == day(9, 2))
    }

    // MARK: - Extending and shortening

    @Test func extendingAndShorteningKeepTheID() throws {
        let stored = PeriodRecord(startDate: day(9, 3), endDate: day(9, 6))
        let cases: [(Set<Date>, Date, Date)] = [
            (days(day(9, 1), day(9, 6)), day(9, 1), day(9, 6)), // earlier start
            (days(day(9, 3), day(9, 8)), day(9, 3), day(9, 8)), // later end
            (days(day(9, 4), day(9, 6)), day(9, 4), day(9, 6)), // later start
            (days(day(9, 3), day(9, 4)), day(9, 3), day(9, 4)), // earlier end
        ]
        for (ticked, start, end) in cases {
            let result = try plan(ticked, [stored])
            #expect(result.deletes.isEmpty)
            #expect(result.adds.isEmpty)
            #expect(result.updates == [PeriodRecord(id: stored.id, startDate: start, endDate: end)])
        }
    }

    // MARK: - Splitting, merging, removing

    @Test func splittingKeepsTheIDOnTheFirstPart() throws {
        let stored = PeriodRecord(startDate: day(9, 1), endDate: day(9, 6))
        var ticked = initial([stored])
        ticked.remove(day(9, 3))
        let result = try plan(ticked, [stored])
        #expect(result.deletes.isEmpty)
        #expect(result.updates == [PeriodRecord(id: stored.id, startDate: day(9, 1), endDate: day(9, 2))])
        #expect(result.adds.count == 1)
        #expect(result.adds.first?.startDate == day(9, 4))
        #expect(result.adds.first?.endDate == day(9, 6))
        #expect(result.adds.first?.id != stored.id)
    }

    @Test func mergingKeepsTheEarliestID() throws {
        let first = PeriodRecord(startDate: day(9, 1), endDate: day(9, 3))
        let second = PeriodRecord(startDate: day(9, 5), endDate: day(9, 7))
        var ticked = initial([first, second])
        ticked.insert(day(9, 4))
        let result = try plan(ticked, [second, first])
        #expect(result.updates == [PeriodRecord(id: first.id, startDate: day(9, 1), endDate: day(9, 7))])
        #expect(result.deletes == [second.id])
        #expect(result.adds.isEmpty)
    }

    @Test func untickingEverythingDeletesEveryPeriod() throws {
        let first = PeriodRecord(startDate: day(8, 1), endDate: day(8, 3))
        let second = PeriodRecord(startDate: day(10, 9))
        let result = try plan([], [second, first])
        #expect(result.deletes == [first.id, second.id])
        #expect(result.updates.isEmpty)
        #expect(result.adds.isEmpty)
    }

    // MARK: - Open periods

    @Test func anOpenPeriodExtendedEarlierStaysOpen() throws {
        let open = PeriodRecord(startDate: day(10, 8))
        var ticked = initial([open])
        ticked.insert(day(10, 7))
        let result = try plan(ticked, [open])
        #expect(result.updates == [PeriodRecord(id: open.id, startDate: day(10, 7), endDate: nil)])
    }

    @Test func untickingTodayClosesAnOpenPeriod() throws {
        let open = PeriodRecord(startDate: day(10, 8))
        var ticked = initial([open])
        ticked.remove(day(10, 10))
        let result = try plan(ticked, [open])
        #expect(result.updates == [PeriodRecord(id: open.id, startDate: day(10, 8), endDate: day(10, 9))])
    }

    @Test func tickingThroughTodayReopensAClosedPeriod() throws {
        let closed = PeriodRecord(startDate: day(10, 7), endDate: day(10, 8))
        let ticked = days(day(10, 7), day(10, 10))
        let result = try plan(ticked, [closed])
        #expect(result.updates == [PeriodRecord(id: closed.id, startDate: day(10, 7), endDate: nil)])
    }

    // MARK: - Window

    @Test func aPeriodStartingBeforeTheWindowIsLeftAlone() throws {
        let old = PeriodRecord(startDate: day(10, 8, year: 2024), endDate: day(10, 12, year: 2024))
        // Its days are unticked, and a day right after it is ticked: neither touches it.
        let result = try plan([day(10, 13, year: 2024)], [old])
        #expect(result.deletes.isEmpty)
        #expect(result.updates.isEmpty)
        #expect(result.adds.map(\.startDate) == [day(10, 13, year: 2024)])
        #expect(result.adds.map(\.endDate) == [day(10, 13, year: 2024)])
    }

    @Test func daysOutsideTheWindowOrInTheFutureAreIgnored() throws {
        let ticked: Set<Date> = [day(10, 9, year: 2024), day(10, 11), day(11, 2)]
        #expect(try plan(ticked, []).isEmpty)
    }

    // MARK: - Length limit

    @Test func aRunLongerThanTenDaysFails() {
        let ticked = days(day(9, 1), day(9, 11))
        #expect(make(ticked, []) == .failure(.periodTooLong))
    }

    @Test func aTenDayRunIsAllowed() throws {
        let result = try plan(days(day(9, 1), day(9, 10)), [])
        #expect(result.adds.first?.endDate == day(9, 10))
    }

    // MARK: - Daylight saving time

    @Test func runsSpanDaylightSavingChanges() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let now = newYork.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9))!
        // Clocks go forward on 8 March and back on 1 November 2026.
        let spring = days(day(3, 6, in: newYork), day(3, 10, in: newYork), in: newYork)
        let autumn = days(day(10, 30, in: newYork), day(11, 3, in: newYork), in: newYork)
        let result = try PeriodEditPlan.make(
            initial: [], ticked: spring.union(autumn), periods: [], now: now, typicalPeriodLength: 5, calendar: newYork
        ).get()
        #expect(result.adds.map(\.startDate) == [day(3, 6, in: newYork), day(10, 30, in: newYork)])
        #expect(result.adds.map(\.endDate) == [day(3, 10, in: newYork), day(11, 3, in: newYork)])
    }

    @Test func runsSpanAMidnightDaylightSavingChange() throws {
        // In Santiago clocks jump from 00:00 to 01:00 on 6 September 2026, so that
        // day starts at 01:00 and stepping from midnight would drift.
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = TimeZone(identifier: "America/Santiago")!
        let now = santiago.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 9))!
        let dayIn = { (d: Int) in santiago.startOfDay(for: santiago.date(from: DateComponents(year: 2026, month: 9, day: d, hour: 12))!) }
        let ticked: Set<Date> = Set((3...9).map(dayIn))
        let result = try PeriodEditPlan.make(
            initial: [], ticked: ticked, periods: [], now: now, typicalPeriodLength: 5, calendar: santiago
        ).get()
        #expect(result.adds.map(\.startDate) == [dayIn(3)])
        #expect(result.adds.map(\.endDate) == [dayIn(9)])

        let stored = PeriodRecord(startDate: dayIn(4), endDate: dayIn(8))
        let initial = PeriodEditPlan.initialDays(periods: [stored], today: now, calendar: santiago)
        #expect(initial == Set((4...8).map(dayIn)))
    }

    // MARK: - Only what the user touched changes

    @Test func aPeriodAddedUnderneathIsKept() throws {
        // Started from Today while the edit was open: not in the edit's start.
        let added = PeriodRecord(startDate: day(10, 9))
        let ticked: Set<Date> = [day(8, 1)]
        let result = try plan(ticked, [added], from: [])
        #expect(result.deletes.isEmpty)
        #expect(result.updates.isEmpty)
        #expect(result.adds.map(\.startDate) == [day(8, 1)])
    }

    @Test func anEditAcrossMidnightKeepsAnOpenPeriodOpen() throws {
        // The edit started yesterday, when the open period covered 8–9 October.
        let open = PeriodRecord(startDate: day(10, 8))
        let start = days(day(10, 8), day(10, 9))
        let result = try plan(start.union([day(8, 1)]), [open], from: start)
        #expect(result.updates.isEmpty)
        #expect(result.deletes.isEmpty)
        #expect(result.adds.map(\.startDate) == [day(8, 1)])
        #expect(result.adds.map(\.endDate) == [day(8, 1)])
    }

    @Test func aPeriodDeletedUnderneathIsNotReAdded() throws {
        let start = days(day(9, 1), day(9, 5))
        let result = try plan(start.union([day(8, 1)]), [], from: start)
        #expect(result.adds.map(\.startDate) == [day(8, 1)])
        #expect(result.adds.map(\.endDate) == [day(8, 1)])
        #expect(result.updates.isEmpty)
    }

    @Test func adjacentPeriodsStaySeparateWhenAnotherMonthIsEdited() throws {
        let first = PeriodRecord(startDate: day(9, 1), endDate: day(9, 3))
        let second = PeriodRecord(startDate: day(9, 4), endDate: day(9, 6))
        let ticked = initial([first, second]).union([day(7, 1)])
        let result = try plan(ticked, [first, second])
        #expect(result.deletes.isEmpty)
        #expect(result.updates.isEmpty)
        #expect(result.adds.map(\.startDate) == [day(7, 1)])
    }

    @Test func aLongStoredPeriodDoesNotBlockOtherEdits() throws {
        let long = PeriodRecord(startDate: day(9, 1), endDate: day(9, 14))
        let ticked = initial([long]).union([day(7, 1)])
        let result = try plan(ticked, [long])
        #expect(result.deletes.isEmpty)
        #expect(result.updates.isEmpty)
        #expect(result.adds.map(\.startDate) == [day(7, 1)])
    }

    @Test func aLongStoredPeriodStillFailsWhenTouched() {
        let long = PeriodRecord(startDate: day(9, 1), endDate: day(9, 14))
        var ticked = initial([long])
        ticked.remove(day(9, 14))
        #expect(make(ticked, [long]) == .failure(.periodTooLong))
    }

    @Test func overlappingDuplicatesAreLeftAloneWhenUntouched() throws {
        let open = PeriodRecord(startDate: day(6, 1))
        let closed = PeriodRecord(startDate: day(6, 4), endDate: day(6, 6))
        let ticked = initial([open, closed]).union([day(8, 1)])
        let result = try plan(ticked, [open, closed])
        #expect(result.deletes.isEmpty)
        #expect(result.updates.isEmpty)
        #expect(result.adds.map(\.startDate) == [day(8, 1)])
    }

    @Test func tickingTheGapBetweenTwoPeriodsMergesThem() throws {
        // Ticking 9/4 touches the first period; its run now meets the second.
        let first = PeriodRecord(startDate: day(9, 1), endDate: day(9, 3))
        let second = PeriodRecord(startDate: day(9, 5), endDate: day(9, 7))
        let ticked = initial([first, second]).union([day(9, 4)])
        let result = try plan(ticked, [first, second], from: initial([first, second]))
        #expect(result.updates == [PeriodRecord(id: first.id, startDate: day(9, 1), endDate: day(9, 7))])
        #expect(result.deletes == [second.id])
    }

    @Test func tickingTheDayAfterAPeriodExtendsIt() throws {
        let stored = PeriodRecord(startDate: day(9, 1), endDate: day(9, 3))
        let third = PeriodRecord(startDate: day(9, 20), endDate: day(9, 22))
        let ticked = initial([stored, third]).union([day(9, 4)])
        let result = try plan(ticked, [stored, third])
        #expect(result.updates == [PeriodRecord(id: stored.id, startDate: day(9, 1), endDate: day(9, 4))])
        #expect(result.deletes.isEmpty)
        #expect(result.adds.isEmpty)
    }
}

/// Phase 19: `CycleCoordinator.applyPeriodEdits` saves a plan in one write.
@MainActor
struct PeriodEditCoordinatorTests {
    let repository: FakeCycleRepository
    let clock: TestClock
    let coordinator: CycleCoordinator

    init() {
        let repository = FakeCycleRepository()
        let clock = TestClock(date("2026-10-10T12:00:00Z"))
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        self.repository = repository
        self.clock = clock
        coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: FakeNotificationCenter()),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "Fertile", body: "Soon"),
                period: NotificationText(title: "Period", body: "Tomorrow"),
                late: NotificationText(title: "Late", body: "Test")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func plan(_ ticked: Set<Date>) throws -> PeriodEditPlan {
        let periods = coordinator.periods
        return try PeriodEditPlan.make(
            initial: PeriodEditPlan.initialDays(periods: periods, today: clock.now, calendar: utcCalendar),
            ticked: ticked, periods: periods, now: clock.now,
            typicalPeriodLength: coordinator.settings.typicalPeriodLength, calendar: utcCalendar
        ).get()
    }

    @Test func appliesEveryChangeInOneCall() async throws {
        let first = PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-03"))
        let second = PeriodRecord(startDate: day("2026-09-05"), endDate: day("2026-09-07"))
        repository.seed(periods: [first, second])
        await coordinator.load()
        var ticked = PeriodEditPlan.initialDays(periods: coordinator.periods, today: clock.now, calendar: utcCalendar)
        ticked.insert(day("2026-09-04"))
        ticked.formUnion([day("2026-08-01"), day("2026-08-02")])

        #expect(await coordinator.applyPeriodEdits(try plan(ticked)) == nil)

        #expect(repository.periodChangeCalls == 1)
        #expect(coordinator.periods.count == 2)
        #expect(coordinator.periods.first?.startDate == day("2026-08-01"))
        #expect(coordinator.periods.first?.endDate == day("2026-08-02"))
        #expect(coordinator.periods.last == PeriodRecord(id: first.id, startDate: day("2026-09-01"), endDate: day("2026-09-07")))
    }

    @Test func anEmptyPlanWritesNothing() async {
        await coordinator.load()
        #expect(await coordinator.applyPeriodEdits(PeriodEditPlan()) == nil)
        #expect(repository.periodChangeCalls == 0)
    }

    @Test func aFailedSaveLeavesThePeriodsUnchanged() async throws {
        let stored = PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-05"))
        repository.seed(periods: [stored])
        await coordinator.load()
        repository.failNextWrite = true

        #expect(await coordinator.applyPeriodEdits(try plan([day("2026-08-01")])) == .saveFailed)

        #expect(repository.storedPeriods == [stored])
        #expect(coordinator.periods == [stored])
    }

    @Test func anInvalidChangeLeavesThePeriodsUnchanged() async {
        let stored = PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-05"))
        repository.seed(periods: [stored])
        await coordinator.load()
        // Shrinking is fine on its own, but the add overlaps the shrunk period.
        let edits = PeriodEditPlan(
            updates: [PeriodRecord(id: stored.id, startDate: day("2026-09-01"), endDate: day("2026-09-03"))],
            adds: [PeriodRecord(startDate: day("2026-09-03"), endDate: day("2026-09-04"))]
        )

        #expect(await coordinator.applyPeriodEdits(edits) == .overlapsExistingPeriod)

        #expect(repository.storedPeriods == [stored])
        #expect(coordinator.periods == [stored])
    }

    @Test func theForecastFollowsTheEdit() async throws {
        repository.seed(periods: [PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-05"))])
        await coordinator.load()
        #expect(coordinator.forecast?.currentPeriodStart == day("2026-09-01"))
        var ticked = PeriodEditPlan.initialDays(periods: coordinator.periods, today: clock.now, calendar: utcCalendar)
        ticked.formUnion([day("2026-09-29"), day("2026-09-30"), day("2026-10-01")])

        #expect(await coordinator.applyPeriodEdits(try plan(ticked)) == nil)

        #expect(coordinator.forecast?.currentPeriodStart == day("2026-09-29"))
        #expect(coordinator.forecast?.cycleDay == 12)
    }
}
