import Foundation
import KickCore
import SwiftData

/// SwiftData-backed AppointmentRepository. Storage only: reminders are kept in
/// step by `AppointmentCoordinator`.
@MainActor
public final class AppointmentStore: AppointmentRepository {
    private let context: ModelContext
    private let calendar: Calendar
    private let saveContext: @MainActor (ModelContext) throws -> Void

    public convenience init(context: ModelContext, calendar: Calendar = .current) {
        self.init(context: context, calendar: calendar, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests: SwiftData offers no reliable way to
    /// make a real save fail (see commit 59dd6a1).
    init(context: ModelContext, calendar: Calendar, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.calendar = calendar
        self.saveContext = saveContext
    }

    public func appointment(id: UUID) throws -> AppointmentRecord? {
        try model(id: id)?.record
    }

    public func upcoming(now: Date) throws -> [AppointmentRecord] {
        AppointmentRules.upcoming(try allRecords(), now: now, calendar: calendar)
    }

    public func past(now: Date) throws -> [AppointmentRecord] {
        AppointmentRules.past(try allRecords(), now: now, calendar: calendar)
    }

    public func add(_ appointment: AppointmentRecord) throws {
        context.insert(Appointment(record: appointment))
        try save()
    }

    public func update(_ appointment: AppointmentRecord) throws {
        guard let model = try model(id: appointment.id) else { throw AppointmentRepositoryError.notFound }
        model.apply(appointment)
        try save()
    }

    public func delete(id: UUID) throws {
        guard let model = try model(id: id) else { return }
        // Its questions go with it, in the same save (1.1).
        try ChecklistItem.deleteQuestions(appointmentID: id, in: context)
        context.delete(model)
        try save()
    }

    public func markDone(id: UUID) throws -> AppointmentRecord? {
        guard let model = try model(id: id) else { return nil }
        model.isDone = true
        try save()
        return model.record
    }

    private func allRecords() throws -> [AppointmentRecord] {
        try context.fetch(FetchDescriptor<Appointment>(sortBy: [SortDescriptor(\.date)])).map(\.record)
    }

    private func model(id: UUID) throws -> Appointment? {
        var descriptor = FetchDescriptor<Appointment>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Saves, rolling back on failure so a failed write leaves no half-applied change.
    private func save() throws {
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
