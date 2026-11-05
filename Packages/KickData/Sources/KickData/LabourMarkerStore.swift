import Foundation
import KickCore
import SwiftData

/// SwiftData-backed LabourMarkerRepository (edit spec 2026-11-06).
@MainActor
public final class LabourMarkerStore: LabourMarkerRepository {
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

    public func markers() throws -> [LabourMarkerRecord] {
        try context.fetch(FetchDescriptor<LabourMarker>(sortBy: [SortDescriptor(\.at)])).map(\.record)
    }

    public func save(_ record: LabourMarkerRecord) throws {
        let models = try context.fetch(FetchDescriptor<LabourMarker>())
        if let model = models.first(where: { $0.id == record.id }) {
            model.kind = record.kind
            model.at = record.at
        } else {
            context.insert(LabourMarker(record: record))
        }
        try save()
    }

    public func delete(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let wanted = Set(ids)
        let models = try context.fetch(FetchDescriptor<LabourMarker>()).filter { wanted.contains($0.id) }
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
