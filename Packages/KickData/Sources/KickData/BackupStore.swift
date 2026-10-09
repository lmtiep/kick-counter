import Foundation
import KickCore
import SwiftData

/// The store half of a backup (phase 15): reading every record for export, and
/// replacing every record on restore, all or nothing.
public enum BackupStore {
    @MainActor
    public static func export(from container: ModelContainer) throws -> BackupRecords {
        let context = container.mainContext
        return BackupRecords(
            sessions: try context.fetch(FetchDescriptor<KickSession>(sortBy: [SortDescriptor(\.startedAt)])).map(\.record),
            appointments: try context.fetch(FetchDescriptor<Appointment>(sortBy: [SortDescriptor(\.date)])).map(\.record),
            periods: try context.fetch(FetchDescriptor<PeriodEntry>(sortBy: [SortDescriptor(\.startDate)])).map(\.record),
            logs: try context.fetch(FetchDescriptor<CycleLog>(sortBy: [SortDescriptor(\.day)])).map(\.record),
            weights: try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.day)])).map(\.record)
        )
    }

    /// Deletes every model and inserts `records` in the main context, then saves once.
    /// If anything throws (including the save), the context is rolled back and the
    /// error rethrown, so the store keeps exactly its old data. `save` exists so tests
    /// can inject a failing save.
    @MainActor
    public static func replaceAll(
        in container: ModelContainer,
        with records: BackupRecords,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        let context = container.mainContext
        do {
            try deleteEvery(Kick.self, in: context)
            try deleteEvery(KickSession.self, in: context)
            try deleteEvery(Appointment.self, in: context)
            try deleteEvery(PeriodEntry.self, in: context)
            try deleteEvery(CycleLog.self, in: context)
            try deleteEvery(WeightEntry.self, in: context)
            for record in records.sessions {
                insert(record, into: context)
            }
            for record in records.appointments {
                context.insert(Appointment(record: record))
            }
            for record in records.periods {
                context.insert(PeriodEntry(record: record))
            }
            for record in records.logs {
                context.insert(CycleLog(record: record))
            }
            for record in records.weights {
                context.insert(WeightEntry(record: record))
            }
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private static func insert(_ record: SessionRecord, into context: ModelContext) {
        let session = KickSession(id: record.id, startedAt: record.state.startedAt)
        session.endedAt = record.state.endedAt
        session.status = record.state.status
        session.exceededThreshold = record.state.exceededThreshold
        context.insert(session)
        for timestamp in record.state.kicks {
            let kick = Kick(timestamp: timestamp)
            context.insert(kick)
            kick.session = session
        }
    }

    @MainActor
    private static func deleteEvery<Model: PersistentModel>(_: Model.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<Model>()) {
            context.delete(model)
        }
    }
}
