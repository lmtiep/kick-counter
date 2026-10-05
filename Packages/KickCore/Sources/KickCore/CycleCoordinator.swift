import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "cycle")

public enum CycleFailure: Error, Equatable, Sendable {
    case loadFailed
    case saveFailed
    case futureDate
    case endBeforeStart
    case overlapsExistingPeriod
    case invalidTemperature

    init(_ error: Error) {
        if let failure = error as? CycleFailure { self = failure; return }
        switch error as? CycleRepositoryError {
        case .futureDate?: self = .futureDate
        case .endBeforeStart?: self = .endBeforeStart
        case .overlapsExistingPeriod?: self = .overlapsExistingPeriod
        case .invalidTemperature?: self = .invalidTemperature
        case .notFound?, nil: self = .saveFailed
        }
    }
}

/// Single entry point for cycle data, cycle settings and switching mode, used
/// by the UI. Keeps the repository, the forecast and the three cycle reminders
/// in step: the store never touches notifications, and nothing else schedules
/// cycle reminders.
///
/// Every change bumps `reminderGeneration`. A reminder sync captures it and
/// re-checks it after each `await`, so a change made while a permission prompt
/// or a scheduling request is in flight (e.g. "I'm pregnant") always wins.
@MainActor
@Observable
public final class CycleCoordinator {
    public private(set) var periods: [PeriodRecord] = []
    public private(set) var logs: [CycleLogRecord] = []
    public private(set) var forecast: CycleForecast?
    public private(set) var settings: CycleSettings
    /// Store errors for the screen to show; validation errors are only returned.
    public private(set) var failure: CycleFailure?
    /// True when the user has turned notifications off; the UI shows a hint.
    public private(set) var notificationsDenied = false

    private let store: CycleRepository
    private let notifications: NotificationScheduler
    @ObservationIgnored private var reminderTexts: CycleReminderTexts
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @MainActor () -> Date

    private var reminderGeneration = 0
    /// The in-flight `load()`, so concurrent callers share one refresh.
    private var loadTask: Task<Void, Never>?

    public init(
        store: CycleRepository,
        notifications: NotificationScheduler,
        reminderTexts: CycleReminderTexts,
        defaults: UserDefaults,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.reminderTexts = reminderTexts
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        settings = CycleSettings.load(from: defaults)
    }

    public var mode: AppMode { AppMode.load(from: defaults) }

    /// The log for that calendar day, if any.
    public func log(on day: Date) -> CycleLogRecord? {
        let start = calendar.startOfDay(for: day)
        return logs.first { $0.day == start }
    }

    /// The logged period covering that day, if any.
    public func period(on day: Date) -> PeriodRecord? {
        let start = calendar.startOfDay(for: day)
        let today = now()
        return periods.last { CycleRules.dayRange(of: $0, today: today, calendar: calendar).contains(start) }
    }

