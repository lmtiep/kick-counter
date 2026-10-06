import Foundation
import KickCore
import SwiftData

/// SwiftData-backed WeightRepository. Validates every write with `WeightRules`
/// and merges iCloud duplicates (several entries on one day) on read.
@MainActor
public final class WeightStore: WeightRepository {
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

    public func entries() throws -> [WeightRecord] {
        let models = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.day)]))
        let merged = WeightRules.mergingDuplicates(models.map(\.record), calendar: calendar)
        guard merged.entries.count != models.count else { return merged.entries }
        var keep = Dictionary(merged.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for model in models {
            if let record = keep.removeValue(forKey: model.id) {
                // Only touch rows the merge changed (CloudKit would re-upload them).
                if model.record != record {
                    model.apply(record)
                }
            } else {
                context.delete(model)
            }
        }
        try save()
        return merged.entries
    }

    public func save(_ entry: WeightRecord, today: Date) throws {
        try WeightRules.validate(entry, today: today, calendar: calendar)
        let normalized = WeightRules.normalized(entry, calendar: calendar)
        let sameDay = try context.fetch(FetchDescriptor<WeightEntry>())
            .filter { calendar.startOfDay(for: $0.day) == normalized.day }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        if let kept = sameDay.first {
            kept.apply(normalized)
            for duplicate in sameDay.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            context.insert(WeightEntry(record: normalized))
        }
        try save()
    }

    public func delete(id: UUID) throws {
        let models = try context.fetch(FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.id == id }))
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
