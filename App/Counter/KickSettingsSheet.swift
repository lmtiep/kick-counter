import KickCore
import SwiftUI

/// "Kick counter settings" (spec §4.6): daily reminder and its time, vibrate on
/// tap, and the fixed goal of 10 (Cardiff). Opened from Kicks and from Profile.
struct KickSettingsSheet: View {
    @Environment(KickCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.reminderEnabled, store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderHour, store: AppGroup.defaults) private var reminderHour = SettingsDefault.reminderHour
    @AppStorage(SettingsKey.reminderMinute, store: AppGroup.defaults) private var reminderMinute = SettingsDefault.reminderMinute
    @AppStorage(SettingsKey.kickHapticsEnabled, store: AppGroup.defaults) private var hapticsEnabled = true

    var body: some View {
        LunaSheet(title: L10n.kickSettingsTitle) {
            VStack(spacing: 0) {
                toggleRow(
                    title: L10n.settingsReminderSection,
                    detail: L10n.kickSettingsReminderDetail,
                    isOn: $reminderEnabled,
                    identifier: "kickSettingsReminderToggle"
                )
                if reminderEnabled {
                    DatePicker(L10n.settingsReminderTime, selection: reminderTime, displayedComponents: .hourAndMinute)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.textPrimary))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .accessibilityIdentifier("kickSettingsReminderTime")
                }
                LunaDivider()
                toggleRow(
                    title: L10n.kickSettingsHaptics,
                    detail: L10n.kickSettingsHapticsDetail,
                    isOn: $hapticsEnabled,
                    identifier: "kickSettingsHapticsToggle"
                )
                LunaDivider()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.kickSettingsGoal)
                            .font(.luna(.cardTitleSmall))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.kicksCardiffTitle)
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(SessionRules.targetCount, format: .number)
                        .font(.luna(.figure))
                        .foregroundStyle(.luna(.textPrimary))
                }
                .padding(16)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("kickSettingsGoal")
            }
            .lunaCard(padding: 0)
            .padding(.top, 16)
            Button(L10n.completionDone) { dismiss() }
                .buttonStyle(.pill(.dark))
                .padding(.top, 18)
                .accessibilityIdentifier("kickSettingsDone")
        }
        .onChange(of: reminderEnabled) { Task { await applyReminder() } }
        .onChange(of: reminderHour) { Task { await applyReminder() } }
        .onChange(of: reminderMinute) { Task { await applyReminder() } }
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>, identifier: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.luna(.cardTitleSmall))
                    .foregroundStyle(.luna(.textPrimary))
                Text(detail)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.luna(.preg))
        .padding(16)
        .accessibilityIdentifier(identifier)
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderHour = components.hour ?? SettingsDefault.reminderHour
                reminderMinute = components.minute ?? SettingsDefault.reminderMinute
            }
        )
    }

    /// Schedules or cancels the daily reminder; turns the switch back off when
    /// it can't be scheduled (usually: notifications denied).
    private func applyReminder() async {
        let scheduled = await coordinator.setDailyReminder(
            enabled: reminderEnabled,
            hour: reminderHour,
            minute: reminderMinute,
            text: ReminderTexts.daily
        )
        if !scheduled { reminderEnabled = false }
    }
}
