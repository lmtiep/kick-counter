import Foundation
import KickCore
import SwiftData

/// Reads what the Home Screen / Lock Screen widget shows, on the device only
/// and without ever writing: no save, no duplicate clean-up (unlike `CycleStore`).
public enum WidgetReader {
    /// Everything the widget needs from the App Group, or `.unavailable` when it cannot
    /// be read: the store throws, or the settings hold no onboarding answer at all (they
    /// are not readable yet, e.g. before the first unlock after a restart, or the data
    /// is not there). The widget then retries soon instead of showing "get started".
    public static func read(
        defaults: UserDefaults = AppGroup.defaults,
        now: Date,
        calendar: Calendar = .current,
        url: URL? = nil
    ) -> WidgetRead {
        guard defaults.object(forKey: SettingsKey.hasCompletedOnboarding) != nil else { return .unavailable }
        do {
            let container = try KickPersistence.makeContainer(readOnly: true, url: url)
            return .input(try input(context: ModelContext(container), defaults: defaults, now: now, calendar: calendar))
        } catch {
            return .unavailable
        }
    }

    /// Settings from `defaults`; periods, logs and kick sessions only for the mode that needs them.
    public static func input(
        context: ModelContext,
        defaults: UserDefaults,
        now: Date,
        calendar: Calendar = .current
    ) throws -> WidgetInput {
        let mode = AppMode.load(from: defaults)
        var input = WidgetInput(
            mode: mode,
            hasCompletedOnboarding: defaults.bool(forKey: SettingsKey.hasCompletedOnboarding),
            preferences: CyclePreferences.load(from: defaults),
            settings: CycleSettings.load(from: defaults),
            dueDate: PregnancyProfile.load(from: defaults).dueDate
        )
        guard input.hasCompletedOnboarding else { return input }
        switch mode {
        case .tryingToConceive:
            let periods = try context.fetch(FetchDescriptor<PeriodEntry>(sortBy: [SortDescriptor(\.startDate)]))
            input.periods = CycleRules.mergingDuplicates(periods.map(\.record), calendar: calendar).periods
            let logs = try context.fetch(FetchDescriptor<CycleLog>(sortBy: [SortDescriptor(\.day)]))
            input.logs = CycleRules.mergingDuplicates(logs.map(\.record), calendar: calendar).logs
            // After a pregnancy ended the widget pauses predictions like the app (1.1 item 4).
            input.endState = PregnancyEndState.load(from: defaults)
        case .pregnant:
            input.kicksToday = try kicksToday(context: context, now: now, calendar: calendar)
        case .partner:
            break
        }
        return input
    }

    /// The count of today's latest finished session, as Today shows it.
    static func kicksToday(context: ModelContext, now: Date, calendar: Calendar) throws -> Int? {
        let startOfDay = calendar.startOfDay(for: now)
        let sessions = try context.fetch(FetchDescriptor<KickSession>(
            predicate: #Predicate { $0.statusRaw != "active" && $0.startedAt >= startOfDay }
        ))
        return HistoryStats.latestCompleted(sessions.map(\.state), on: now, calendar: calendar)?.count
    }
}
