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
    /// Pill `number` of `count` of `day`; `taken` once marked. `isYesterday`:
    /// just after midnight, yesterday's pill while it is unmarked and its
    /// follow-up time has not come (a late reminder, phase 17 review).
    case pillDay(number: Int, count: Int, day: CalendarDay, isYesterday: Bool, taken: PillDoseRecord?)
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
    /// Bumped by every refresh, so views reading `today` update after a
    /// reload (e.g. at midnight or after a time-zone change).
    private var refreshCount = 0
    /// Mode and contraception live in other coordinators' keys: re-read on every
    /// refresh, kept here so SwiftUI observes them.
    private var mode: AppMode
    private var preferences: CyclePreferences
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
        settings = PillReminderSettings.load(from: defaults, calendar: calendar)
        mode = AppMode.load(from: defaults)
        preferences = CyclePreferences.load(from: defaults)
    }

    /// The setting shows only in the cycle mode with the pill. Like
    /// `CycleDisplayPolicy`, only while tracking: trying to conceive ignores a
    /// stored contraception (and Profile hides it).
    public var isAvailable: Bool {
        mode == .tryingToConceive && preferences.goal == .tracking && preferences.contraception == .pill
    }

    /// Reminders and the Today card: available, switched on, with a pack start.
    public var isActive: Bool { isAvailable && settings.enabled && settings.packStartDay != nil }

    public var pack: PillPack? { settings.pack(calendar: calendar) }

    public func dose(on day: CalendarDay) -> PillDoseRecord? {
        doses.first { $0.day == day }
    }

    public func dose(on date: Date) -> PillDoseRecord? {
        dose(on: CalendarDay(date, calendar: calendar))
    }

    /// Today's card; nil when the reminder is not active.
    public var today: PillToday? {
        _ = refreshCount
        guard isActive, let pack else { return nil }
        let date = now()
        let today = CalendarDay(date, calendar: calendar)
        let yesterday = today.adding(days: -1)
        if let number = pack.pillNumber(on: yesterday), dose(on: yesterday) == nil,
           let followUp = PillReminderPlan.followUpDate(
               for: yesterday, pack: pack, hour: settings.hour, minute: settings.minute, calendar: calendar
           ),
           date < followUp {
            return .pillDay(number: number, count: pack.pillCount, day: yesterday, isYesterday: true, taken: nil)
        }
        guard let number = pack.pillNumber(on: today) else {
            return .breakWeek(nextPackStart: pack.nextPackStart(after: date))
        }
        return .pillDay(number: number, count: pack.pillCount, day: today, isYesterday: false, taken: dose(on: today))
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
        newSettings.save(to: defaults)
        refresh()
        return await syncReminders(generation: bump(), mayPrompt: newSettings.enabled)
    }

    /// Marks the pill of `day` (Today's card, or the notification's action) and
    /// clears that day's delivered notifications.
    @discardableResult
    public func markTaken(on day: CalendarDay) async -> PillFailure? {
        let failure = await write { try store.markTaken(on: day, at: now()) }
        if failure == nil { notifications.removeDeliveredPillReminders(for: day) }
        return failure
    }

    /// Marks the pill of the local day of `date`.
    @discardableResult
    public func markTaken(on date: Date) async -> PillFailure? {
        await markTaken(on: CalendarDay(date, calendar: calendar))
    }

    /// "Bỏ đánh dấu": the day's reminders come back while still ahead.
    @discardableResult
    public func undo(on day: CalendarDay) async -> PillFailure? {
        await write { try store.unmark(on: day) }
    }

    @discardableResult
    public func undo(on date: Date) async -> PillFailure? {
        await undo(on: CalendarDay(date, calendar: calendar))
    }

    /// The contraception, the goal or the mode changed: reminders follow.
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
        refreshCount += 1
        settings = PillReminderSettings.load(from: defaults, calendar: calendar)
        mode = AppMode.load(from: defaults)
        preferences = CyclePreferences.load(from: defaults)
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
