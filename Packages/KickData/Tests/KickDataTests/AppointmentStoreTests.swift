import Foundation
import KickCore
import SwiftData
import Testing
@testable import KickData

@MainActor
struct AppointmentStoreTests {
    struct SaveFailed: Error {}

    let now = date("2026-10-02T12:00:00Z")
    let container: ModelContainer
    let store: AppointmentStore

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        store = AppointmentStore(context: container.mainContext, calendar: utcCalendar)
    }

    /// A store on the same context whose saves always fail.
    private func failingStore() -> AppointmentStore {
        AppointmentStore(context: container.mainContext, calendar: utcCalendar, saveContext: { _ in throw SaveFailed() })
    }

    private func record(_ iso: String, title: String = "Check-up", isDone: Bool = false, milestoneID: String? = nil) -> AppointmentRecord {
        AppointmentRecord(date: date(iso), title: title, note: "Note", isDone: isDone, milestoneID: milestoneID)
    }

    @Test func schemaIncludesAppointment() {
        #expect(KickPersistence.schema.entities.map(\.name).contains("Appointment"))
    }

    @Test func addedAppointmentRoundTrips() throws {
        let added = record("2026-10-20T09:00:00Z", title: "Glucose test", milestoneID: "gdm-screening")
        try store.add(added)
        #expect(try store.appointment(id: added.id) == added)
        #expect(try store.upcoming(now: now) == [added])
        #expect(try store.past(now: now).isEmpty)
    }

    @Test func upcomingAndPastAreSplitAndSorted() throws {
        let later = record("2026-11-01T09:00:00Z")
        let soon = record("2026-10-05T09:00:00Z")
        let earlierToday = record("2026-10-02T08:00:00Z")
        let lastWeek = record("2026-09-25T09:00:00Z")
        let done = record("2026-10-10T09:00:00Z", isDone: true)
        for appointment in [later, lastWeek, done, soon, earlierToday] { try store.add(appointment) }
        #expect(try store.upcoming(now: now) == [earlierToday, soon, later])
        #expect(try store.past(now: now) == [done, lastWeek])
    }

    @Test func updateChangesEveryField() throws {
        var appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        appointment.date = date("2026-10-21T10:30:00Z")
        appointment.title = "Anomaly scan"
        appointment.note = "Full bladder"
        appointment.milestoneID = "anomaly-scan"
        try store.update(appointment)
        #expect(try store.appointment(id: appointment.id) == appointment)
    }

    @Test func updatingAnUnknownAppointmentThrowsNotFound() {
        #expect(throws: AppointmentRepositoryError.notFound) {
            try store.update(record("2026-10-20T09:00:00Z"))
        }
    }

    @Test func deleteRemovesAndUnknownIDIsANoOp() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        try store.delete(id: appointment.id)
        #expect(try store.appointment(id: appointment.id) == nil)
        try store.delete(id: UUID())
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Appointment>()) == 0)
    }

    @Test func markDoneMovesToPast() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        let done = try store.markDone(id: appointment.id)
        #expect(done?.isDone == true)
        #expect(try store.upcoming(now: now).isEmpty)
        #expect(try store.past(now: now).map(\.id) == [appointment.id])
        #expect(try store.markDone(id: UUID()) == nil)
    }

    @Test func failedAddRollsBack() throws {
        #expect(throws: SaveFailed.self) {
            try failingStore().add(record("2026-10-20T09:00:00Z"))
        }
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Appointment>()) == 0)
    }

    @Test func failedUpdateRollsBack() throws {
        var appointment = record("2026-10-20T09:00:00Z", title: "Original")
        try store.add(appointment)
        appointment.title = "Changed"
        #expect(throws: SaveFailed.self) {
            try failingStore().update(appointment)
        }
        #expect(try store.appointment(id: appointment.id)?.title == "Original")
    }

    @Test func failedDeleteRollsBack() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        #expect(throws: SaveFailed.self) {
            try failingStore().delete(id: appointment.id)
        }
        #expect(try store.appointment(id: appointment.id) == appointment)
    }

    @Test func failedMarkDoneRollsBack() throws {
        let appointment = record("2026-10-20T09:00:00Z")
        try store.add(appointment)
        #expect(throws: SaveFailed.self) {
            _ = try failingStore().markDone(id: appointment.id)
        }
        #expect(try store.appointment(id: appointment.id)?.isDone == false)
    }
}

@MainActor
struct AppointmentQuestionsCascadeTests {
    let container: ModelContainer
    let appointments: AppointmentStore
    let checklist: ChecklistStore
    let now = date("2026-11-06T08:00:00Z")

    init() throws {
        container = try KickPersistence.makeContainer(inMemory: true)
        appointments = AppointmentStore(context: container.mainContext, calendar: utcCalendar)
        checklist = ChecklistStore(context: container.mainContext)
    }

    @Test func deletingAnAppointmentDeletesItsQuestionsOnly() throws {
        let doomed = AppointmentRecord(date: date("2026-11-20T09:00:00Z"), title: "Khám 32 tuần")
        let kept = AppointmentRecord(date: date("2026-12-04T09:00:00Z"), title: "Khám 34 tuần")
        try appointments.add(doomed)
        try appointments.add(kept)
        _ = try checklist.addQuestion("Của lần bị xoá 1", appointmentID: doomed.id, now: now)
        _ = try checklist.addQuestion("Của lần bị xoá 2", appointmentID: doomed.id, now: now)
        _ = try checklist.addQuestion("Của lần giữ lại", appointmentID: kept.id, now: now)
        _ = try checklist.addQuestion("Chưa gán", appointmentID: nil, now: now)
        _ = try checklist.addBagItem("Gối", group: .mother, now: now)
        try checklist.setBuiltInDone("cccd", done: true, now: now)

        try appointments.delete(id: doomed.id)

        let items = try checklist.items()
        #expect(items.filter { $0.kind == .question }.map(\.text).sorted() == ["Chưa gán", "Của lần giữ lại"])
        #expect(items.filter { $0.kind == .bag }.count == 2, "bag rows are untouched")
        #expect(try appointments.appointment(id: doomed.id) == nil)
    }

    @Test func aFailedDeleteKeepsTheAppointmentAndItsQuestions() throws {
        let record = AppointmentRecord(date: date("2026-11-20T09:00:00Z"), title: "Khám")
        try appointments.add(record)
        _ = try checklist.addQuestion("Hỏi", appointmentID: record.id, now: now)
        struct Boom: Error {}
        let failing = AppointmentStore(context: container.mainContext, calendar: utcCalendar, saveContext: { _ in throw Boom() })
        #expect(throws: Boom.self) { try failing.delete(id: record.id) }
        #expect(try appointments.appointment(id: record.id) != nil)
        #expect(try checklist.items().count == 1)
    }
}
