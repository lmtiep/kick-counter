import Foundation

/// Builds the partner's snapshot from plain values (phase 8 spec §3.2). Its
/// parameters are the whole of what can be shared: notes, symptoms, weight and
/// cycle data are not inputs, so they cannot leak.
public enum PartnerSnapshotBuilder {
    public static let maxAppointments = 5
    public static let kickWindowDays = 7

    public static func make(
        dueDate: Date,
        appointments: [AppointmentRecord],
        sessions: [SessionState],
        displayName: String,
        now: Date,
        calendar: Calendar = .current
    ) -> PartnerSnapshot {
        PartnerSnapshot(
            updatedAt: now,
            displayName: displayName,
            dueDate: calendar.startOfDay(for: dueDate),
            appointments: upcoming(appointments, now: now),
            kicks: kickSummary(sessions, now: now, calendar: calendar)
        )
    }

    /// Not done and not yet started, soonest first, at most five. Only the
    /// title and the date are read; the note never is.
    static func upcoming(_ appointments: [AppointmentRecord], now: Date) -> [PartnerAppointment] {
        appointments
            .filter { !$0.isDone && $0.date >= now }
            .sorted { $0.date < $1.date }
            .prefix(maxAppointments)
            .map { PartnerAppointment(title: $0.title, date: $0.date) }
    }

    static func kickSummary(_ sessions: [SessionState], now: Date, calendar: Calendar) -> PartnerKickSummary {
        let completed: [(state: SessionState, minutes: Double)] = sessions.compactMap { session in
            guard session.status == .completed, let duration = session.duration else { return nil }
            return (session, duration / 60)
        }
        let last = completed.max { $0.state.startedAt < $1.state.startedAt }
        let windowStart = calendar.date(byAdding: .day, value: -kickWindowDays, to: now) ?? now
        let recent = completed.filter { $0.state.startedAt >= windowStart && $0.state.startedAt <= now }.map(\.minutes)
        return PartnerKickSummary(
            lastSession: last.map {
                PartnerKickSession(startedAt: $0.state.startedAt, kicks: $0.state.count, durationMinutes: $0.minutes)
            },
            sessionsLast7Days: recent.count,
            averageMinutesLast7Days: recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count)
        )
    }
}
