import Foundation
import KickCore
import SwiftData

/// SwiftData-backed PillDoseRepository (phase 17): at most one dose per
/// calendar day. Days are `CalendarDay` keys, never instants, so a dose stays
/// on its date whatever the time zone (phase 17 review).
@MainActor
public final class PillDoseStore: PillDoseRepository {
    private let context: ModelContext
    private let calendar: Calendar
    private let saveContext: @MainActor (ModelContext) throws -> Void

    /// `calendar` only dates the rows of earlier builds and checks "not in the
    /// future"; `.autoupdatingCurrent` follows the phone's time zone.
    public convenience init(context: ModelContext, calendar: Calendar = .autoupdatingCurrent) {
        self.init(context: context, calendar: calendar, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests, as in `WeightStore`.
    init(context: ModelContext, calendar: Calendar, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.calendar = calendar
        self.saveContext = saveContext
    }

    /// Oldest first. Rows without a `dayKey` get one; several doses on one day
    /// (never written by this store) are merged, keeping the earliest `takenAt`.
    public func doses() throws -> [PillDoseRecord] {
        let models = try context.fetch(FetchDescriptor<PillDose>(sortBy: [SortDescriptor(\.takenAt)]))
        var changed = false
        var kept: [CalendarDay: PillDoseRecord] = [:]
        for model in models {
            let day = model.calendarDay(in: calendar)
            if model.dayKey != day.key {
                model.dayKey = day.key
                changed = true
            }
            if kept[day] == nil {
                kept[day] = PillDoseRecord(id: model.id, day: day, takenAt: model.takenAt)
            } else {
                context.delete(model)
                changed = true
            }
        }
        if changed { try save() }
        return kept.values.sorted { $0.day < $1.day }
    }

    public func markTaken(on day: CalendarDay, at time: Date) throws {
        let record = try PillDoseRules.dose(on: day, takenAt: time, calendar: calendar)
        guard try models(on: day).isEmpty else { return }
        context.insert(PillDose(record: record))
        try save()
    }

    public func unmark(on day: CalendarDay) throws {
        let models = try models(on: day)
        guard !models.isEmpty else { return }
        for model in models {
            context.delete(model)
        }
        try save()
    }

    private func models(on day: CalendarDay) throws -> [PillDose] {
        try context.fetch(FetchDescriptor<PillDose>()).filter { $0.calendarDay(in: calendar) == day }
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
