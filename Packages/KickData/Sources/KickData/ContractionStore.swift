import Foundation
import KickCore
import SwiftData

/// SwiftData-backed ContractionRepository (phase 20): at most one contraction
/// runs (`ContractionRules.validate`).
@MainActor
public final class ContractionStore: ContractionRepository {
    private let context: ModelContext
    private let saveContext: @MainActor (ModelContext) throws -> Void

    public convenience init(context: ModelContext) {
        self.init(context: context, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests, as in `WeightStore`.
    init(context: ModelContext, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.saveContext = saveContext
    }

    public func contractions() throws -> [ContractionRecord] {
        try context.fetch(FetchDescriptor<Contraction>(sortBy: [SortDescriptor(\.startedAt)])).map(\.record)
    }

    public func save(_ record: ContractionRecord) throws {
        let models = try context.fetch(FetchDescriptor<Contraction>())
        try ContractionRules.validate(record, existing: models.map(\.record))
        if let model = models.first(where: { $0.id == record.id }) {
            model.startedAt = record.startedAt
            model.endedAt = record.endedAt
        } else {
            context.insert(Contraction(record: record))
        }
        try save()
    }

    public func delete(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let wanted = Set(ids)
        let models = try context.fetch(FetchDescriptor<Contraction>()).filter { wanted.contains($0.id) }
        guard !models.isEmpty else { return }
        for model in models {
            context.delete(model)
        }
        try save()
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
