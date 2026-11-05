import Foundation
import KickCore
import KickData
import Observation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "pregnancy-ending")

/// "Thai kỳ của tôi đã kết thúc" (1.1 item 4, spec §4.2, §4.6): runs
/// `PregnancyEndingPlan` over the coordinators, and keeps the memories list.
///
/// The archive (memory saved and raw rows deleted in one transaction) runs
/// first: if it throws, the ending stops there and nothing has changed. Ending
/// never prompts for notification permission.
@MainActor
@Observable
final class PregnancyEnding {
    /// Newest first (Profile's "Kỷ niệm" row shows while it is not empty).
    private(set) var memories: [PregnancyMemoryRecord] = []

    private let kicks: KickCoordinator
    private let contractions: ContractionCoordinator
    private let cycle: CycleCoordinator
    private let appointments: AppointmentCoordinator
    private let weight: WeightCoordinator
    private let container: ModelContainer
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @MainActor () -> Date

    init(
        kicks: KickCoordinator,
        contractions: ContractionCoordinator,
        cycle: CycleCoordinator,
        appointments: AppointmentCoordinator,
        weight: WeightCoordinator,
        container: ModelContainer,
        defaults: UserDefaults = AppGroup.defaults,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @MainActor () -> Date = { AppClock.now() }
    ) {
        self.kicks = kicks
        self.contractions = contractions
        self.cycle = cycle
        self.appointments = appointments
        self.weight = weight
        self.container = container
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    private var store: PregnancyMemoryStore { PregnancyMemoryStore(context: container.mainContext) }

    func loadMemories() {
        do {
            memories = try store.all()
        } catch {
            logger.error("Loading memories failed: \(error.localizedDescription)")
        }
    }

    /// Ends the pregnancy. Throws only from the archive, before anything else changed.
    func end(branch: PregnancyEndBranch, endDate: Date, keep: PregnancyEndingKeep) async throws {
        let endDay = calendar.startOfDay(for: min(endDate, now()))
        for step in PregnancyEndingPlan.steps(keep: keep) {
            switch step {
            case .archive:
                try archive(branch: branch, endDay: endDay, keep: keep)
            case .stopKickCounting:
                // The reminder setting goes too: a language change or a restore
                // would otherwise schedule it again outside pregnancy.
                defaults.set(false, forKey: SettingsKey.reminderEnabled)
                await kicks.stopForPregnancyEnd()
            case .stopContractions:
                await contractions.stopForPregnancyEnd()
            case .endLiveActivities(let force):
                await kicks.endLiveActivities(force: force)
                await contractions.endLiveActivity()
            case .cancelPregnancyReminders:
                await appointments.cancelAllReminders()
            case .switchToCycle:
                await cycle.endPregnancy(branch: branch, endDate: endDay)
            }
        }
        // The lists follow the deleted rows; appointment reminders stay silenced.
        await appointments.load()
        await weight.load()
        loadMemories()
        logger.info("Pregnancy ended")
    }

    private func archive(branch: PregnancyEndBranch, endDay: Date, keep: PregnancyEndingKeep) throws {
        let store = self.store
        let rows = try store.pregnancyRows()
        let profile = PregnancyProfile.load(from: defaults)
        let range = PregnancyRange.make(
            profile: profile, endDate: endDay,
            fallbackStarts: PregnancyMemoryBuilder.fallbackStarts(
                sessions: rows.sessions, contractions: rows.contractions, appointments: rows.appointments
            ),
            calendar: calendar
        )
        let content = keep.memoryTitle.map { _ in
            PregnancyMemoryBuilder.make(
                branch: branch, profile: profile, endDate: endDay,
                sessions: rows.sessions, contractions: rows.contractions, appointments: rows.appointments,
                weights: rows.weights, logs: rows.logs, calendar: calendar
            )
        }
        let deleting = PregnancyMemoryBuilder.rowsToDelete(range: range, appointments: rows.appointments, weights: rows.weights)
        try store.archive(
            memory: content, title: keep.memoryTitle ?? "",
            deleteAllSessions: true, deleteAllContractions: true,
            appointmentIDs: deleting.appointmentIDs, weightIDs: deleting.weightIDs,
            now: now()
        )
    }

    func rename(id: UUID, title: String) {
        do {
            try store.rename(id: id, title: title)
        } catch {
            logger.error("Renaming a memory failed: \(error.localizedDescription)")
        }
        loadMemories()
    }

    /// Returns false when the store refused (the memory stays).
    @discardableResult
    func delete(id: UUID) -> Bool {
        defer { loadMemories() }
        do {
            try store.delete(id: id)
            return true
        } catch {
            logger.error("Deleting a memory failed: \(error.localizedDescription)")
            return false
        }
    }
}
