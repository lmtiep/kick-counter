import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "pill")

public enum PillFailure: Error, Equatable, Sendable {
    case loadFailed
    case saveFailed
    case futureDate
}

/// What Today's pill card shows (phase 17 spec §4.3).
public enum PillToday: Equatable, Sendable {
    /// Pill `number` of `count`; `taken` once marked.
    case pillDay(number: Int, count: Int, taken: PillDoseRecord?)
    /// Days 22–28 of a 21+7 pack.
    case breakWeek(nextPackStart: Date)
}

/// The daily pill reminder (phase 17): its settings, the marked pills and the
/// pending notifications. It is available only in the cycle mode with the pill
/// as contraception; otherwise its reminders are cancelled and its settings kept.
///
/// Every change bumps `generation`. A reminder sync re-checks it after each
/// `await`, so the newest state always wins.
@MainActor
@Observable
public final class PillCoordinator {
    public private(set) var settings: PillReminderSettings
    /// Oldest first, one per day.
    public private(set) var doses: [PillDoseRecord] = []
    /// Store errors for the screen's alert.
    public private(set) var failure: PillFailure?
    /// True when the user has turned notifications off; the UI shows a hint.
    public private(set) var notificationsDenied = false

    private let store: PillDoseRepository
    private let notifications: NotificationScheduler
    @ObservationIgnored private var texts: PillReminderTexts
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @MainActor () -> Date
    /// Mode and contraception live in other coordinators' keys: re-read on every
    /// refresh, kept here so SwiftUI observes them.
    private var mode: AppMode
    private var contraception: Contraception?
    private var generation = 0
    private var loadTask: Task<Void, Never>?

    public init(
        store: PillDoseRepository,
        notifications: NotificationScheduler,
        texts: PillReminderTexts,
        defaults: UserDefaults,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.texts = texts
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        settings = PillReminderSettings.load(from: defaults)
        mode = AppMode.load(from: defaults)
        contraception = CyclePreferences.load(from: defaults).contraception
    }

    /// The setting shows only in the cycle mode with the pill.
    public var isAvailable: Bool { mode == .tryingToConceive && contraception == .pill }

    /// Reminders and the Today card: available, switched on, with a pack start.
    public var isActive: Bool { isAvailable && settings.enabled && settings.packStart != nil }

    public var pack: PillPack? { settings.pack(calendar: calendar) }

    public func dose(on day: Date) -> PillDoseRecord? {
        let start = calendar.startOfDay(for: day)
        return doses.first { $0.day == start }
    }

    /// Today's card; nil when the reminder is not active.
    public var today: PillToday? {
        guard isActive, let pack else { return nil }
        let date = now()
        guard let number = pack.pillNumber(on: date) else {
            return .breakWeek(nextPackStart: pack.nextPackStart(after: date))
        }
        return .pillDay(number: number, count: pack.pillCount, taken: dose(on: date))
    }

    /// Re-reads the settings, mode, contraception and doses, then reconciles the
    /// reminders. Call on launch and whenever the app becomes active. Never prompts.
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
        refresh()
        await syncReminders(generation: bump(), mayPrompt: false)
    }

    /// Stores new settings (the pack start at start of day). Turning the reminder
    /// on may ask for notification permission. Returns false when the reminders
    /// could not be scheduled because notifications are not allowed; the setting
    /// stays on and `notificationsDenied` tells the screen.
    @discardableResult
    public func update(_ newSettings: PillReminderSettings) async -> Bool {
        var stored = newSettings
        stored.packStart = newSettings.packStart.map(calendar.startOfDay(for:))
        stored.save(to: defaults)
        refresh()
        return await syncReminders(generation: bump(), mayPrompt: newSettings.enabled)
    }

    /// Marks the pill of the day of `day` (Today, or the notification's action).
    @discardableResult
    public func markTaken(on day: Date) async -> PillFailure? {
        await write { try store.markTaken(on: day, at: now()) }
    }

    /// "Bỏ đánh dấu": the day's reminders come back while still ahead.
    @discardableResult
    public func undo(on day: Date) async -> PillFailure? {
        await write { try store.unmark(on: day) }
    }

    /// Profile changed the contraception (or the mode changed): reminders follow.
    public func contraceptionChanged() async {
        refresh()
        await syncReminders(generation: bump(), mayPrompt: false)
    }

    /// The app language changed: reschedule with the new texts.
    public func updateTexts(_ newTexts: PillReminderTexts) async {
        texts = newTexts
        await syncReminders(generation: bump(), mayPrompt: false)
    }

    public func clearFailure() {
        failure = nil
    }

    // MARK: - Internals

    private func write(_ change: () throws -> Void) async -> PillFailure? {
        do {
            try change()
        } catch PillDoseError.futureDate {
            return .futureDate
        } catch {
            logger.error("Saving a pill dose failed: \(error.localizedDescription)")
            failure = .saveFailed
            return .saveFailed
        }
        refresh()
        await syncReminders(generation: bump(), mayPrompt: false)
        return nil
    }

    private func refresh() {
        settings = PillReminderSettings.load(from: defaults)
        mode = AppMode.load(from: defaults)
        contraception = CyclePreferences.load(from: defaults).contraception
        do {
            doses = try store.doses()
            if failure == .loadFailed { failure = nil }
        } catch {
            logger.error("Loading pill doses failed: \(error.localizedDescription)")
            failure = .loadFailed
        }
    }

    @discardableResult
    private func bump() -> Int {
        generation += 1
        return generation
    }

    /// Brings the pending pill notifications in line with the current state.
    /// Returns false only when notifications are not allowed.
    @discardableResult
    private func syncReminders(generation captured: Int, mayPrompt: Bool) async -> Bool {
        guard isActive else {
            await notifications.cancelPillReminders()
            return true
        }
        let authorized = mayPrompt
            ? await notifications.requestAuthorizationIfNeeded()
            : await notifications.isAuthorized()
        notificationsDenied = authorized ? false : await notifications.isDenied()
        guard authorized else { return false }
        guard captured == generation else {
            return await syncReminders(generation: generation, mayPrompt: false)
        }
        guard isActive, let pack else {
            await notifications.cancelPillReminders()
            return true
        }
        let requests = PillReminderPlan.requests(
            pack: pack, hour: settings.hour, minute: settings.minute, now: now(),
            takenDays: Set(doses.map(\.day)), calendar: calendar
        )
        do {
            try await notifications.schedulePillReminders(requests, texts: texts, calendar: calendar)
        } catch {
            logger.error("Scheduling pill reminders failed: \(error.localizedDescription)")
        }
        if captured != generation {
            return await syncReminders(generation: generation, mayPrompt: false)
        }
        return true
    }
}
