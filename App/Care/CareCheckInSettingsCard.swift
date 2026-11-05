import KickCore
import SwiftUI

/// Profile → "Hỏi thăm" (1.1 item 4, spec §4.5), while a pregnancy has ended:
/// the check-ins on or off, and the one optional, neutral notification. Only
/// turning the notification on may ask for permission (her explicit choice).
struct CareCheckInSettingsCard: View {
    @State private var state = CareCheckInState.load(from: AppGroup.defaults)
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.careProfileTitle)
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
            Toggle(isOn: enabledBinding) {
                Text(L10n.careProfileEnabled)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
            }
            .tint(.luna(.cycleStrong))
            .accessibilityIdentifier("careEnabledToggle")
            Toggle(isOn: notifyBinding) {
                Text(L10n.careProfileNotify)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textPrimary))
            }
            .tint(.luna(.cycleStrong))
            .disabled(!isOn || working)
            .accessibilityIdentifier("careNotifyToggle")
            Text(L10n.careProfileNote)
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .lunaCard()
        .onAppear { state = CareCheckInState.load(from: AppGroup.defaults) }
    }

    /// On while she has not switched them off nor said "Cảm ơn, mình ổn rồi".
    private var isOn: Bool { state.enabled && !state.stopped }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { on in
                state.enabled = on
                if on { state.stopped = false }
                save()
                Task { await CareCheckInNotifications.sync() }
            }
        )
    }

    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { isOn && state.notify },
            set: { on in
                state.notify = on
                save()
                Task {
                    working = true
                    defer { working = false }
                    // Turning it on is her explicit action: it may ask for permission.
                    if !(await CareCheckInNotifications.sync(mayPrompt: on)) {
                        state.notify = false
                        save()
                    }
                }
            }
        )
    }

    private func save() {
        state.save(to: AppGroup.defaults)
    }
}
