import KickCore
import OSLog
import SwiftUI

/// The Profile tab (spec §4.8), replacing Settings: language, mode (and ending
/// the pregnancy), pregnancy dates or cycle numbers, kick reminder, check-ups,
/// permissions, medical information, replaying the introduction, version.
struct ProfileView: View {
    /// Shows onboarding in replay mode (RootView): nothing is saved from it.
    let onReplayOnboarding: () -> Void

    @Environment(KickCoordinator.self) private var coordinator
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
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
    @State private var showingEndPregnancy = false
    @State private var showingKickSettings = false
    @State private var showingMaternal = false

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    languageCard
                    modeCard
                    if mode == .pregnant {
                        pregnancyCard
                    } else {
                        cycleCard
                    }
                    // The kick reminder belongs to pregnancy mode, but stays
                    // reachable while it is on so it can always be turned off.
                    if mode == .pregnant || reminderEnabled {
                        Button { showingKickSettings = true } label: {
                            LunaRow(
                                title: L10n.profileKickReminder,
                                value: reminderEnabled
                                    ? Formatting.clockTime(hour: reminderHour, minute: reminderMinute)
                                    : L10n.profileReminderOff
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profileKickReminder")
                        .lunaCard(padding: 0)
                    }
                    if mode == .pregnant {
                        NavigationLink { AppointmentsView() } label: {
                            LunaRow(title: L10n.appointmentsTitle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profileAppointments")
                        .lunaCard(padding: 0)
                    }
                    permissionsCard
                    aboutCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            // Content scrolled up stays out from under the status bar.
            .lunaStatusBarBackdrop()
            .background(.luna(.background))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingPregnancyDates) { PregnancyDateSheet() }
            .sheet(isPresented: $showingMaternal) { MaternalProfileSheet() }
            .sheet(isPresented: $showingImPregnant) {
                ImPregnantSheet(lastPeriodStart: cycle.forecast?.currentPeriodStart)
            }
            .sheet(isPresented: $showingEndPregnancy) {
                EndPregnancySheet()
                    .lunaSheetPresentation(detents: [.medium])
            }
            // Turning the reminder on may have just asked for notifications.
            .sheet(isPresented: $showingKickSettings, onDismiss: { Task { await refreshPermissions() } }) {
                KickSettingsSheet()
                    .lunaSheetPresentation(detents: [.medium, .large])
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
        }
    }

    // MARK: - Cards

    private var header: some View {
        HStack(spacing: 14) {
            Text(verbatim: "L")
                .font(.luna(size: 22, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.luna(.avatarText))
                .frame(width: 60, height: 60)
                .background(Circle().fill(.luna(.avatar)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.appName)
                    .font(.luna(.sheetTitle))
                    .foregroundStyle(.luna(.textPrimary))
                Text(mode == .pregnant ? L10n.profileModePregnant : L10n.profileModeCycle)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .accessibilityIdentifier("profileModeName")
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.languageTitle)
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
            Picker(L10n.languageTitle, selection: $appLanguage) {
                Text(L10n.languageSystem).tag(AppLanguage.system.rawValue)
                Text(L10n.languageVietnamese).tag(AppLanguage.vi.rawValue)
                Text(L10n.languageEnglish).tag(AppLanguage.en.rawValue)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("profileLanguagePicker")
        }
        .lunaCard()
    }

    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.settingsModeSection)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                Picker(L10n.settingsModeSection, selection: modeBinding) {
                    Text(L10n.modeTryingToConceive).tag(AppMode.tryingToConceive)
                    Text(L10n.modePregnant).tag(AppMode.pregnant)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settingsModePicker")
            }
            .padding(18)
            LunaDivider()
            if mode == .pregnant {
                Button { showingEndPregnancy = true } label: {
                    LunaRow(title: L10n.profileEndPregnancy)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profileEndPregnancy")
            } else {
                Button { showingImPregnant = true } label: {
                    LunaRow(title: L10n.profileSwitchToPregnant)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profileSwitchToPregnant")
            }
        }
        .lunaCard(padding: 0)
    }

    private var pregnancyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { showingPregnancyDates = true } label: {
                VStack(alignment: .leading, spacing: 0) {
                    LunaRow(title: dueDate > 0 ? L10n.settingsDueDate : L10n.settingsPregnancySet, value: dueDateText)
                    if let lmpText {
                        Text(L10n.settingsPregnancyFromLMP(lmpText))
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 14)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settingsPregnancyDates")
            LunaDivider()
            Button { showingMaternal = true } label: {
                LunaRow(title: L10n.profileMaternal, value: maternalText)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profileMaternal")
            if dueDate > 0 {
                LunaDivider()
                Button(role: .destructive) {
                    confirmingClearPregnancy = true
                } label: {
                    Text(L10n.settingsPregnancyClear)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.warningText))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settingsPregnancyClear")
            }
        }
        .lunaCard(padding: 0)
    }

    /// "52.0 kg · 160 cm", "52.0 kg", or "Not set".
    private var maternalText: String {
        let parts = [weight.profile.preWeightKg.map { Formatting.kilograms($0) }, weight.profile.heightCm.map(Formatting.centimeters)]
            .compactMap { $0 }
        return parts.isEmpty ? L10n.profileMaternalNotSet : parts.joined(separator: " · ")
    }

    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.settingsCycleSection)
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
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
                .tint(.luna(.cycleStrong))
                .accessibilityIdentifier("settingsCycleReminders")
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.cycleSettingsHint)
                Text(L10n.settingsCycleRemindersHint)
            }
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
        }
        .font(.luna(.body))
        .foregroundStyle(.luna(.textPrimary))
        .lunaCard()
    }

    @ViewBuilder
    private var permissionsCard: some View {
        let showsLiveActivityHint = mode == .pregnant && !coordinator.liveActivitiesAvailable
        if !notificationsAuthorized || showsLiveActivityHint {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.settingsPermissionsSection)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                if !notificationsAuthorized {
                    Text(mode == .tryingToConceive ? L10n.cycleNotificationsOff : L10n.settingsNotificationsDenied)
                }
                if showsLiveActivityHint {
                    Text(L10n.settingsLiveActivitiesOff)
                }
                Button(L10n.settingsOpenSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.pill(.soft(.surfaceAlt, .textPrimary), fullWidth: false, height: 40))
            }
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
            .lunaCard()
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink { MedicalInfoView() } label: {
                LunaRow(title: L10n.settingsMedicalInfo)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settingsMedicalInfo")
            LunaDivider()
            Button(action: onReplayOnboarding) {
                LunaRow(title: L10n.profileReplayOnboarding)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profileReplayOnboarding")
            LunaDivider()
            NavigationLink { FontLicenseView() } label: {
                LunaRow(title: L10n.profileFontLicense)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profileFontLicense")
            LunaDivider()
            LunaRow(title: L10n.settingsVersion, value: appVersion, showsChevron: false)
                .accessibilityElement(children: .combine)
        }
        .lunaCard(padding: 0)
    }

    // MARK: - Bindings

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
                case .partner:
                    // The picker offers only the two modes of the mother.
                    break
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
    private func saveCycleSettings(_ settings: CycleSettings) {
        Task {
            await cycle.updateSettings(settings)
            await refreshPermissions()
        }
    }

    private var dueDateText: String {
        guard dueDate > 0 else { return L10n.settingsPregnancyNotSet }
        return Formatting.longDate(Date(timeIntervalSince1970: dueDate))
    }

    private var lmpText: String? {
        guard pregnancyDateSource == PregnancyDateSource.lmp.rawValue, lmpDate > 0 else { return nil }
        return Formatting.longDate(Date(timeIntervalSince1970: lmpDate))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func refreshPermissions() async {
        notificationsAuthorized = await coordinator.notificationsAuthorized()
    }
}

/// "End pregnancy tracking?" (spec §4.8): back to trying-to-conceive mode;
/// pregnancy data, check-ups and their reminders are kept.
struct EndPregnancySheet: View {
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(\.dismiss) private var dismiss
    @State private var working = false

    var body: some View {
        LunaSheet(title: L10n.endPregnancyTitle) {
            Text(L10n.endPregnancyBody)
                .font(.luna(.body))
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Button(L10n.endPregnancyConfirm) {
                Task {
                    working = true
                    await cycle.activateTryingToConceive()
                    working = false
                    dismiss()
                }
            }
            .buttonStyle(.pill(.dark))
            .disabled(working)
            .padding(.top, 20)
            .accessibilityIdentifier("endPregnancyConfirm")
            Button(L10n.commonNotNow) { dismiss() }
                .buttonStyle(.pill(.text(.textSecondary), height: 44))
                .padding(.top, 4)
                .accessibilityIdentifier("endPregnancyCancel")
        }
    }
}

private let licenseLogger = Logger(subsystem: "com.lmtiep.kickcounter", category: "font-license")

/// The SIL Open Font License of Be Vietnam Pro (`App/Fonts/OFL.txt`), spec §7.
struct FontLicenseView: View {
    private var license: String {
        guard let url = Bundle.main.url(forResource: "OFL", withExtension: "txt") else {
            licenseLogger.error("OFL.txt is missing from the app bundle")
            return ""
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            licenseLogger.error("Reading OFL.txt failed: \(error.localizedDescription)")
            return ""
        }
    }

    var body: some View {
        ScrollView {
            Text(verbatim: license)
                .font(.luna(.small))
                .foregroundStyle(.luna(.articleText))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .accessibilityIdentifier("fontLicenseText")
        }
        .background(.luna(.background))
        .navigationTitle(L10n.profileFontLicense)
        .navigationBarTitleDisplayMode(.inline)
    }
}
