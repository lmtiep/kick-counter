import ActivityKit
import KickCore
import KickData
import OSLog
import SwiftData
import SwiftUI
@preconcurrency import UserNotifications

private let profileLogger = Logger(subsystem: "com.lmtiep.kickcounter", category: "profile")

/// The three choices of Profile's goal picker (phase 9 spec §4.3): the two
/// cycle goals and pregnancy, as in onboarding.
enum ProfileModeChoice: Hashable {
    case tracking
    case conceiving
    case pregnant
}

/// The Profile tab (spec §4.8), replacing Settings: language, goal (and ending
/// the pregnancy), pregnancy dates or cycle numbers, kick reminder, check-ups,
/// permissions, medical information, privacy policy and support, replaying the
/// introduction, version, and deleting all data (phase 12).
struct ProfileView: View {
    /// Shows onboarding in replay mode (RootView): nothing is saved from it.
    let onReplayOnboarding: () -> Void

    @Environment(KickCoordinator.self) private var coordinator
    @Environment(CycleCoordinator.self) private var cycle
    @Environment(WeightCoordinator.self) private var weight
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @AppStorage(SettingsKey.appMode, store: AppGroup.defaults) private var appMode = AppMode.pregnant.rawValue
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
    @State private var confirmingDeleteAll = false
    @State private var deletingAll = false
    @State private var deleteAllFailed = false

