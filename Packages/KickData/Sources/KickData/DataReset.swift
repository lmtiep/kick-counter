import Foundation
import SwiftData

/// The store half of "Xoá toàn bộ dữ liệu" (the preferences half is `AppDataReset` in KickCore).
public enum DataReset {
    /// Deletes every instance of each model in `KickPersistence.schema` and saves once.
    /// If saving fails, the deletions are rolled back and the error is rethrown, so the
    /// store is left as it was.
    @MainActor
    public static func deleteAll(in container: ModelContainer) throws {
        let context = container.mainContext
        do {
            // Kicks first: a session's cascade would delete them anyway.
            try deleteEvery(Kick.self, in: context)
            try deleteEvery(KickSession.self, in: context)
            try deleteEvery(Appointment.self, in: context)
            try deleteEvery(PeriodEntry.self, in: context)
            try deleteEvery(CycleLog.self, in: context)
            try deleteEvery(WeightEntry.self, in: context)
            try deleteEvery(PillDose.self, in: context)
            try deleteEvery(Contraction.self, in: context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    private static func deleteEvery<Model: PersistentModel>(_: Model.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<Model>()) {
            context.delete(model)
        }
    }
}
