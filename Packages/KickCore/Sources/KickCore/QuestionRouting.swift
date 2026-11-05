import Foundation

/// Questions for the doctor (1.1 spec): where a quick-added question goes, and which
/// questions belong to which appointment.
public enum QuestionRouting {
    /// The soonest upcoming appointment (today counts until marked done), or nil: the
    /// question then stays unassigned until an appointment adopts it.
    public static func target(among appointments: [AppointmentRecord], now: Date, calendar: Calendar = .current) -> UUID? {
        AppointmentRules.upcoming(appointments, now: now, calendar: calendar).first?.id
    }

    /// Whether a newly saved appointment takes over the unassigned questions.
    public static func canAdopt(_ appointment: AppointmentRecord, now: Date, calendar: Calendar = .current) -> Bool {
        AppointmentRules.isUpcoming(appointment, now: now, calendar: calendar)
    }

    public static func questions(for appointmentID: UUID, in items: [ChecklistItemRecord]) -> [ChecklistItemRecord] {
        ordered(items.filter { $0.kind == .question && $0.appointmentID == appointmentID })
    }

    public static func unassigned(in items: [ChecklistItemRecord]) -> [ChecklistItemRecord] {
        ordered(items.filter { $0.kind == .question && $0.appointmentID == nil })
    }

    public static func progress(_ questions: [ChecklistItemRecord]) -> ChecklistProgress {
        ChecklistProgress(done: questions.filter(\.isDone).count, total: questions.count)
    }

    private static func ordered(_ items: [ChecklistItemRecord]) -> [ChecklistItemRecord] {
        items.sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }
}