    /// Re-reads the store (e.g. after iCloud sync) and reconciles reminders.
    /// Call on launch and whenever the app becomes active. Never prompts for permission.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func performLoad() async {
        guard refresh() else { return }
        await syncReminders(generation: bump(), mayPrompt: false)
    }

    // MARK: - Periods

    @discardableResult
    public func startPeriod(on day: Date) async -> CycleFailure? {
        if case .failure(let failure) = await startPeriodReturningID(on: day) { return failure }
        return nil
    }

    /// Starts a period on `day` and returns the new record's id, so the caller
    /// can undo exactly that record (Today's "Undo").
    public func startPeriodReturningID(on day: Date) async -> Result<UUID, CycleFailure> {
        let record = PeriodRecord(startDate: calendar.startOfDay(for: day))
        let stale = staleOpenPeriod(before: record.startDate)
        let failure = await write {
            // A period left open for weeks was never ended: close it at the typical
            // length so it doesn't run into the new one.
            if let stale { try store.updatePeriod(stale, today: now()) }
            try store.addPeriod(record, today: now())
        }
        return failure.map { .failure($0) } ?? .success(record.id)
    }

    /// The open period that has run past `CycleRules.longPeriodDays` by `day`,
    /// closed at the typical period length; nil when there is none.
    private func staleOpenPeriod(before day: Date) -> PeriodRecord? {
        guard let open = periods.first(where: { $0.isOpen && $0.startDate < day }),
              let length = calendar.dateComponents([.day], from: open.startDate, to: day).day,
              length >= CycleRules.longPeriodDays
        else { return nil }
        let assumed = CycleRules.assumedPeriod(
            startingOn: open.startDate, typicalLength: settings.typicalPeriodLength, today: day, calendar: calendar
        )
        var closed = open
        closed.endDate = assumed.endDate
        return closed.endDate == nil ? nil : closed
    }

    /// Stores the last period from its first day alone (onboarding, empty Cycle
    /// tab), assuming the typical period length when it is already over.
    @discardableResult
    public func logLastPeriod(startingOn day: Date) async -> CycleFailure? {
        let record = CycleRules.assumedPeriod(
            startingOn: day, typicalLength: settings.typicalPeriodLength, today: now(), calendar: calendar
        )
        return await write { try store.addPeriod(record, today: now()) }
    }

    @discardableResult
    public func endPeriod(id: UUID, on day: Date) async -> CycleFailure? {
        guard var record = periods.first(where: { $0.id == id }) else { return report(.saveFailed) }
        record.endDate = calendar.startOfDay(for: day)
        return await write { [record] in try store.updatePeriod(record, today: now()) }
    }

    @discardableResult
    public func updatePeriod(_ period: PeriodRecord) async -> CycleFailure? {
        await write { try store.updatePeriod(period, today: now()) }
    }

    @discardableResult
    public func deletePeriod(id: UUID) async -> CycleFailure? {
        await write { try store.deletePeriod(id: id) }
    }

    // MARK: - Day logs

    /// Saves the day's log (an empty log removes it). Temperatures outside
    /// 35.0–38.5 °C and future days are refused.
    @discardableResult
    public func saveLog(_ log: CycleLogRecord) async -> CycleFailure? {
        await write { try store.saveLog(log, today: now()) }
    }

    // MARK: - Settings and mode

    public func updateSettings(_ newSettings: CycleSettings) async {
        newSettings.save(to: defaults)
        settings = CycleSettings.load(from: defaults)
        recomputeForecast()
        await syncReminders(generation: bump(), mayPrompt: settings.remindersEnabled)
    }

    /// Onboarding or Settings chose "Trying to conceive". Pregnancy data,
    /// appointments and their reminders are left as they are.
    public func activateTryingToConceive() async {
        AppMode.save(.tryingToConceive, to: defaults)
        guard refresh() else { return }
        await syncReminders(generation: bump(), mayPrompt: true)
    }

    /// "I'm pregnant": stores the pregnancy dates (usually the first day of the
    /// latest period), switches to pregnancy mode and cancels cycle reminders.
    /// Cycle data is kept.
    public func switchToPregnant(source: PregnancyDateSource, date: Date) {
        PregnancyProfile.save(source: source, date: date, to: defaults, calendar: calendar)
        AppMode.save(.pregnant, to: defaults)
        bump()
        notifications.cancelCycleReminders()
    }

    /// The app language changed: the cycle reminders are scheduled again with
    /// the new texts. Never prompts for permission.
    public func updateReminderTexts(_ texts: CycleReminderTexts) async {
        reminderTexts = texts
        await syncReminders(generation: bump(), mayPrompt: false)
    }

    public func clearFailure() {
        failure = nil
    }

    // MARK: - Internals

    private func write(_ change: () throws -> Void) async -> CycleFailure? {
        do {
            try change()
        } catch {
            logger.error("Saving cycle data failed: \(error.localizedDescription)")
            return report(CycleFailure(error))
        }
        // Saved, but the reload failed (`failure` is set): leave reminders alone
        // rather than syncing them to data that no longer matches the store.
        guard refresh() else { return nil }
        await syncReminders(generation: bump(), mayPrompt: true)
        return nil
    }

    /// Store errors also go to `failure` for the screen's alert.
    private func report(_ failure: CycleFailure) -> CycleFailure {
        if failure == .saveFailed { self.failure = .saveFailed }
        return failure
    }

    private var wantsReminders: Bool {
        mode == .tryingToConceive && settings.remindersEnabled && forecast != nil
    }

    /// Brings the three cycle reminders in line with the current forecast.
    /// `generation` is the value captured when the triggering change happened:
    /// if a newer change lands during an `await`, the newest state is re-applied.
    private func syncReminders(generation: Int, mayPrompt: Bool) async {
        guard wantsReminders else {
            notifications.cancelCycleReminders()
            return
        }
        let authorized: Bool
        if mayPrompt {
            authorized = await notifications.requestAuthorizationIfNeeded()
        } else {
            authorized = await notifications.isAuthorized()
        }
        await updateDeniedHint(authorized: authorized)
        guard authorized else { return }
        guard generation == reminderGeneration else {
            await syncReminders(generation: reminderGeneration, mayPrompt: false)
            return
        }
        guard wantsReminders, let forecast else {
            notifications.cancelCycleReminders()
            return
        }
        do {
            try await notifications.scheduleCycleReminders(for: forecast, now: now(), texts: reminderTexts, calendar: calendar)
        } catch {
            logger.error("Scheduling cycle reminders failed: \(error.localizedDescription)")
            // Requests that landed before the failure may be stale by now.
            if generation != reminderGeneration {
                await syncReminders(generation: reminderGeneration, mayPrompt: false)
            }
            return
        }
        // Changed while the requests were in flight: re-apply the newest state.
        if generation != reminderGeneration {
            await syncReminders(generation: reminderGeneration, mayPrompt: false)
        }
    }

    private func updateDeniedHint(authorized: Bool) async {
        if authorized {
            notificationsDenied = false
        } else {
            notificationsDenied = await notifications.isDenied()
        }
    }

    @discardableResult
    private func refresh() -> Bool {
        settings = CycleSettings.load(from: defaults)
        let loadedPeriods: [PeriodRecord]
        let loadedLogs: [CycleLogRecord]
        do {
            loadedPeriods = try store.periods()
            loadedLogs = try store.logs()
        } catch {
            logger.error("Loading cycle data failed: \(error.localizedDescription)")
            failure = .loadFailed
            return false
        }
        periods = loadedPeriods
        logs = loadedLogs
        recomputeForecast()
        return true
    }

    private func recomputeForecast() {
        forecast = CyclePredictor.forecast(periods: periods, logs: logs, settings: settings, now: now(), calendar: calendar)
    }

    @discardableResult
    private func bump() -> Int {
        reminderGeneration += 1
        return reminderGeneration
    }
}
