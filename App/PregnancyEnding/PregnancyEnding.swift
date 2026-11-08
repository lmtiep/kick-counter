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
    /// A birth just ended: RootView shows the celebration for it (not the sheet or
    /// Profile, which the mode switch rebuilds). Cleared when she closes it.
    var pendingCelebration: PregnancyRecap?

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
    /// Returns the recap to celebrate: only a birth has one.
    @discardableResult
    func end(
        branch: PregnancyEndBranch, endDate: Date, keep: PregnancyEndingKeep, baby: BirthDetails? = nil
    ) async throws -> PregnancyRecap? {
        let endDay = calendar.startOfDay(for: min(endDate, now()))
        let rangeStart = try pregnancyRange(endDay: endDay)?.lowerBound
        // Before any step: `switchToCycle` clears the dates `furthestWeek` needs, and a
        // birth with no memory and the data kept has no archive step at all.
        let content = PregnancyEndingPlan.buildsContent(branch: branch, keep: keep)
            ? try makeContent(branch: branch, endDay: endDay, baby: baby)
            : nil
        let recap = content.flatMap {
            PregnancyRecap.forEnding(content: $0, keptAsMemory: keep.memoryTitle != nil, calendar: calendar)
        }
        for step in PregnancyEndingPlan.steps(keep: keep) {
            switch step {
            case .archive:
                try archive(content: content, endDay: endDay, keep: keep)
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
                // Under the sheet before the mode switch takes it away: she sees the
                // celebration as it slides down, not Today first.
                if let recap { pendingCelebration = recap }
                await cycle.endPregnancy(branch: branch, endDate: endDay, rangeStart: rangeStart)
            }
        }
        // The lists follow the deleted rows; appointment reminders stay silenced.
        await appointments.load()
        await weight.load()
        loadMemories()
        logger.info("Pregnancy ended")
        return recap
    }

    /// The pregnancy's days, from the stored dates (read before `switchToCycle` clears them).
    private func pregnancyRange(endDay: Date) throws -> ClosedRange<Date>? {
        let rows = try store.pregnancyRows()
        return PregnancyRange.make(
            profile: PregnancyProfile.load(from: defaults), endDate: endDay,
            fallbackStarts: PregnancyMemoryBuilder.fallbackStarts(
                sessions: rows.sessions, contractions: rows.contractions, appointments: rows.appointments
            ),
            calendar: calendar
        )
    }

    /// The frozen journey, in memory. Read from the rows before anything is deleted.
    private func makeContent(branch: PregnancyEndBranch, endDay: Date, baby: BirthDetails?) throws -> PregnancyMemoryContent {
        let rows = try store.pregnancyRows()
        return PregnancyMemoryBuilder.make(
            branch: branch, profile: PregnancyProfile.load(from: defaults), endDate: endDay,
            sessions: rows.sessions, contractions: rows.contractions, appointments: rows.appointments,
            weights: rows.weights, logs: rows.logs, calendar: calendar, baby: baby
        )
    }

    /// Saves the memory when she keeps one and deletes the raw rows, in one transaction.
    private func archive(content: PregnancyMemoryContent?, endDay: Date, keep: PregnancyEndingKeep) throws {
        let store = self.store
        let rows = try store.pregnancyRows()
        let range = try pregnancyRange(endDay: endDay)
        let deleting = PregnancyMemoryBuilder.rowsToDelete(
            range: range, sessions: rows.sessions, contractions: rows.contractions,
            appointments: rows.appointments, weights: rows.weights, labourMarkers: rows.labourMarkers,
            checklistItems: rows.checklistItems
        )
        try store.archive(
            memory: keep.memoryTitle == nil ? nil : content, title: keep.memoryTitle ?? "", deleting: deleting, now: now()
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
