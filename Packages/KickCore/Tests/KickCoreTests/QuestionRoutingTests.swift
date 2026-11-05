import Foundation
import Testing
@testable import KickCore

/// Quick-add routing (1.1 spec): a question goes to the next upcoming appointment, or stays unassigned.
struct QuestionRoutingTests {
    let now = date("2026-10-02T12:00:00Z")

    private func appointment(_ iso: String, isDone: Bool = false) -> AppointmentRecord {
        AppointmentRecord(date: date(iso), title: iso, isDone: isDone)
    }

    private func question(_ text: String, appointmentID: UUID?) -> ChecklistItemRecord {
        ChecklistItemRecord(kind: .question, text: text, appointmentID: appointmentID, createdAt: now)
    }

    @Test func routesToTheNextUpcomingAppointment() {
        let later = appointment("2026-11-01T08:00:00Z")
        let soon = appointment("2026-10-05T08:00:00Z")
        #expect(QuestionRouting.target(among: [later, soon], now: now, calendar: utcCalendar) == soon.id)
    }

    @Test func todaysAppointmentStillCounts() {
        let today = appointment("2026-10-02T08:00:00Z")
        #expect(QuestionRouting.target(among: [today], now: now, calendar: utcCalendar) == today.id)
    }

    @Test func skipsDoneAndPastAppointments() {
        let past = appointment("2026-09-20T08:00:00Z")
        let done = appointment("2026-10-10T08:00:00Z", isDone: true)
        let later = appointment("2026-11-01T08:00:00Z")
        #expect(QuestionRouting.target(among: [past, done, later], now: now, calendar: utcCalendar) == later.id)
    }

    @Test func noAppointmentMeansUnassigned() {
        #expect(QuestionRouting.target(among: [], now: now, calendar: utcCalendar) == nil)
        let past = appointment("2026-09-20T08:00:00Z")
        #expect(QuestionRouting.target(among: [past], now: now, calendar: utcCalendar) == nil)
    }

    @Test func aNewUpcomingAppointmentCanAdopt() {
        #expect(QuestionRouting.canAdopt(appointment("2026-10-20T08:00:00Z"), now: now, calendar: utcCalendar))
    }

    @Test func aPastOrDoneAppointmentCannotAdopt() {
        #expect(QuestionRouting.canAdopt(appointment("2026-09-20T08:00:00Z"), now: now, calendar: utcCalendar) == false)
        #expect(QuestionRouting.canAdopt(appointment("2026-10-20T08:00:00Z", isDone: true), now: now, calendar: utcCalendar) == false)
    }

    @Test func questionsAreFilteredPerAppointmentAndUnassigned() {
        let a = UUID(), b = UUID()
        let items = [
            question("1", appointmentID: a), question("2", appointmentID: b), question("3", appointmentID: nil),
            ChecklistItemRecord(kind: .bag, group: .mother, text: "Gối", createdAt: now),
        ]
        #expect(QuestionRouting.questions(for: a, in: items).map(\.text) == ["1"])
        #expect(QuestionRouting.unassigned(in: items).map(\.text) == ["3"])
    }

    @Test func questionsKeepTheOrderTheyWereAsked() {
        let a = UUID()
        let items = [
            ChecklistItemRecord(kind: .question, text: "B", order: 2, appointmentID: a, createdAt: now),
            ChecklistItemRecord(kind: .question, text: "A", order: 1, appointmentID: a, createdAt: now),
        ]
        #expect(QuestionRouting.questions(for: a, in: items).map(\.text) == ["A", "B"])
    }

    @Test func progressCountsAskedQuestions() {
        let a = UUID()
        let items = [
            ChecklistItemRecord(kind: .question, text: "A", isDone: true, appointmentID: a, createdAt: now),
            ChecklistItemRecord(kind: .question, text: "B", appointmentID: a, createdAt: now),
        ]
        let progress = QuestionRouting.progress(QuestionRouting.questions(for: a, in: items))
        #expect(progress.done == 1)
        #expect(progress.total == 2)
    }
}
