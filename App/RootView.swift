import KickCore
import SwiftUI

enum AppTab: Hashable {
    case pregnancy
    case counter
    case history
    case settings
    case cycle
    case calendar
}

struct RootView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.hasCompletedOnboarding, store: AppGroup.defaults)
    private var hasCompletedOnboarding = false
    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults)
    private var appMode = AppMode.pregnant.rawValue
    @State private var selectedTab: AppTab

    init() {
        _selectedTab = State(initialValue: Self.homeTab(for: AppMode.load(from: AppGroup.defaults)))
    }

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        Group {
            switch mode {
            case .tryingToConceive: cycleTabs
            case .pregnant: pregnancyTabs
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { hasCompletedOnboarding = !$0 }
        )) {
            OnboardingView { hasCompletedOnboarding = true }
        }
        .task { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
        .onChange(of: appMode) {
            // Settings stays open after switching mode there; anywhere else
            // (e.g. "I'm pregnant" on the Cycle tab) lands on the new home tab.
            if selectedTab != .settings { selectedTab = Self.homeTab(for: mode) }
        }
    }

    /// Pregnancy mode (phases 1–2): Pregnancy · Count · History · Settings.
    private var pregnancyTabs: some View {
        TabView(selection: $selectedTab) {
            PregnancyHomeView { selectedTab = .counter }
                .tabItem { Label(L10n.tabPregnancy, systemImage: "heart.text.square.fill") }
                .tag(AppTab.pregnancy)
            CounterView()
                .tabItem { Label(L10n.tabCounter, systemImage: "hand.tap.fill") }
                .tag(AppTab.counter)
            HistoryView()
                .tabItem { Label(L10n.tabHistory, systemImage: "chart.bar.fill") }
                .tag(AppTab.history)
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }

    /// Trying-to-conceive mode: Cycle · Calendar · Settings.
    private var cycleTabs: some View {
        TabView(selection: $selectedTab) {
            CycleHomeView()
                .tabItem { Label(L10n.tabCycle, systemImage: "drop.circle.fill") }
                .tag(AppTab.cycle)
            CycleCalendarView()
                .tabItem { Label(L10n.tabCalendar, systemImage: "calendar") }
                .tag(AppTab.calendar)
            SettingsView()
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }

    static func homeTab(for mode: AppMode) -> AppTab {
        mode == .tryingToConceive ? .cycle : .pregnancy
    }

    private func reload() async {
        await coordinator.load()
        await appointments.load()
        await cycle.load()
    }
}
