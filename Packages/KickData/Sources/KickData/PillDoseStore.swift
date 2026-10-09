import Foundation
import KickCore
import SwiftData

/// SwiftData-backed PillDoseRepository (phase 17): at most one dose per day.
@MainActor
public final class PillDoseStore: PillDoseRepository {
    private let context: ModelContext
    private let calendar: Calendar
    private let saveContext: @MainActor (ModelContext) throws -> Void

    public convenience init(context: ModelContext, calendar: Calendar = .current) {
        self.init(context: context, calendar: calendar, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests, as in `WeightStore`.
    init(context: ModelContext, calendar: Calendar, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.calendar = calendar
        self.saveContext = saveContext
    }

    /// Oldest first. Several doses on one day (never written by this store) are
    /// merged: the earliest `takenAt` is kept.
    public func doses() throws -> [PillDoseRecord] {
        let models = try context.fetch(FetchDescriptor<PillDose>(sortBy: [SortDescriptor(\.day), SortDescriptor(\.takenAt)]))
        var kept: [PillDoseRecord] = []
        var duplicates: [PillDose] = []
        for model in models {
            let day = calendar.startOfDay(for: model.day)
            if kept.last?.day == day {
                duplicates.append(model)
            } else {
                kept.append(PillDoseRecord(id: model.id, day: day, takenAt: model.takenAt))
            }
        }
        if !duplicates.isEmpty {
            for duplicate in duplicates {
                context.delete(duplicate)
            }
            try save()
        }
        return kept
    }

    public func markTaken(on day: Date, at time: Date) throws {
        let record = try PillDoseRules.dose(on: day, takenAt: time, calendar: calendar)
        guard try models(on: record.day).isEmpty else { return }
        context.insert(PillDose(record: record))
        try save()
    }

    public func unmark(on day: Date) throws {
        let models = try models(on: calendar.startOfDay(for: day))
        guard !models.isEmpty else { return }
        for model in models {
            context.delete(model)
        }
        try save()
    }

    private func models(on start: Date) throws -> [PillDose] {
        try context.fetch(FetchDescriptor<PillDose>()).filter { calendar.startOfDay(for: $0.day) == start }
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
