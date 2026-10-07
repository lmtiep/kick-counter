import KickCore
import KickData
import SwiftData
import SwiftUI

/// Feeds `PartnerPublisher` (phase 8 spec §5.1) in pregnancy mode: a new
/// snapshot whenever an appointment, a completed kick session or the due date
/// changes, and "became active" whenever the app does. Draws nothing.
struct PartnerPublishObserver: View {
    @Environment(AppointmentCoordinator.self) private var appointments
    @Environment(\.partnerPublisher) private var publisher
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.dueDate, store: AppGroup.defaults) private var dueDate: Double = 0
    @Query(
        filter: #Predicate<KickSession> { $0.statusRaw == "completed" },
        sort: \KickSession.startedAt,
        order: .reverse
    )
    private var sessions: [KickSession]

    /// Everything the snapshot is built from.
    private struct Inputs: Equatable {
        let dueDate: Double
        let appointments: [AppointmentRecord]
        let sessions: [SessionState]
    }

    private var inputs: Inputs {
        Inputs(dueDate: dueDate, appointments: appointments.upcoming, sessions: sessions.map(\.state))
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: inputs, initial: true) { _, inputs in
                publisher?.update(snapshot(from: inputs))
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { publisher?.noteBecameActive() }
            }
    }

    /// Notes, symptoms and weight are not inputs of the builder.
    private func snapshot(from inputs: Inputs) -> PartnerSnapshot? {
        guard inputs.dueDate > 0 else { return nil }
        return PartnerSnapshotBuilder.make(
            dueDate: Date(timeIntervalSince1970: inputs.dueDate),
            appointments: inputs.appointments,
            sessions: inputs.sessions,
            displayName: L10n.partnerDefaultName,
            now: AppClock.now()
        )
    }
}
