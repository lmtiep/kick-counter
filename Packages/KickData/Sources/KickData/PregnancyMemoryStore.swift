import Foundation
import KickCore
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "memories")

/// Pregnancy memories (1.1 item 4), and the archive that ends a pregnancy's
/// raw data: the memory is written and the raw rows are deleted in ONE save.
/// If anything throws, the context is rolled back and the error rethrown, so
/// nothing is deleted and no memory is left half-made (spec §4.3).
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

    /// Inserts the memory (when given) and deletes the raw rows: every kick
    /// session and its kicks, every contraction, and the appointments and
    /// weights with the given ids. Day logs and periods are never touched.
    /// One save; on any throw everything is rolled back.
    public func archive(
        memory: PregnancyMemoryContent?,
        title: String,
        deleteAllSessions: Bool,
        deleteAllContractions: Bool,
        appointmentIDs: Set<UUID>,
        weightIDs: Set<UUID>,
        now: Date = Date()
    ) throws {
        do {
            if let memory {
                let record = PregnancyMemoryRecord(
                    createdAt: now, title: title.trimmingCharacters(in: .whitespacesAndNewlines), content: memory
                )
                context.insert(try PregnancyMemory(record: record))
            }
            if deleteAllSessions {
                // Kicks first: a session's cascade would delete them anyway.
                for kick in try context.fetch(FetchDescriptor<Kick>()) { context.delete(kick) }
                for session in try context.fetch(FetchDescriptor<KickSession>()) { context.delete(session) }
            }
            if deleteAllContractions {
                for contraction in try context.fetch(FetchDescriptor<Contraction>()) { context.delete(contraction) }
            }
            if !appointmentIDs.isEmpty {
                for appointment in try context.fetch(FetchDescriptor<Appointment>()) where appointmentIDs.contains(appointment.id) {
                    context.delete(appointment)
                }
            }
            if !weightIDs.isEmpty {
                for weight in try context.fetch(FetchDescriptor<WeightEntry>()) where weightIDs.contains(weight.id) {
                    context.delete(weight)
                }
            }
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
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
