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
        let notificationCenter: NotificationCenterClient = isUITesting ? DisabledNotificationCenter() : SystemNotificationCenter()
        let liveActivities: LiveActivityManaging = isUITesting ? NoopLiveActivityManager() : SystemLiveActivityManager()
        let notifications = NotificationScheduler(center: notificationCenter)
        let coordinator = KickCoordinator(
            store: KickStore(context: container.mainContext),
            notifications: notifications,
            liveActivities: liveActivities,
            overdueText: NotificationText(title: L10n.overdueTitle, body: L10n.overdueBody)
        )
        let appointments = AppointmentCoordinator(
            store: AppointmentStore(context: container.mainContext),
            notifications: notifications,
            reminderText: NotificationText(title: L10n.appointmentsReminderTitle, body: L10n.appointmentsReminderBody),
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
            reminderTexts: CycleReminderTexts(
                fertile: NotificationText(title: L10n.cycleReminderFertileTitle, body: L10n.cycleReminderFertileBody),
                period: NotificationText(title: L10n.cycleReminderPeriodTitle, body: L10n.cycleReminderPeriodBody),
                late: NotificationText(title: L10n.cycleReminderLateTitle, body: L10n.cycleReminderLateBody)
            ),
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
    #endif
}
