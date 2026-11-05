import Foundation
import KickCore
import SwiftData

/// Reads what the Home Screen / Lock Screen widget shows, on the device only
/// and without ever writing: no save, no duplicate clean-up (unlike `CycleStore`).
public enum WidgetReader {
    /// The App Group store opened for reading: saving through it is refused.
    public static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: KickPersistence.schema,
            allowsSave: false,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: KickPersistence.schema, configurations: configuration)
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
