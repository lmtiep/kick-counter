import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Phase 9: the goal in the coordinator — reminders per goal, Profile's goal
/// and mode choices, and finishing onboarding.
@MainActor
struct CycleCoordinatorGoalTests {
    let repository: FakeCycleRepository
    let center: FakeNotificationCenter
    let defaults: UserDefaults
    let coordinator: CycleCoordinator

    init() {
        let repository = FakeCycleRepository()
        let center = FakeNotificationCenter()
        let clock = TestClock(date("2026-09-05T12:00:00Z"))
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        self.repository = repository
        self.center = center
        self.defaults = defaults
        coordinator = CycleCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: "Fertile window soon", body: "In 2 days"),
                period: NotificationText(title: "Period tomorrow", body: "Due tomorrow"),
                late: NotificationText(title: "Period is late", body: "Consider a test")
            ),
            defaults: defaults,
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    /// Regular 28-day cycles; current period 2026-09-03 → next period 10-01.
    private func seedRegularCycles() {
        repository.seed(periods: ["2026-07-09", "2026-08-06", "2026-09-03"].map {
            PeriodRecord(startDate: day($0), endDate: utcCalendar.date(byAdding: .day, value: 4, to: day($0)))
        })
    }

    private var reminderIDs: Set<String> { Set(center.added.map(\.identifier)) }

    @Test func existingUsersKeepConceivingAndAllThreeReminders() async {
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.preferences.goal == .conceiving)
        #expect(coordinator.policy == .conceiving)
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func trackingSchedulesOnlyThePeriodReminders() async {
        CyclePreferences(goal: .tracking).save(to: defaults)
        seedRegularCycles()
        await coordinator.load()
        #expect(coordinator.policy.goal == .tracking)
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func changingTheGoalReschedulesWithoutPrompting() async {
        seedRegularCycles()
        await coordinator.load()
        center.status = .authorized
        await coordinator.updatePreferences(CyclePreferences(goal: .tracking, contraception: .pill))
        #expect(coordinator.preferences.contraception == .pill)
        #expect(CyclePreferences.load(from: defaults).goal == .tracking)
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
        await coordinator.updatePreferences(CyclePreferences(goal: .conceiving))
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
        #expect(center.requestCount == 0)
    }

    @Test func choosingACycleGoalFromPregnancySwitchesModeAndKeepsTheOtherAnswers() async {
        AppMode.save(.pregnant, to: defaults)
        CyclePreferences(goal: .conceiving, contraception: .copperIUD, regularity: .regular).save(to: defaults)
        seedRegularCycles()
        await coordinator.load()
        #expect(center.added.isEmpty)

        await coordinator.activateCycleMode(goal: .tracking)

        #expect(coordinator.mode == .tryingToConceive)
        #expect(coordinator.preferences == CyclePreferences(goal: .tracking, contraception: .copperIUD, regularity: .regular))
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func endingThePregnancyKeepsTheStoredGoal() async {
        AppMode.save(.pregnant, to: defaults)
        CyclePreferences(goal: .tracking).save(to: defaults)
        await coordinator.activateTryingToConceive()
        #expect(coordinator.preferences.goal == .tracking)
    }

    @Test func finishingOnboardingStoresEveryAnswerAndThePeriod() async throws {
        AppMode.save(.pregnant, to: defaults)
        let failure = await coordinator.completeOnboarding(
            goal: .tracking,
            settings: CycleSettings(typicalCycleLength: 30, typicalPeriodLength: 4),
            firstPeriodStart: day("2026-08-30"),
            regularity: .irregular,
            contraception: .condom,
            requestNotifications: true
        )
        #expect(failure == nil)
        #expect(coordinator.mode == .tryingToConceive)
        #expect(coordinator.settings == CycleSettings(typicalCycleLength: 30, typicalPeriodLength: 4))
        #expect(CyclePreferences.load(from: defaults) == CyclePreferences(goal: .tracking, contraception: .condom, regularity: .irregular))
        let period = try #require(repository.storedPeriods.first)
        #expect(period.startDate == day("2026-08-30"))
        #expect(period.endDate == day("2026-09-02"))
        #expect(coordinator.forecast?.nextPeriodStart == day("2026-09-29"))
        #expect(center.requestCount == 0) // already authorized: nothing to ask
        #expect(reminderIDs == ["cycle-period", "cycle-late"])
    }

    @Test func turnOnRemindersAsksForPermission() async {
        center.status = .notDetermined
        await coordinator.completeOnboarding(
            goal: .conceiving, settings: CycleSettings(), firstPeriodStart: day("2026-09-03"),
            regularity: .unknown, contraception: nil, requestNotifications: true
        )
        #expect(center.requestCount == 1)
        #expect(reminderIDs == ["cycle-fertile", "cycle-period", "cycle-late"])
    }

    @Test func laterNeverAsksForPermission() async {
        center.status = .notDetermined
        await coordinator.completeOnboarding(
            goal: .conceiving, settings: CycleSettings(), firstPeriodStart: day("2026-09-03"),
            regularity: .unknown, contraception: nil, requestNotifications: false
        )
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
        #expect(coordinator.periods.count == 1)
    }

    /// Fix round 1: "Bật nhắc nhở" must ask even when there is nothing to remind about yet.
    @Test func finishingWithoutAPeriodHasNoForecast() async {
        center.status = .notDetermined
        await coordinator.completeOnboarding(
            goal: .tracking, settings: CycleSettings(), firstPeriodStart: nil,
            regularity: .unknown, contraception: nil, requestNotifications: true
        )
        #expect(coordinator.forecast == nil)
        #expect(repository.storedPeriods.isEmpty)
        #expect(coordinator.mode == .tryingToConceive)
        #expect(center.requestCount == 1)
    }

    /// Fix round 1: and "Later" must still never ask, even without a forecast.
    @Test func finishingWithoutAPeriodAndRequestingLaterNeverAsks() async {
        center.status = .notDetermined
        await coordinator.completeOnboarding(
            goal: .tracking, settings: CycleSettings(), firstPeriodStart: nil,
            regularity: .unknown, contraception: nil, requestNotifications: false
        )
        #expect(center.requestCount == 0)
    }

    @Test func aFailedPeriodSaveIsReturnedAndTheAnswersAreKept() async {
        repository.failNextWrite = true
        let failure = await coordinator.completeOnboarding(
            goal: .tracking, settings: CycleSettings(typicalCycleLength: 33), firstPeriodStart: day("2026-09-03"),
            regularity: .regular, contraception: nil, requestNotifications: false
        )
        #expect(failure == .saveFailed)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.settings.typicalCycleLength == 33)
        #expect(coordinator.preferences.goal == .tracking)
        #expect(coordinator.mode == .tryingToConceive)
    }
}
