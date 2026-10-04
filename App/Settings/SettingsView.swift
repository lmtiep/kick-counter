import KickCore
import SwiftUI

struct SettingsView: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults) private var appMode = AppMode.pregnant.rawValue
    @AppStorage(SettingsKey.appLanguage, store: AppGroup.defaults) private var appLanguage = AppLanguage.system.rawValue
    @AppStorage(SettingsKey.reminderEnabled, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderHour, store: AppGroup.defaults) private var reminderHour = SettingsDefault.reminderHour
    @AppStorage(SettingsKey.reminderMinute, store: AppGroup.defaults) private var reminderMinute = SettingsDefault.reminderMinute
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @AppStorage(SettingsKey.lmpDate, store: AppGroup.defaults) private var lmpDate: Double = 0
    @AppStorage(SettingsKey.pregnancyDateSource, store: AppGroup.defaults)
    private var pregnancyDateSource = PregnancyDateSource.dueDate.rawValue

    @State private var notificationsAuthorized = true
    @State private var showingPregnancyDates = false
    @State private var confirmingClearPregnancy = false
    @State private var showingImPregnant = false

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.languageTitle) {
                    Picker(L10n.languageTitle, selection: $appLanguage) {
                        Text(L10n.languageSystem).tag(AppLanguage.system.rawValue)
                        Text(L10n.languageVietnamese).tag(AppLanguage.vi.rawValue)
                        Text(L10n.languageEnglish).tag(AppLanguage.en.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("profileLanguagePicker")
                }

                Section(L10n.settingsModeSection) {
                    Picker(L10n.settingsModeSection, selection: modeBinding) {
                        Text(L10n.modeTryingToConceive).tag(AppMode.tryingToConceive)
                        Text(L10n.modePregnant).tag(AppMode.pregnant)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settingsModePicker")
                }

                if mode == .tryingToConceive {
                    Section {
                        Stepper(
                            L10n.cycleSettingsCycleLength(cycle.settings.typicalCycleLength),
                            value: cycleLengthBinding,
                            in: CycleSettings.cycleLengthRange
                        )
                        .accessibilityIdentifier("settingsCycleLength")
                        Stepper(
                            L10n.cycleSettingsPeriodLength(cycle.settings.typicalPeriodLength),
                            value: periodLengthBinding,
                            in: CycleSettings.periodLengthRange
                        )
                        .accessibilityIdentifier("settingsPeriodLength")
                        Toggle(L10n.settingsCycleReminders, isOn: cycleRemindersBinding)
                            .accessibilityIdentifier("settingsCycleReminders")
                    } header: {
                        Text(L10n.settingsCycleSection)
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.cycleSettingsHint)
                            Text(L10n.settingsCycleRemindersHint)
                        }
                    }
                }

                // The kick-count reminder belongs to pregnancy mode, but stays
                // visible while it is on so it can always be turned off.
                if mode == .pregnant || reminderEnabled {
                    Section(L10n.settingsReminderSection) {
                        Toggle(L10n.settingsReminderToggle, isOn: $reminderEnabled)
                            .accessibilityIdentifier("settingsReminderToggle")
                        if reminderEnabled {
                            DatePicker(L10n.settingsReminderTime, selection: reminderTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }

                if mode == .pregnant {
                    Section(L10n.settingsPregnancySection) {
                        Button {
                            showingPregnancyDates = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent(dueDate > 0 ? L10n.settingsDueDate : L10n.settingsPregnancySet, value: dueDateText)
                                if let lmpText {
                                    Text(L10n.settingsPregnancyFromLMP(lmpText))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                        .accessibilityIdentifier("settingsPregnancyDates")

                        if dueDate > 0 {
                            Button(L10n.settingsPregnancyClear, role: .destructive) {
                                confirmingClearPregnancy = true
                            }
                            .accessibilityIdentifier("settingsPregnancyClear")
                        }
                    }
                }

                let showsLiveActivityHint = mode == .pregnant && !coordinator.liveActivitiesAvailable
                if !notificationsAuthorized || showsLiveActivityHint {
                    Section(L10n.settingsPermissionsSection) {
                        if !notificationsAuthorized {
                            Text(mode == .tryingToConceive ? L10n.cycleNotificationsOff : L10n.settingsNotificationsDenied)
                                .font(.footnote)
                        }
                        if showsLiveActivityHint {
                            Text(L10n.settingsLiveActivitiesOff).font(.footnote)
                        }
                        Button(L10n.settingsOpenSettings) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }

                Section(L10n.settingsAboutSection) {
                    NavigationLink(L10n.settingsMedicalInfo) { MedicalInfoView() }
                        .accessibilityIdentifier("settingsMedicalInfo")
                    LabeledContent(L10n.settingsVersion, value: appVersion)
                }
            }
            .navigationTitle(L10n.profileTitle)
            .sheet(isPresented: $showingPregnancyDates) { PregnancyDateSheet() }
            .sheet(isPresented: $showingImPregnant) {
                ImPregnantSheet(lastPeriodStart: cycle.forecast?.currentPeriodStart)
            }
            .confirmationDialog(
                L10n.settingsPregnancyClearConfirm,
                isPresented: $confirmingClearPregnancy,
                titleVisibility: .visible
            ) {
                Button(L10n.settingsPregnancyClear, role: .destructive) { PregnancyProfile.clear(AppGroup.defaults) }
                Button(L10n.commonCancel, role: .cancel) {}
            }
            .task { await refreshPermissions() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPermissions() } }
            }
            .onChange(of: reminderEnabled) { Task { await applyReminder() } }
            .onChange(of: reminderHour) { Task { await applyReminder() } }
            .onChange(of: reminderMinute) { Task { await applyReminder() } }
        }
    }

    /// Switching to "Trying to conceive" is immediate; switching to "Pregnant"
    /// goes through the "I'm pregnant" sheet so the due date is set.
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { mode },
            set: { newMode in
                guard newMode != mode else { return }
                switch newMode {
                case .tryingToConceive:
                    Task {
                        await cycle.activateTryingToConceive()
                        await refreshPermissions()
                    }
                case .pregnant:
                    showingImPregnant = true
                }
            }
        )
    }

    private var cycleLengthBinding: Binding<Int> {
        Binding(
            get: { cycle.settings.typicalCycleLength },
            set: { days in
                let current = cycle.settings
                saveCycleSettings(CycleSettings(
                    typicalCycleLength: days,
                    typicalPeriodLength: current.typicalPeriodLength,
                    remindersEnabled: current.remindersEnabled
                ))
            }
        )
    }

    private var periodLengthBinding: Binding<Int> {
        Binding(
            get: { cycle.settings.typicalPeriodLength },
            set: { days in
                let current = cycle.settings
                saveCycleSettings(CycleSettings(
                    typicalCycleLength: current.typicalCycleLength,
                    typicalPeriodLength: days,
                    remindersEnabled: current.remindersEnabled
                ))
            }
        )
    }

    private var cycleRemindersBinding: Binding<Bool> {
        Binding(
            get: { cycle.settings.remindersEnabled },
            set: { enabled in
                var settings = cycle.settings
                settings.remindersEnabled = enabled
                saveCycleSettings(settings)
            }
        )
    }

    /// Saved through the coordinator, which reschedules the cycle reminders.
    /// (CycleSettings lengths are set only through its clamping init.)
    private func saveCycleSettings(_ settings: CycleSettings) {
        Task {
            await cycle.updateSettings(settings)
            await refreshPermissions()
        }
    }

    private var dueDateText: String {
        guard dueDate > 0 else { return L10n.settingsPregnancyNotSet }
        return Date(timeIntervalSince1970: dueDate).formatted(date: .long, time: .omitted)
    }

    private var lmpText: String? {
        guard pregnancyDateSource == PregnancyDateSource.lmp.rawValue, lmpDate > 0 else { return nil }
        return Date(timeIntervalSince1970: lmpDate).formatted(date: .long, time: .omitted)
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderHour = components.hour ?? SettingsDefault.reminderHour
                reminderMinute = components.minute ?? SettingsDefault.reminderMinute
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func applyReminder() async {
        let scheduled = await coordinator.setDailyReminder(
            enabled: reminderEnabled,
            hour: reminderHour,
            minute: reminderMinute,
            text: ReminderTexts.daily
        )
        if !scheduled {
            reminderEnabled = false
        }
        await refreshPermissions()
    }

    private func refreshPermissions() async {
        notificationsAuthorized = await coordinator.notificationsAuthorized()
    }
}
