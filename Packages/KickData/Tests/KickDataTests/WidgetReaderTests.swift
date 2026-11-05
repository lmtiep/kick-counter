import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct WidgetReaderTests {
    let now = date("2026-10-02T12:00:00Z")
    let container: ModelContainer
    let defaults: UserDefaults

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        defaults = UserDefaults(suiteName: "WidgetReaderTests-\(UUID().uuidString)")!
    }

    private func read() throws -> WidgetInput {
        try WidgetReader.input(context: container.mainContext, defaults: defaults, now: now, calendar: utcCalendar)
    }

    @Test func notOnboardedReadsNoStoreData() throws {
        container.mainContext.insert(PeriodEntry(record: PeriodRecord(startDate: date("2026-09-20T00:00:00Z"))))
        let input = try read()
        #expect(input.hasCompletedOnboarding == false)
        #expect(input.periods.isEmpty)
    }

    @Test func cycleModeReadsPeriodsAndLogsAndSettings() throws {
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        AppMode.save(.tryingToConceive, to: defaults)
        defaults.set(CycleGoal.tracking.rawValue, forKey: SettingsKey.cycleGoal)
        defaults.set(30, forKey: SettingsKey.typicalCycleLength)
        container.mainContext.insert(PeriodEntry(record: PeriodRecord(startDate: date("2026-09-20T00:00:00Z"))))
        container.mainContext.insert(CycleLog(record: CycleLogRecord(day: date("2026-09-21T00:00:00Z"), lh: .negative)))
        let input = try read()
        #expect(input.mode == .tryingToConceive)
        #expect(input.preferences.goal == .tracking)
        #expect(input.settings.typicalCycleLength == 30)
        #expect(input.periods.count == 1)
        #expect(input.logs.count == 1)
    }

    @Test func readingMergesDuplicatesInMemoryWithoutDeletingThem() throws {
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        AppMode.save(.tryingToConceive, to: defaults)
        let context = container.mainContext
        context.insert(PeriodEntry(record: PeriodRecord(startDate: date("2026-09-20T00:00:00Z"), endDate: date("2026-09-24T00:00:00Z"))))
        context.insert(PeriodEntry(record: PeriodRecord(startDate: date("2026-09-21T00:00:00Z"), endDate: date("2026-09-25T00:00:00Z"))))
        try context.save()
        #expect(try read().periods.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<PeriodEntry>()) == 2)
    }

    @Test func pregnantReadsDueDateAndTodaysLatestFinishedKickCount() throws {
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        AppMode.save(.pregnant, to: defaults)
        PregnancyProfile.saveDueDate(date("2027-01-19T00:00:00Z"), to: defaults)
        let context = container.mainContext
        let morning = KickSession(startedAt: date("2026-10-02T08:00:00Z"))
        morning.statusRaw = SessionStatus.completed.rawValue
        morning.endedAt = date("2026-10-02T08:30:00Z")
        morning.kicks = (0..<10).map { Kick(timestamp: date("2026-10-02T08:00:00Z").addingTimeInterval(Double($0) * 60)) }
        context.insert(morning)
        let yesterday = KickSession(startedAt: date("2026-10-01T08:00:00Z"))
        yesterday.statusRaw = SessionStatus.completed.rawValue
        yesterday.endedAt = date("2026-10-01T08:30:00Z")
        yesterday.kicks = [Kick(timestamp: date("2026-10-01T08:05:00Z"))]
        context.insert(yesterday)
        try context.save()
        let input = try read()
        #expect(input.dueDate == date("2027-01-19T00:00:00Z"))
        #expect(input.kicksToday == 10)
    }

    @Test func noFinishedSessionTodayMeansNoCount() throws {
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        AppMode.save(.pregnant, to: defaults)
        let active = KickSession(startedAt: date("2026-10-02T08:00:00Z"))
        container.mainContext.insert(active)
        try container.mainContext.save()
        #expect(try read().kicksToday == nil)
    }
}
