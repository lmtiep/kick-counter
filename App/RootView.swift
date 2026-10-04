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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults)
    private var appMode = AppMode.pregnant.rawValue
    @AppStorage(SettingsKey.appLanguage, store: AppGroup.defaults)
    private var appLanguage = AppLanguage.system.rawValue
    @State private var selectedTab = AppTab.today

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        tabs
            // A new language rebuilds every screen with the new strings (spec §2.2).
            // The selected tab lives here, outside the rebuilt part, so Profile stays open.
            .id(appLanguage)
            .environment(\.locale, AppLocale.locale)
            .fullScreenCover(isPresented: Binding(
                get: { !hasCompletedOnboarding },
                set: { hasCompletedOnboarding = !$0 }
            )) {
                OnboardingView { hasCompletedOnboarding = true }
                    .environment(\.locale, AppLocale.locale)
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
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            switch mode {
            case .tryingToConceive:
                CycleHomeView()
                    .lunaTab(L10n.tabToday, systemImage: "sun.max.fill", tag: .today)
                CycleCalendarView()
                    .lunaTab(L10n.tabCalendar, systemImage: "calendar", tag: .calendar)
            case .pregnant:
                PregnancyHomeView { selectedTab = .kicks }
                    .lunaTab(L10n.tabToday, systemImage: "sun.max.fill", tag: .today)
                CounterView()
                    .lunaTab(L10n.tabKicks, systemImage: "hand.tap.fill", tag: .kicks)
            }
            SettingsView()
                .lunaTab(L10n.tabProfile, systemImage: "person.crop.circle.fill", tag: .profile)
        }
        // Active tab: cycleStrong / pregnancy (pregOnSoft: pregStrong fails AA at 11 pt).
        .tint(mode == .tryingToConceive ? Color.luna(.cycleStrong) : Color.luna(.pregOnSoft))
    }

    private func reload() async {
        await coordinator.load()
        await appointments.load()
        await cycle.load()
    }

    /// The language changed: every pending reminder is scheduled again in it
    /// (2-hour alert, cycle reminders, check-up reminders, daily kick reminder).
    private func relocalizeReminders() async {
        await coordinator.updateOverdueText(ReminderTexts.overdue)
        await cycle.updateReminderTexts(ReminderTexts.cycle)
        await appointments.updateReminderText(ReminderTexts.appointment)
        let defaults = AppGroup.defaults
        guard defaults.bool(forKey: SettingsKey.reminderEnabled) else { return }
        _ = await coordinator.setDailyReminder(
            enabled: true,
            hour: defaults.object(forKey: SettingsKey.reminderHour) as? Int ?? SettingsDefault.reminderHour,
            minute: defaults.object(forKey: SettingsKey.reminderMinute) as? Int ?? SettingsDefault.reminderMinute,
            text: ReminderTexts.daily
        )
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
