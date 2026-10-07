import Foundation
import Testing
@testable import KickCore

/// Phase 8 spec §3.2: what the builder keeps, and what it never reads.
struct PartnerSnapshotBuilderTests {
    let now = date("2026-10-02T12:00:00Z")

    private func make(
        appointments: [AppointmentRecord] = [],
        sessions: [SessionState] = []
    ) -> PartnerSnapshot {
        PartnerSnapshotBuilder.make(
            dueDate: date("2027-01-19T15:30:00Z"),
            appointments: appointments,
            sessions: sessions,
            displayName: "Mẹ",
            now: now,
            calendar: utcCalendar
        )
    }

    private func completed(_ start: String, minutes: Double, kicks: Int = 10) -> SessionState {
        let startedAt = date(start)
        return SessionState(
            startedAt: startedAt,
            kicks: (0..<kicks).map { startedAt.addingTimeInterval(Double($0) * 30) },
            status: .completed,
            endedAt: startedAt.addingTimeInterval(minutes * 60)
        )
    }

    @Test func copiesTheNameAndTheStartOfTheDueDay() {
        let snapshot = make()
        #expect(snapshot.version == PartnerSnapshot.currentVersion)
        #expect(snapshot.updatedAt == now)
        #expect(snapshot.displayName == "Mẹ")
        #expect(snapshot.dueDate == date("2027-01-19T00:00:00Z"))
        #expect(snapshot.appointments.isEmpty)
        #expect(snapshot.kicks == .empty)
    }

    @Test func keepsOnlyUpcomingAppointmentsSoonestFirstAtMostFive() {
        let days = [9, 3, 1, 7, 5, 11]
        let future = days.map { AppointmentRecord(date: now.addingTimeInterval(Double($0) * 86_400), title: "Day \($0)") }
        let past = AppointmentRecord(date: now.addingTimeInterval(-3_600), title: "Earlier today")
        let done = AppointmentRecord(date: now.addingTimeInterval(2 * 86_400), title: "Done", isDone: true)
        let snapshot = make(appointments: future + [past, done])
        #expect(snapshot.appointments.map(\.title) == ["Day 1", "Day 3", "Day 5", "Day 7", "Day 9"])
    }

    @Test func neverCopiesTheNote() throws {
        let record = AppointmentRecord(date: now.addingTimeInterval(86_400), title: "Khám thai", note: "private note")
        let snapshot = make(appointments: [record])
        #expect(snapshot.appointments == [PartnerAppointment(title: "Khám thai", date: record.date, location: nil)])
        let json = String(decoding: try snapshot.encoded(), as: UTF8.self)
        #expect(!json.contains("private note"))
    }

    @Test func countsOnlyCompletedSessions() {
        let active = SessionState(startedAt: date("2026-10-02T11:00:00Z"), kicks: [date("2026-10-02T11:00:00Z")])
        let cancelled = SessionState(
            startedAt: date("2026-10-02T10:00:00Z"), kicks: [], status: .cancelled, endedAt: date("2026-10-02T10:30:00Z")
        )
        let done = completed("2026-10-01T20:00:00Z", minutes: 18)
        let snapshot = make(sessions: [active, cancelled, done])
        #expect(snapshot.kicks.lastSession == PartnerKickSession(startedAt: date("2026-10-01T20:00:00Z"), kicks: 10, durationMinutes: 18))
        #expect(snapshot.kicks.sessionsLast7Days == 1)
        #expect(snapshot.kicks.averageMinutesLast7Days == 18)
    }

    @Test func theSevenDayWindowGivesTheCountAndTheMean() {
        let sessions = [
            completed("2026-10-02T08:00:00Z", minutes: 20),
            completed("2026-09-28T08:00:00Z", minutes: 30),
            completed("2026-09-25T12:00:00Z", minutes: 10), // exactly 7 days before now: inside
            completed("2026-09-25T11:59:00Z", minutes: 50), // just outside
        ]
        let snapshot = make(sessions: sessions)
        #expect(snapshot.kicks.sessionsLast7Days == 3)
        #expect(snapshot.kicks.averageMinutesLast7Days == 20)
        #expect(snapshot.kicks.lastSession?.startedAt == date("2026-10-02T08:00:00Z"))
        #expect(snapshot.kicks.lastSession?.durationMinutes == 20)
    }

    @Test func anOldSessionIsTheLastSessionButNotInTheWindow() {
        let snapshot = make(sessions: [completed("2026-09-01T08:00:00Z", minutes: 25, kicks: 10)])
        #expect(snapshot.kicks.lastSession?.startedAt == date("2026-09-01T08:00:00Z"))
        #expect(snapshot.kicks.sessionsLast7Days == 0)
        #expect(snapshot.kicks.averageMinutesLast7Days == nil)
    }
}
