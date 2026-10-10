import Foundation
import KickCore
import SwiftData

/// SwiftData-backed CycleRepository. Validates every write with `CycleRules`
/// and merges iCloud duplicates on read (overlapping periods, several logs on
/// one day). Storage only: reminders are kept in step by `CycleCoordinator`.
@MainActor
public final class CycleStore: CycleRepository {
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

    public func periods() throws -> [PeriodRecord] {
        let models = try context.fetch(FetchDescriptor<PeriodEntry>(sortBy: [SortDescriptor(\.startDate)]))
        let merged = CycleRules.mergingDuplicates(models.map(\.record), calendar: calendar)
        guard merged.periods.count != models.count else { return merged.periods }
        var keep = Dictionary(merged.periods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for model in models {
            if let record = keep.removeValue(forKey: model.id) {
                // Only touch rows the merge changed: rewriting the others would
                // mark them dirty for CloudKit for nothing.
                if model.record != record {
                    model.apply(record)
                }
            } else {
                context.delete(model)
            }
        }
        try save()
        return merged.periods
    }

    public func logs() throws -> [CycleLogRecord] {
        let models = try context.fetch(FetchDescriptor<CycleLog>(sortBy: [SortDescriptor(\.day)]))
        let merged = CycleRules.mergingDuplicates(models.map(\.record), calendar: calendar)
        guard merged.logs.count != models.count else { return merged.logs }
        var keep = Dictionary(merged.logs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for model in models {
            if let record = keep.removeValue(forKey: model.id) {
                // Only touch rows the merge changed: rewriting the others would
                // mark them dirty for CloudKit for nothing.
                if model.record != record {
                    model.apply(record)
                }
            } else {
                context.delete(model)
            }
        }
        try save()
        return merged.logs
    }

    public func addPeriod(_ period: PeriodRecord, today: Date) throws {
        try CycleRules.validate(period, existing: try periods(), today: today, calendar: calendar)
        context.insert(PeriodEntry(record: CycleRules.normalized(period, calendar: calendar)))
        try save()
    }

    public func updatePeriod(_ period: PeriodRecord, today: Date) throws {
        let existing = try periods()
        guard let model = try periodModel(id: period.id) else { throw CycleRepositoryError.notFound }
        try CycleRules.validate(period, existing: existing, today: today, calendar: calendar)
        model.apply(CycleRules.normalized(period, calendar: calendar))
        try save()
    }

    public func deletePeriod(id: UUID) throws {
        let models = try context.fetch(FetchDescriptor<PeriodEntry>(predicate: #Predicate { $0.id == id }))
        guard !models.isEmpty else { return }
        for model in models {
            context.delete(model)
        }
        try save()
    }

    public func applyPeriodChanges(deletes: [UUID], updates: [PeriodRecord], adds: [PeriodRecord], today: Date) throws {
        let deleted = Set(deletes)
        var final = try periods().filter { !deleted.contains($0.id) }
        let normalizedUpdates = updates.map { CycleRules.normalized($0, calendar: calendar) }
        let normalizedAdds = adds.map { CycleRules.normalized($0, calendar: calendar) }
        for update in normalizedUpdates {
            guard let index = final.firstIndex(where: { $0.id == update.id }) else {
                throw CycleRepositoryError.notFound
            }
            final[index] = update
        }
        final += normalizedAdds
        for record in normalizedUpdates + normalizedAdds {
            try CycleRules.validate(record, existing: final, today: today, calendar: calendar)
        }
        do {
            for id in deleted {
                for model in try context.fetch(FetchDescriptor<PeriodEntry>(predicate: #Predicate { $0.id == id })) {
                    context.delete(model)
                }
            }
            for update in normalizedUpdates {
                guard let model = try periodModel(id: update.id) else { throw CycleRepositoryError.notFound }
                model.apply(update)
            }
            for add in normalizedAdds {
                context.insert(PeriodEntry(record: add))
            }
        } catch {
            context.rollback()
            throw error
        }
        try save()
    }

    public func saveLog(_ log: CycleLogRecord, today: Date) throws {
        let normalized = CycleRules.normalized(log, calendar: calendar)
        try CycleRules.validate(normalized, today: today, calendar: calendar)
        let sameDay = try context.fetch(FetchDescriptor<CycleLog>())
            .filter { calendar.startOfDay(for: $0.day) == normalized.day }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        if normalized.isEmpty {
            guard !sameDay.isEmpty else { return }
            for model in sameDay {
                context.delete(model)
            }
        } else if let kept = sameDay.first {
            kept.apply(normalized)
            for duplicate in sameDay.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            context.insert(CycleLog(record: normalized))
        }
        try save()
    }

    private func periodModel(id: UUID) throws -> PeriodEntry? {
        var descriptor = FetchDescriptor<PeriodEntry>(predicate: #Predicate { $0.id == id })
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