    private var mode: AppMode { AppMode(rawValue: appMode) ?? .pregnant }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    LanguagePickerCard()
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
                        // Partner sharing needs iCloud, off in 1.0 (phase 12).
                        if AppEnvironment.showsPartnerUI {
                            PartnerShareCard()
                        }
                    }
                    permissionsCard
                    aboutCard
                    deleteAllCard
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
            .alert(L10n.settingsDeleteAllTitle, isPresented: $confirmingDeleteAll) {
                Button(L10n.settingsDeleteAllConfirm, role: .destructive) {
                    Task { await deleteAllData() }
                }
                .accessibilityIdentifier("deleteAllConfirm")
                Button(L10n.commonCancel, role: .cancel) {}
                    .accessibilityIdentifier("deleteAllCancel")
            } message: {
                Text(L10n.settingsDeleteAllMessage)
            }
            .alert(L10n.settingsDeleteAllFailed, isPresented: $deleteAllFailed) {
                Button(L10n.commonOK) {}
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

    /// "Goal": track my cycle · trying to conceive · pregnant (phase 9).
    private var modeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.profileGoal)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                // UISegmentedControl ignores Dynamic Type and would clip the
                // Vietnamese labels at AX sizes, so the goal becomes a
                // vertical list of full-width rows there instead.
                if dynamicTypeSize.isAccessibilitySize {
                    goalList
                } else {
                    Picker(L10n.profileGoal, selection: modeBinding) {
                        Text(L10n.modeTracking).tag(ProfileModeChoice.tracking)
                        Text(L10n.modeTryingToConceive).tag(ProfileModeChoice.conceiving)
                        Text(L10n.modePregnantShort).tag(ProfileModeChoice.pregnant)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settingsModePicker")
                }
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

    /// The goal picker at accessibility Dynamic Type sizes (phase 9 fix round 1):
    /// a vertical list of full-width rows instead of the segmented control.
    private var goalList: some View {
        VStack(spacing: 10) {
            goalRow(L10n.modeTracking, choice: .tracking, identifier: "settingsGoal-tracking")
            goalRow(L10n.modeTryingToConceive, choice: .conceiving, identifier: "settingsGoal-conceiving")
            goalRow(L10n.modePregnantShort, choice: .pregnant, identifier: "settingsGoal-pregnant")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsModePicker")
    }

    private func goalRow(_ title: String, choice: ProfileModeChoice, identifier: String) -> some View {
        let isSelected = modeBinding.wrappedValue == choice
        return Button {
            modeBinding.wrappedValue = choice
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.luna(.cycleStrong))
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(.luna(.surfaceAlt), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.luna(.cycleStrong) : Color.clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
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
                Text(cycle.policy.reminderKinds.contains(.fertile)
                     ? L10n.settingsCycleRemindersHint
                     : L10n.settingsCycleRemindersHintTracking)
                    .accessibilityIdentifier("settingsCycleRemindersHint")
            }
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
            if cycle.preferences.goal == .tracking {
                trackingRows
            }
        }
        .font(.luna(.body))
        .foregroundStyle(.luna(.textPrimary))
        .lunaCard()
    }

    /// Tracking only (phase 9 spec §4.3): the contraception and the LH/BBT override.
    @ViewBuilder
    private var trackingRows: some View {
        LunaDivider()
        // At accessibility sizes the label sits above the menu instead of
        // beside it, so the menu's value is never squeezed to nothing.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.profileContraception)
                    .accessibilityHidden(true)
                contraceptionPicker
            }
        } else {
            HStack(spacing: 8) {
                Text(L10n.profileContraception)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                contraceptionPicker
            }
        }
        Toggle(L10n.profileShowFertilityTests, isOn: fertilityTestsBinding)
            .tint(.luna(.cycleStrong))
            .accessibilityIdentifier("profileShowFertilityTests")
            .accessibilityHint(L10n.profileShowFertilityTestsHint)
        Text(L10n.profileShowFertilityTestsHint)
            .font(.luna(.caption))
            .foregroundStyle(.luna(.textSecondary))
            .accessibilityHidden(true)
    }

    /// A menu whose label is the full current value, wrapped over as many lines as
    /// it needs (phase 9 final fix): a `.menu` Picker squeezes its value to one
    /// truncated line at accessibility sizes ("chữ T" for the copper IUD).
    private var contraceptionPicker: some View {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        return Menu {
            Picker(selection: contraceptionBinding) {
                Text(L10n.profileContraceptionNotSet).tag(Contraception?.none)
                ForEach(Contraception.allCases, id: \.self) { value in
                    Text(L10n.contraception(value)).tag(Contraception?.some(value))
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.inline)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(contraceptionText)
                    .multilineTextAlignment(isAccessibilitySize ? .leading : .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.luna(.caption))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.luna(.cycleOnSoft))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.profileContraception)
        .accessibilityValue(contraceptionText)
        .accessibilityIdentifier("profileContraception")
    }

    private var contraceptionText: String {
        cycle.preferences.contraception.map(L10n.contraception) ?? L10n.profileContraceptionNotSet
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
            externalLinkRow(L10n.settingsPrivacyPolicy, url: AppLinks.privacyPolicy, identifier: "profilePrivacyPolicy")
            LunaDivider()
            externalLinkRow(L10n.settingsSupport, url: AppLinks.support, identifier: "profileSupport")
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

    /// A row that opens a web page in Safari: the `arrow.up.right` accessory instead
    /// of the chevron, and a hint saying where it goes.
    private func externalLinkRow(_ title: String, url: URL, identifier: String) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.settingsOpensInSafari)
        .accessibilityIdentifier(identifier)
    }

    /// The last card (phase 12 spec §3.4): a destructive row, confirmed by an alert.
    private var deleteAllCard: some View {
        Button(role: .destructive) {
            confirmingDeleteAll = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.luna(.body))
                    .accessibilityHidden(true)
                Text(L10n.settingsDeleteAll)
                    .font(.luna(.body))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if deletingAll {
                    ProgressView()
                }
            }
            .foregroundStyle(.luna(.warningText))
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(deletingAll)
        .accessibilityIdentifier("profileDeleteAllData")
        .lunaCard(padding: 0)
    }

    /// "Xoá toàn bộ dữ liệu" (phase 12 spec §3.4). The store goes first: if it cannot
    /// be emptied, nothing else is touched (the deletions are rolled back) and an alert
    /// says so. Then the app's own preferences, its notifications and Live Activities;
    /// the coordinators reload, and RootView shows onboarding (`hasCompletedOnboarding`
    /// is gone). Only the app's store, its `AppDataReset.ownedKeys` and its own
    /// notifications and activities are deleted.
    private func deleteAllData() async {
        guard !deletingAll else { return }
        deletingAll = true
        defer { deletingAll = false }
        do {
            try DataReset.deleteAll(in: modelContext.container)
        } catch {
            profileLogger.error("Deleting all data failed: \(error.localizedDescription)")
            deleteAllFailed = true
            return
        }
        AppDataReset.clearDefaults(AppGroup.defaults)
        // The daily reminder, the 2-hour alerts and every kick Live Activity.
        await coordinator.silenceForPartnerMode()
        if !AppEnvironment.isUITesting {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            for activity in Activity<KickActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        await coordinator.load()
        await appointments.load()
        await cycle.load()
        await weight.load()
        profileLogger.info("Deleted all data")
    }

    // MARK: - Bindings

    /// "Pregnant" goes through the "I'm pregnant" sheet so the due date is
    /// set. Switching between the two cycle goals while already in cycle
    /// mode just changes the preference (`updatePreferences`), never
    /// prompting for notifications; leaving pregnancy for either goal takes
    /// `activateCycleMode(goal:)`, which switches the mode and so makes
    /// RootView stop partner sharing.
    private var modeBinding: Binding<ProfileModeChoice> {
        Binding(
            get: {
                guard mode == .tryingToConceive else { return .pregnant }
                return cycle.preferences.goal == .tracking ? .tracking : .conceiving
            },
            set: { choice in
                switch choice {
                case .tracking, .conceiving:
                    let goal: CycleGoal = choice == .tracking ? .tracking : .conceiving
                    guard mode != .tryingToConceive || goal != cycle.preferences.goal else { return }
                    Task {
                        if mode == .tryingToConceive {
                            var preferences = cycle.preferences
                            preferences.goal = goal
                            await cycle.updatePreferences(preferences)
                        } else {
                            await cycle.activateCycleMode(goal: goal)
                        }
                        await refreshPermissions()
                    }
                case .pregnant:
                    guard mode != .pregnant else { return }
                    showingImPregnant = true
                }
            }
        )
    }

    private var contraceptionBinding: Binding<Contraception?> {
        Binding(
            get: { cycle.preferences.contraception },
            set: { value in
                var preferences = cycle.preferences
                preferences.contraception = value
                Task { await cycle.updatePreferences(preferences) }
            }
        )
    }

    private var fertilityTestsBinding: Binding<Bool> {
        Binding(
            get: { cycle.preferences.showsFertilityTests },
            set: { shows in
                var preferences = cycle.preferences
                preferences.showsFertilityTests = shows
                Task { await cycle.updatePreferences(preferences) }
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

/// The language picker of both Profile tabs (spec §2.2).
struct LanguagePickerCard: View {
    @AppStorage(SettingsKey.appLanguage, store: AppGroup.defaults) private var appLanguage = AppLanguage.system.rawValue

    var body: some View {
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
