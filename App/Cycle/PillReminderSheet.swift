import KickCore
import SwiftUI

/// "Nhắc uống thuốc" (phase 17 spec §4.1), from Profile → Chu kỳ when the
/// contraception is the pill: the switch, the pack type, the first day of this
/// pack, the time, and the one missed-pill sentence (no clinical instructions).
/// Every change is stored and scheduled at once, like the kick reminder.
struct PillReminderSheet: View {
    @Environment(PillCoordinator.self) private var pill
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft = PillReminderSettings()
    @State private var loaded = false

    private var today: Date { Calendar.current.startOfDay(for: AppClock.now()) }

    /// The last 60 days, up to today (spec §4.1).
    private var startRange: ClosedRange<Date> {
        (Calendar.current.date(byAdding: .day, value: -60, to: today) ?? today)...today
    }

    var body: some View {
        LunaSheet(title: L10n.pillSheetTitle, titleIdentifier: "pillSheetTitle") {
            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: enabledBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.pillSheetToggle)
                            .font(.luna(.cardTitleSmall))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(L10n.pillSheetToggleDetail)
                            .font(.luna(.small))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(.luna(.cycleStrong))
                .padding(16)
                .accessibilityIdentifier("pillReminderToggle")
                LunaDivider()
                packTypeSection
                    .padding(16)
                LunaDivider()
                pickerRow(L10n.pillSheetPackStart, identifier: "pillPackStart") {
                    DatePicker(L10n.pillSheetPackStart, selection: startBinding, in: startRange, displayedComponents: .date)
                }
                LunaDivider()
                pickerRow(L10n.pillSheetTime, identifier: "pillReminderTime") {
                    DatePicker(L10n.pillSheetTime, selection: timeBinding, displayedComponents: .hourAndMinute)
                }
            }
            .lunaCard(padding: 0)
            .padding(.top, 16)
            if draft.enabled, pill.notificationsDenied {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.pillSheetNotificationsOff)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.settingsOpenSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.pill(.soft(.surfaceAlt, .textPrimary), fullWidth: false, height: 44))
                }
                .lunaCard()
                .padding(.top, 12)
                .accessibilityIdentifier("pillNotificationsOff")
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .accessibilityHidden(true)
                Text(L10n.pillSheetMissed)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 14)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pillMissedFootnote")
            Button(L10n.completionDone) { dismiss() }
                .buttonStyle(.pill(.dark))
                .padding(.top, 18)
                .accessibilityIdentifier("pillReminderDone")
        }
        .onAppear {
            guard !loaded else { return }
            draft = pill.settings
            loaded = true
        }
        .onChange(of: draft) { _, settings in
            guard loaded else { return }
            Task { await pill.update(settings) }
        }
    }

    // MARK: - Pack type

    private var packTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.pillSheetPackType)
                .font(.luna(.captionStrong))
                .foregroundStyle(.luna(.textSecondary))
                .accessibilityAddTraits(.isHeader)
            if dynamicTypeSize.isAccessibilitySize {
                // Two long segment titles do not fit side by side at these sizes.
                VStack(spacing: 0) {
                    ForEach(PillPackType.allCases, id: \.self) { type in
                        packTypeRow(type)
                    }
                }
            } else {
                SegmentedPill(options: PillPackType.allCases.map { type in
                    SegmentedOption(value: type, title: L10n.pillPack(type), identifier: identifier(for: type))
                }, selection: $draft.packType)
            }
            Text(L10n.pillPackDetail(draft.packType))
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pillPackTypeDetail")
        }
    }

    private func packTypeRow(_ type: PillPackType) -> some View {
        let isSelected = draft.packType == type
        return Button {
            draft.packType = type
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.luna(isSelected ? .cycleStrong : .chevron))
                    .accessibilityHidden(true)
                Text(L10n.pillPack(type))
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier(for: type))
    }

    private func identifier(for type: PillPackType) -> String {
        switch type {
        case .withBreak: "pillPackType21"
        case .continuous: "pillPackType28"
        }
    }

    // MARK: - Pickers

    /// A picker beside its label, or under it at accessibility sizes so neither
    /// is squeezed.
    @ViewBuilder
    private func pickerRow<Picker: View>(_ title: String, identifier: String, @ViewBuilder picker: () -> Picker) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .accessibilityHidden(true)
                    picker()
                        .labelsHidden()
                        .accessibilityLabel(title)
                        .accessibilityIdentifier(identifier)
                }
            } else {
                picker()
                    .accessibilityIdentifier(identifier)
            }
        }
        .font(.luna(.body))
        .foregroundStyle(.luna(.textPrimary))
        .tint(.luna(.cycleStrong))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
    }

    // MARK: - Bindings

    /// Turning it on without a pack start picks today, so it can remind at once.
    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { draft.enabled },
            set: { enabled in
                if enabled, draft.packStart == nil { draft.packStart = today }
                draft.enabled = enabled
            }
        )
    }

    private var startBinding: Binding<Date> {
        Binding(
            // Packs repeat every 28 days: show the first day of the current one.
            get: {
                guard let pack = draft.pack(calendar: .current) else { return today }
                let next = pack.nextPackStart(after: today)
                let current = Calendar.current.date(byAdding: .day, value: -PillPack.length, to: next) ?? pack.start
                return min(max(max(current, pack.start), startRange.lowerBound), today)
            },
            set: { draft.packStart = Calendar.current.startOfDay(for: $0) }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: draft.hour, minute: draft.minute)) ?? today },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.hour = parts.hour ?? PillReminderSettings.defaultHour
                draft.minute = parts.minute ?? PillReminderSettings.defaultMinute
            }
        )
    }
}
