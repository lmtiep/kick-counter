import KickCore
import SwiftUI

enum AppTab: Hashable {
    case today
    case calendar
    case kicks
    case profile
}

/// Three tabs per mode (spec §2.3). Trying to conceive: Today · Calendar ·
/// Profile. Pregnant: Today · Kicks (with History inside) · Profile.
struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
    @Environment(PartnerInvitationInbox.self) private var invitations
    @Environment(\.partnerSharing) private var sharing
    @Environment(\.scenePhase) private var scenePhase
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

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

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
                get: { !hasCompletedOnboarding || replayingOnboarding },
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
            }
            .task { await reload() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await reload() } }
            }
            .onChange(of: appMode) {
                // Profile stays open after switching mode there; anywhere else
                // (e.g. "I'm pregnant" on Today) lands on the new mode's Today.
                if selectedTab != .profile { selectedTab = .today }
            }
            .onChange(of: appLanguage) {
                Task { await relocalizeReminders() }
            }
            // An iCloud invitation opened from Messages or Mail (phase 8 spec §5.2).
            // Not `.task(id:)`: taking the invitation changes the id, which would
            // cancel the acceptance in flight.
            .onChange(of: invitations.pending?.id, initial: true) {
                guard let invitation = invitations.take() else { return }
                Task { await accept(invitation) }
            }
            .alert(L10n.partnerAcceptFailedTitle, isPresented: $invitationFailed) {
                Button(L10n.commonOK) {}
            } message: {
                Text(L10n.partnerAcceptFailedBody)
            }
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
            case .pregnant, .partner:
                PregnancyTodayView(
                    onOpenKicks: { selectedTab = .kicks },
                    onOpenProfile: { selectedTab = .profile }
                )
                .lunaTab(L10n.tabToday, systemImage: "sun.max.fill", tag: .today)
                KicksView()
                    .lunaTab(L10n.tabKicks, systemImage: "hand.tap.fill", tag: .kicks)
            }
            ProfileView(onReplayOnboarding: { replayingOnboarding = true })
                .lunaTab(L10n.tabProfile, systemImage: "person.crop.circle.fill", tag: .profile)
        }
        // Active tab: cycleStrong / pregnancy (pregOnSoft: pregStrong fails AA at 11 pt).
        .tint(mode == .tryingToConceive ? Color.luna(.cycleStrong) : Color.luna(.pregOnSoft))
    }

    private func accept(_ invitation: PartnerInvitation) async {
        switch await PartnerAcceptance.accept(invitation, sharing: sharing, defaults: AppGroup.defaults) {
        case .accepted:
            selectedTab = .today
        case .ignoredOwnInvitation:
            break
        case .failed:
            invitationFailed = true
        }
    }

    private func reload() async {
        await coordinator.load()
        await appointments.load()
        await cycle.load()
        await weight.load()
    }

    /// The language changed: every pending reminder is scheduled again in it
    /// (2-hour alert, cycle reminders, check-up reminders, daily kick reminder).
    private func relocalizeReminders() async {
        await coordinator.updateOverdueText(ReminderTexts.overdue)
        await cycle.updateReminderTexts(ReminderTexts.cycle)
        await appointments.updateReminderText(ReminderTexts.appointment)
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
