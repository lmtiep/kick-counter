import Foundation
import KickCore
import SwiftData

/// SwiftData storage for the hospital bag and the doctor questions (1.1). Built-in bag
/// items are not stored until the mother ticks or hides one; an override that is back to
/// "untouched" is removed again. The screens read `@Query` and write through this store.
@MainActor
public final class ChecklistStore {
    private let context: ModelContext
    private let saveContext: @MainActor (ModelContext) throws -> Void

    public convenience init(context: ModelContext) {
        self.init(context: context, saveContext: { try $0.save() })
    }

    /// `saveContext` is a seam for tests, as in `AppointmentStore`.
    init(context: ModelContext, saveContext: @escaping @MainActor (ModelContext) throws -> Void) {
        self.context = context
        self.saveContext = saveContext
    }

    public func items() throws -> [ChecklistItemRecord] {
        try models().map(\.record).sorted { $0.createdAt < $1.createdAt }
    }

    /// Nil (nothing stored) when `text` is blank.
    @discardableResult
    public func addBagItem(_ text: String, group: BagGroup, now: Date = Date()) throws -> ChecklistItemRecord? {
        guard let text = ChecklistText.clean(text) else { return nil }
        let siblings = try models().filter { $0.list == ChecklistKind.bag.rawValue && $0.group == group.rawValue }
        let record = ChecklistItemRecord(
            kind: .bag, group: group, text: text, order: (siblings.map(\.order).max() ?? 0) + 1, createdAt: now
        )
        context.insert(ChecklistItem(record: record))
        try save()
        return record
    }

    /// `appointmentID` nil leaves it unassigned. Nil (nothing stored) when `text` is blank.
    @discardableResult
    public func addQuestion(_ text: String, appointmentID: UUID?, now: Date = Date()) throws -> ChecklistItemRecord? {
        guard let text = ChecklistText.clean(text) else { return nil }
        let siblings = try models().filter { $0.list == ChecklistKind.question.rawValue && $0.appointmentID == appointmentID }
        let record = ChecklistItemRecord(
            kind: .question, text: text, order: (siblings.map(\.order).max() ?? 0) + 1,
            appointmentID: appointmentID, createdAt: now
        )
        context.insert(ChecklistItem(record: record))
        try save()
        return record
    }

    public func setBuiltInDone(_ builtInID: String, done: Bool, now: Date = Date()) throws {
        try updateBuiltIn(builtInID, now: now) { $0.isDone = done }
    }

    public func setBuiltInHidden(_ builtInID: String, hidden: Bool, now: Date = Date()) throws {
        try updateBuiltIn(builtInID, now: now) { $0.isHidden = hidden }
    }

    /// A custom bag item or a question.
    public func setDone(id: UUID, done: Bool) throws {
        guard let model = try models().first(where: { $0.id == id }) else { return }
        model.isDone = done
        try save()
    }

    public func delete(id: UUID) throws {
        guard let model = try models().first(where: { $0.id == id }) else { return }
        context.delete(model)
        try save()
    }

    /// Unticks every bag item. Hidden built-ins stay hidden; questions are not touched.
    public func resetBagTicks() throws {
        for model in try models() where model.list == ChecklistKind.bag.rawValue && model.isDone {
            model.isDone = false
            dropIfUntouched(model)
        }
        try save()
    }

    public func unhideAllBuiltIns() throws {
        for model in try models() where model.list == ChecklistKind.bag.rawValue && model.isHidden {
            model.isHidden = false
            dropIfUntouched(model)
        }
        try save()
    }

    /// Gives every unassigned question to `appointmentID`; returns how many moved.
    @discardableResult
    public func adoptUnassignedQuestions(into appointmentID: UUID) throws -> Int {
        let loose = try models().filter { $0.list == ChecklistKind.question.rawValue && $0.appointmentID == nil }
        guard !loose.isEmpty else { return 0 }
        let taken = try models().filter { $0.list == ChecklistKind.question.rawValue && $0.appointmentID == appointmentID }.map(\.order).max() ?? 0
        for (offset, model) in loose.sorted(by: { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }).enumerated() {
            model.appointmentID = appointmentID
            model.order = taken + offset + 1
        }
        try save()
        return loose.count
    }

    private func updateBuiltIn(_ builtInID: String, now: Date, change: (ChecklistItem) -> Void) throws {
        guard BagCatalog.items.contains(where: { $0.id == builtInID }) else { return }
        // The newest row, as `BagList` reads it; older duplicates (from a backup) are removed.
        let rows = try models().filter { $0.list == ChecklistKind.bag.rawValue && $0.builtInID == builtInID }
        let newestID = BagList.canonicalOverrides(rows.map(\.record))[builtInID]?.id
        let existing = rows.first { $0.id == newestID }
        for duplicate in rows where duplicate.id != newestID { context.delete(duplicate) }
        let model = existing ?? ChecklistItem(record: ChecklistItemRecord(kind: .bag, builtInID: builtInID, createdAt: now))
        if existing == nil { context.insert(model) }
        change(model)
        dropIfUntouched(model)
        try save()
    }

    /// A built-in override that is neither ticked nor hidden carries no information.
    private func dropIfUntouched(_ model: ChecklistItem) {
        if model.builtInID != nil, !model.isDone, !model.isHidden {
            context.delete(model)
        }
    }

    private func models() throws -> [ChecklistItem] {
        try context.fetch(FetchDescriptor<ChecklistItem>())
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
