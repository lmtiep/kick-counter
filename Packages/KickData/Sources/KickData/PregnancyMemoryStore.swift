import Foundation
import KickCore
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "memories")

/// Pregnancy memories (1.1 item 4), and the archive that ends a pregnancy's
/// raw data: the memory is written and the raw rows are deleted in ONE save.
/// If anything throws, the context is rolled back and the error rethrown, so
/// nothing is deleted and no memory is left half-made (spec §4.3).
/// The raw rows of a pregnancy, read for the memory.
public struct PregnancyRows: Sendable {
    public var sessions: [SessionRecord]
    public var contractions: [ContractionRecord]
    public var appointments: [AppointmentRecord]
    public var weights: [WeightRecord]
    public var logs: [CycleLogRecord]
}

@MainActor
public final class PregnancyMemoryStore {
    private let context: ModelContext
    private let saveContext: @MainActor (ModelContext) throws -> Void

    public convenience init(context: ModelContext) {
        self.init(context: context, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests, as in `ContractionStore`.
    init(context: ModelContext, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.saveContext = saveContext
    }

    /// Newest first. A memory whose payload cannot be read is left out (and logged).
    public func all() throws -> [PregnancyMemoryRecord] {
        let models = try context.fetch(FetchDescriptor<PregnancyMemory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        return models.compactMap { model in
            guard let record = model.record else {
                logger.error("A pregnancy memory could not be read")
                return nil
            }
            return record
        }
    }

    /// Trims the title. Unknown ids are a no-op.
    public func rename(id: UUID, title: String) throws {
        guard let model = try model(id: id) else { return }
        model.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try save()
    }

    /// Unknown ids are a no-op.
    public func delete(id: UUID) throws {
        guard let model = try model(id: id) else { return }
        context.delete(model)
        try save()
    }

    /// Inserts the memory (when given) and deletes exactly the given raw rows (the
    /// pregnancy's in-range kick sessions with their kicks, contractions,
    /// appointments and weights). Day logs and periods are never touched. One
    /// save; on any throw everything is rolled back. A new pregnancy model adds
    /// its ID set to `PregnancyRawRowIDs` and one `delete` call here.
    public func archive(
        memory: PregnancyMemoryContent?,
        title: String,
        deleting rows: PregnancyRawRowIDs,
        now: Date = Date()
    ) throws {
        do {
            if let memory {
                let record = PregnancyMemoryRecord(
                    createdAt: now, title: title.trimmingCharacters(in: .whitespacesAndNewlines), content: memory
                )
                context.insert(try PregnancyMemory(record: record))
            }
            // Kicks first: a session's cascade would delete them anyway.
            for kick in try context.fetch(FetchDescriptor<Kick>()) where kick.session.map({ rows.sessions.contains($0.id) }) ?? false {
                context.delete(kick)
            }
            try delete(KickSession.self, ids: rows.sessions, id: \.id)
            try delete(Contraction.self, ids: rows.contractions, id: \.id)
            try delete(Appointment.self, ids: rows.appointments, id: \.id)
            try delete(WeightEntry.self, ids: rows.weights, id: \.id)
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func delete<Model: PersistentModel>(_: Model.Type, ids: Set<UUID>, id: KeyPath<Model, UUID>) throws {
        guard !ids.isEmpty else { return }
        for model in try context.fetch(FetchDescriptor<Model>()) where ids.contains(model[keyPath: id]) {
            context.delete(model)
        }
    }

    /// Every raw row a memory is built from (`PregnancyMemoryBuilder.make`).
    public func pregnancyRows() throws -> PregnancyRows {
        PregnancyRows(
            sessions: try context.fetch(FetchDescriptor<KickSession>(sortBy: [SortDescriptor(\.startedAt)])).map(\.record),
            contractions: try context.fetch(FetchDescriptor<Contraction>(sortBy: [SortDescriptor(\.startedAt)])).map(\.record),
            appointments: try context.fetch(FetchDescriptor<Appointment>(sortBy: [SortDescriptor(\.date)])).map(\.record),
            weights: try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.day)])).map(\.record),
            logs: try context.fetch(FetchDescriptor<CycleLog>(sortBy: [SortDescriptor(\.day)])).map(\.record)
        )
    }

    private func model(id: UUID) throws -> PregnancyMemory? {
        try context.fetch(FetchDescriptor<PregnancyMemory>()).first { $0.id == id }
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
