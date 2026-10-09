import KickCore
import SwiftUI

enum AppTab: Hashable {
    case today
    case calendar
    case kicks
    case knowledge
    case profile
}

/// Three tabs per mode (spec §2.3). Trying to conceive: Today · Calendar ·
/// Profile. Pregnant: Today · Kicks (with History inside) · Profile. Partner
/// (phase 8): Today · Knowledge · Profile, with no kick counter.
struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
    @Environment(PartnerShareCoordinator.self) private var partnerShare
    @Environment(PartnerJourneyModel.self) private var partnerJourney
    @Environment(PartnerInvitationInbox.self) private var invitations
    @Environment(BackupCenter.self) private var backup
    @Environment(\.partnerSharing) private var sharing
    @Environment(\.partnerPublisher) private var publisher
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults)
    private var appMode = AppMode.pregnant.rawValue
    @AppStorage(SettingsKey.appLanguage, store: AppGroup.defaults)
    private var appLanguage = AppLanguage.system.rawValue
    @State private var selectedTab = AppTab.today
    /// Profile → "Replay the introduction": onboarding without saving anything.
    @State private var replayingOnboarding = false
    @State private var invitationFailed = false
    /// "Đã khôi phục dữ liệu" after a restore (phase 15).
    @State private var toastMessage: String?
    #if DEBUG
    /// `-uiTestingRestoreOnReactivate`: the app went to the background since launch.
    @State private var wasInBackground = false
    #endif

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }
    private var showsOnboarding: Bool { !hasCompletedOnboarding || replayingOnboarding }

    var body: some View {
        tabs
            // A new language rebuilds every screen with the new strings (spec §2.2).
            // The selected tab lives here, outside the rebuilt part, so Profile stays open.
            .id(appLanguage)
            .environment(\.locale, AppLocale.locale)
            // DatePickers and other system calendars follow the app language too.
            .environment(\.calendar, AppLocale.calendar)
            // Outside the language-rebuilt part, so a replay survives a language change.
            .fullScreenCover(isPresented: Binding(
                get: { showsOnboarding },
                set: { shown in
                    guard !shown else { return }
                    hasCompletedOnboarding = true
                    replayingOnboarding = false
                }
            )) {
                OnboardingView(replay: replayingOnboarding && hasCompletedOnboarding) {
                    hasCompletedOnboarding = true
                    replayingOnboarding = false
                }
                    .environment(\.locale, AppLocale.locale)
                    .environment(\.calendar, AppLocale.calendar)
                    // A fresh install opening an invitation is still onboarding:
                    // a failure is shown over the cover, where it can be seen.
                    .partnerAcceptFailedAlert(isPresented: acceptFailedBinding(whileOnboarding: true))
            }
            // While she shares, the mother's changes reach the partner (phase 8).
            .background {
                if mode == .pregnant, AppEnvironment.showsPartnerUI { PartnerPublishObserver() }
            }
            .task { await reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await reload() } }
            }
            .onChange(of: appMode) { oldMode, newMode in
                // Profile stays open after switching mode there; anywhere else
                // (e.g. "I'm pregnant" on Today) lands on the new mode's Today.
                if selectedTab != .profile { selectedTab = .today }
                // Ending pregnancy tracking or switching to trying to conceive
                // (Profile, onboarding, any other path) stops the share: the
                // partner must not keep seeing the last snapshot. Accepting an
                // invitation (partner mode) keeps it.
                if AppEnvironment.showsPartnerUI,
                   AppMode(rawValue: oldMode) == .pregnant, AppMode(rawValue: newMode) == .tryingToConceive {
                    Task { await partnerShare.stopSharingAfterLeavingPregnancy(publisher: publisher) }
                }
            }
            // Onboarding reset (Profile → "Delete all data", or a hidden partner mode):
            // a fresh start lands on Today, not on the Profile tab it was left on.
            .onChange(of: hasCompletedOnboarding) { _, completed in
                if !completed { selectedTab = .today }
            }
            .onChange(of: appLanguage) {
                Task { await relocalizeReminders() }
            }
            // An iCloud invitation opened from Messages or Mail (phase 8 spec §5.2).
            // Not `.task(id:)`: taking the invitation changes the id, which would
            // cancel the acceptance in flight.
            .onChange(of: invitations.pending?.id, initial: true) {
                guard let invitation = invitations.take() else { return }
                // Partner mode hidden (phase 12): an invitation is dropped.
                guard AppEnvironment.showsPartnerUI else { return }
                Task { await accept(invitation) }
            }
            .partnerAcceptFailedAlert(isPresented: acceptFailedBinding(whileOnboarding: false))
            .toast($toastMessage)
            // A `.lunamom` file opened from Files, AirDrop or a chat app (phase 15).
            .onOpenURL { url in
                guard BackupCenter.isBackupFile(url) else { return }
                backup.open(url)
            }
            // Over whatever is on top (a sheet, onboarding), never blocked by it.
            .onChange(of: backup.request?.id) {
                if let request = backup.request {
                    let overOnboarding = showsOnboarding
                    Task {
                        await RestoreBackupPresenter.shared.present(
                            restoreSheet(request, overOnboarding: overOnboarding),
                            style: overOnboarding ? .light : AppEnvironment.forceDarkMode ? .dark : .unspecified
                        ) { backup.request = nil }
                    }
                } else {
                    RestoreBackupPresenter.shared.dismiss()
                }
            }
            .onChange(of: backup.restoreCount) {
                // A file opened while replaying the introduction ends the replay too.
                replayingOnboarding = false
                selectedTab = .today
                toastMessage = L10n.backupRestored
            }
            #if DEBUG
            .task {
                let options = AppClock.launchOptions
                if let file = options.restoreFile, !options.restoresFileOnReactivate { backup.openUITestFile(file) }
            }
            .onChange(of: scenePhase) { _, phase in
                let options = AppClock.launchOptions
                guard let file = options.restoreFile, options.restoresFileOnReactivate else { return }
                if phase == .background { wasInBackground = true }
                if phase == .active, wasInBackground { backup.openUITestFile(file) }
            }
            #endif
    }

    /// The restore sheet with what it needs from the environment: it is hosted by
    /// `RestoreBackupPresenter`, outside this view's hierarchy. Over onboarding
    /// it is light, as onboarding is (phase 18).
    private func restoreSheet(_ request: BackupCenter.Request, overOnboarding: Bool) -> AnyView {
        AnyView(
            RestoreBackupSheet(request: request)
                .environment(backup)
                .environment(coordinator)
                .environment(appointments)
                .environment(cycle)
                .environment(weight)
                .modelContext(modelContext)
                .environment(\.locale, AppLocale.locale)
                .environment(\.calendar, AppLocale.calendar)
                .preferredColorScheme(overOnboarding ? .light : AppEnvironment.forceDarkMode ? .dark : nil)
        )
    }

    /// The acceptance-failure alert is presented by whichever view is on top:
    /// the onboarding cover while it shows, the tabs otherwise.
    private func acceptFailedBinding(whileOnboarding: Bool) -> Binding<Bool> {
        Binding(
            get: { invitationFailed && showsOnboarding == whileOnboarding },
            set: { if !$0 { invitationFailed = false } }
        )
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            switch mode {
            case .tryingToConceive:
                CycleTodayView(
                    onOpenProfile: { selectedTab = .profile },
                    onOpenCalendar: { selectedTab = .calendar }
                )
                .lunaTab(L10n.tabToday, systemImage: "sun.max.fill", tag: .today)
                CycleCalendarView()
                    .lunaTab(L10n.tabCalendar, systemImage: "calendar", tag: .calendar)
            case .pregnant:
                PregnancyTodayView(
                    onOpenKicks: { selectedTab = .kicks },
                    onOpenProfile: { selectedTab = .profile }
                )
                .lunaTab(L10n.tabToday, systemImage: "sun.max.fill", tag: .today)
                KicksView()
                    .lunaTab(L10n.tabKicks, systemImage: "hand.tap.fill", tag: .kicks)
            case .partner:
                PartnerTodayView(onLeave: leavePartnerMode)
                    .lunaTab(L10n.tabToday, systemImage: "sun.max.fill", tag: .today)
                let trimester = partnerJourney.trimester(now: AppClock.now())
                NavigationStack {
                    KnowledgeLibraryView(initialTrimester: trimester)
                }
                // The library keeps its first trimester: start again once the
                // shared due date arrives or the trimester changes. Transient
                // states (an error, no iCloud) keep the last known trimester.
                .id(trimester)
                .lunaTab(L10n.knowledgeTitle, systemImage: "book.fill", tag: .knowledge)
            }
            if mode == .partner {
                PartnerProfileView(onLeave: leavePartnerMode)
                    .lunaTab(L10n.tabProfile, systemImage: "person.crop.circle.fill", tag: .profile)
            } else {
                ProfileView(onReplayOnboarding: { replayingOnboarding = true })
                    .lunaTab(L10n.tabProfile, systemImage: "person.crop.circle.fill", tag: .profile)
            }
        }
        // Active tab (pregnancy: pregStrong fails AA at 11 pt, so the darker pregOnSoft value).
        .tint(mode == .tryingToConceive ? Color.luna(.tabSelectedCycle) : Color.luna(.tabSelectedPreg))
    }

    private func accept(_ invitation: PartnerInvitation) async {
        switch await PartnerAcceptance.accept(invitation, sharing: sharing, defaults: AppGroup.defaults) {
        case .accepted:
            selectedTab = .today
            // Partner mode now: the kick reminders and Live Activity stop.
            await coordinator.silenceForPartnerMode()
            // Already in partner mode (a new invitation): Today does not appear again.
            await partnerJourney.refresh()
        case .ignoredOwnInvitation:
            break
        case .failed:
            invitationFailed = true
        }
    }

    private func reload() async {
        if mode == .partner {
            // Not her pregnancy on this iPhone: no kick reminders or Live Activity.
            await coordinator.silenceForPartnerMode()
        } else {
            await coordinator.load()
        }
        await appointments.load()
        await cycle.load()
        await weight.load()
        // Partner sharing is off with iCloud (phase 12): nothing to refresh.
        guard AppEnvironment.showsPartnerUI else { return }
        switch mode {
        case .pregnant: await partnerShare.refresh()
        case .partner: await partnerJourney.refresh()
        // Finishes a stop that failed when pregnancy tracking ended (offline).
        case .tryingToConceive: await partnerShare.refreshOutsidePregnancy(publisher: publisher)
        }
    }

    /// Back to the mode before partner mode, on its Today.
    private func leavePartnerMode() {
        partnerJourney.leave()
        selectedTab = .today
        // What partner mode silenced comes back: the session's Live Activity and
        // 2-hour alert through `load()`, the daily reminder from its stored setting.
        Task {
            await coordinator.load()
            await restoreDailyKickReminder()
        }
    }

    /// The language changed: every pending reminder is scheduled again in it
    /// (2-hour alert, cycle reminders, check-up reminders, daily kick reminder).
    private func relocalizeReminders() async {
        if mode != .partner { await coordinator.updateOverdueText(ReminderTexts.overdue) }
        await cycle.updateReminderTexts(ReminderTexts.cycle)
        await appointments.updateReminderText(ReminderTexts.appointment)
        await restoreDailyKickReminder()
    }

    /// Schedules the stored daily kick reminder again, never prompting and
    /// never in partner mode.
    private func restoreDailyKickReminder() async {
        guard mode != .partner else { return }
        let reminder = DailyKickReminder.stored
        guard reminder.enabled else { return }
        // Enabling may prompt; a language change never should.
        guard await coordinator.notificationsAuthorized() else { return }
        _ = await DailyKickReminder.apply(reminder, with: coordinator)
    }
}

private extension View {
    func lunaTab(_ title: String, systemImage: String, tag: AppTab) -> some View {
        tabItem { Label(title, systemImage: systemImage) }
            .tag(tag)
            .toolbarBackground(Color.luna(.tabBar), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

private extension View {
    /// "Couldn't open the invitation" (phase 8 spec §5.2).
    func partnerAcceptFailedAlert(isPresented: Binding<Bool>) -> some View {
        alert(L10n.partnerAcceptFailedTitle, isPresented: isPresented) {
            Button(L10n.commonOK) {}
        } message: {
            Text(L10n.partnerAcceptFailedBody)
        }
    }
}
