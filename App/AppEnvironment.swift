import Foundation
import KickCore
import KickData
import SwiftData

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let coordinator: KickCoordinator
    let appointments: AppointmentCoordinator
    let cycle: CycleCoordinator
    let content: WeeklyContentLibrary?

    private static let arguments = ProcessInfo.processInfo.arguments
    #if DEBUG
    static let isUITesting = AppClock.launchOptions.isUITesting
    static let forceDarkMode = arguments.contains("-forceDarkMode")
    #else
    static let isUITesting = false
    static let forceDarkMode = false
    #endif

    static func make() throws -> AppEnvironment {
        #if DEBUG
        if isUITesting {
            AppGroup.defaults.removePersistentDomain(forName: AppGroup.identifier)
            if arguments.contains("-skipOnboarding") {
                AppGroup.defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
            }
            if let seededDueDate = AppClock.launchOptions.seedDueDate {
                PregnancyProfile.saveDueDate(seededDueDate, to: AppGroup.defaults)
            }
            if AppClock.launchOptions.seedCycles != nil {
                AppMode.save(.tryingToConceive, to: AppGroup.defaults)
            }
        }
        #endif
        let container = try KickPersistence.makeContainer(inMemory: isUITesting)
        #if DEBUG
        if isUITesting, AppClock.launchOptions.seedSessions {
            try seedSessions(into: container.mainContext)
        }
        #endif
        let notificationCenter: NotificationCenterClient = isUITesting ? DisabledNotificationCenter() : SystemNotificationCenter()
        let liveActivities: LiveActivityManaging = isUITesting ? NoopLiveActivityManager() : SystemLiveActivityManager()
        let notifications = NotificationScheduler(center: notificationCenter)
        let kickStore = KickStore(context: container.mainContext)
        #if DEBUG
        if isUITesting, AppClock.launchOptions.seedOverdueSession {
            try seedOverdueSession(into: kickStore)
        }
        #endif
        let coordinator = KickCoordinator(
            store: kickStore,
            notifications: notifications,
            liveActivities: liveActivities,
            overdueText: ReminderTexts.overdue
        )
        let appointments = AppointmentCoordinator(
            store: AppointmentStore(context: container.mainContext),
            notifications: notifications,
            reminderText: ReminderTexts.appointment,
            now: { AppClock.now() }
        )
        let cycleStore = CycleStore(context: container.mainContext)
        #if DEBUG
        if isUITesting, let scenario = AppClock.launchOptions.seedCycles {
            try seedCycles(scenario, into: cycleStore)
        }
        #endif
        let cycle = CycleCoordinator(
            store: cycleStore,
            notifications: notifications,
            reminderTexts: ReminderTexts.cycle,
            defaults: AppGroup.defaults,
            now: { AppClock.now() }
        )
        return AppEnvironment(
            container: container,
            coordinator: coordinator,
            appointments: appointments,
            cycle: cycle,
            content: WeeklyContentLibrary.loadBundled()
        )
    }

    #if DEBUG
    /// `-uiTesting -seedCycles <scenario>`: sample periods and logs relative to the pinned clock.
    private static func seedCycles(_ scenario: CycleSeedScenario, into store: CycleStore) throws {
        let now = AppClock.now()
        let records = scenario.records(today: now)
        for period in records.periods {
            try store.addPeriod(period, today: now)
        }
        for log in records.logs {
            try store.saveLog(log, today: now)
        }
    }

    /// `-uiTesting -seedOverdueSession`: a session started 2 h 5 min ago on the real
    /// clock (counting never uses the pinned one) with 4 movements, so the 2-hour
    /// card shows on Kicks.
    private static func seedOverdueSession(into store: KickStore) throws {
        let start = Date().addingTimeInterval(-125 * 60)
        for minutes in [0.0, 15, 45, 80] {
            _ = try store.addKick(at: start.addingTimeInterval(minutes * 60))
        }
    }

    /// `-uiTesting -seedSessions`: `SessionSeed`'s four weeks of sessions,
    /// relative to the pinned clock (spec §6).
    private static func seedSessions(into context: ModelContext) throws {
        for state in SessionSeed.sessions(today: AppClock.now()) {
            let session = KickSession(startedAt: state.startedAt)
            session.endedAt = state.endedAt
            session.status = state.status
            session.exceededThreshold = state.exceededThreshold
            context.insert(session)
            // Insert before linking, like KickStore: a relationship to a model
            // outside the context traps.
            for timestamp in state.kicks {
                let kick = Kick(timestamp: timestamp)
                context.insert(kick)
                kick.session = session
            }
        }
        try context.save()
    }
    #endif
}
