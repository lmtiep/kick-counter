import Foundation
import KickCore
import KickData
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "environment")

@MainActor
struct AppEnvironment {
    let container: ModelContainer
    let coordinator: KickCoordinator
    let appointments: AppointmentCoordinator
    let cycle: CycleCoordinator
    let weight: WeightCoordinator
    let content: WeeklyContentLibrary?
    let knowledge: KnowledgeLibrary?
    let sharing: any PartnerSharing
    let partnerShare: PartnerShareCoordinator
    let partnerPublisher: PartnerPublisher
    let partnerJourney: PartnerJourneyModel

    private static let arguments = ProcessInfo.processInfo.arguments
    #if DEBUG
    static let isUITesting = AppClock.launchOptions.isUITesting
    static let forceDarkMode = arguments.contains("-forceDarkMode")
    #else
    static let isUITesting = false
    static let forceDarkMode = false
    #endif

    /// The partner UI (Profile's share card, partner mode, invitations) exists only with
    /// iCloud (`AppFeatures.cloudSync`, off in 1.0). UI tests of the partner flows force it
    /// with `-uiTestingPartnerUI` so they keep covering it for when the switch comes back.
    static let showsPartnerUI = AppFeatures.cloudSync || AppClock.launchOptions.forcesPartnerUI

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
            // Phase 9: `-seedCycleGoal` / `-seedContraception`; neither means a
            // user from before phase 9 (conceiving, not asked).
            let options = AppClock.launchOptions
            if options.seedCycleGoal != nil || options.seedContraception != nil {
                CyclePreferences(goal: options.seedCycleGoal ?? .conceiving, contraception: options.seedContraception)
                    .save(to: AppGroup.defaults)
            }
            if AppClock.launchOptions.partner != nil {
                AppMode.enterPartner(in: AppGroup.defaults)
            }
            if let mode = AppClock.launchOptions.seedAppMode {
                AppMode.save(mode, to: AppGroup.defaults)
            }
        }
        #endif
        // Phase 12 spec §3.2: with partner mode hidden, someone who was following a
        // shared journey goes through onboarding again (nothing else is touched).
        if !showsPartnerUI, AppMode.hidePartnerMode(in: AppGroup.defaults) {
            logger.info("Stored partner mode hidden: onboarding again")
        }
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
        if isUITesting, arguments.contains("-seedActiveSession") {
            try seedActiveSession(into: kickStore)
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
        let weightStore = WeightStore(context: container.mainContext)
        #if DEBUG
        if isUITesting, AppClock.launchOptions.seedWeights {
            try seedWeights(into: weightStore)
        }
        #endif
        let weight = WeightCoordinator(store: weightStore, defaults: AppGroup.defaults, now: { AppClock.now() })
        let sharing = makeSharing()
        let partnerShare = PartnerShareCoordinator(sharing: sharing, defaults: AppGroup.defaults)
        // The real clock, not AppClock: the publisher waits 5 s on it.
        let partnerPublisher = PartnerPublisher(
            sharing: sharing,
            isActive: { [weak partnerShare] in partnerShare?.isSharing ?? false },
            defaults: AppGroup.defaults
        )
        return AppEnvironment(
            container: container,
            coordinator: coordinator,
            appointments: appointments,
            cycle: cycle,
            weight: weight,
            content: WeeklyContentLibrary.loadBundled(),
            knowledge: KnowledgeLibrary.loadBundled(),
            sharing: sharing,
            partnerShare: partnerShare,
            partnerPublisher: partnerPublisher,
            partnerJourney: PartnerJourneyModel(sharing: sharing, defaults: AppGroup.defaults)
        )
    }

    /// CloudKit when `AppFeatures.cloudSync` is on, `DisabledPartnerSharing` (never
    /// touches CloudKit) while it is off. UI tests: the fake in the state the launch
    /// arguments ask for (not shared when they ask for none), so no test touches iCloud.
    private static func makeSharing() -> any PartnerSharing {
        #if DEBUG
        if isUITesting {
            let options = AppClock.launchOptions
            if let partner = options.partner {
                let sample = PartnerSnapshot.uiTestSample(now: AppClock.now(), language: ContentLanguage.current)
                return FakePartnerSharing(partner: partner, snapshot: sample)
            }
            return FakePartnerSharing(mother: options.sharing ?? .notShared)
        }
        #endif
        guard AppFeatures.cloudSync else { return DisabledPartnerSharing() }
        return CloudPartnerSharing()
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

    /// `-uiTesting -seedWeights`: the design's pre-pregnancy weight (52 kg), height
    /// (160 cm) and weights at weeks 12–30 of the seeded pregnancy (`-seedDueDate`),
    /// up to the pinned today.
    private static func seedWeights(into store: WeightStore) throws {
        try WeightSeed.profile.save(to: AppGroup.defaults)
        guard let dueDate = PregnancyProfile.load(from: AppGroup.defaults).dueDate else { return }
        let now = AppClock.now()
        for entry in WeightSeed.entries(dueDate: dueDate, today: now) {
            try store.save(entry, today: now)
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

    /// `-uiTesting -seedActiveSession` (App Store screenshots): a session started
    /// 22 min ago on the real clock with 6 movements, well inside the 2-hour window.
    private static func seedActiveSession(into store: KickStore) throws {
        let start = Date().addingTimeInterval(-22 * 60)
        for minutes in [0.0, 3, 7, 11, 16, 20] {
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
