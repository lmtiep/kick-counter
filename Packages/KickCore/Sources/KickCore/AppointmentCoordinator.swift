import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "appointments")

/// Single entry point for appointment changes, used by the UI. Keeps the
/// repository and the day-before reminders in step: the store never touches
/// notifications, and nothing else schedules appointment reminders.
///
/// Every change bumps a per-appointment generation. Reminder side effects
/// capture it and re-check it after each `await`, so an appointment deleted,
/// marked done or edited while a permission prompt or a scheduling request is
/// in flight never ends up with a stale reminder (the same guard
/// `KickCoordinator` applies with `activeSessionID`).
@MainActor
@Observable
public final class AppointmentCoordinator {
    public private(set) var upcoming: [AppointmentRecord] = []
    public private(set) var past: [AppointmentRecord] = []
    public private(set) var failure: KickFailure?
    /// True when the user has turned notifications off; the UI shows a hint.
    public private(set) var notificationsDenied = false

    private let store: AppointmentRepository
    private let notifications: NotificationScheduler
    @ObservationIgnored private var reminderText: NotificationText
    private let calendar: Calendar
    private let now: @MainActor () -> Date

    private var generations: [UUID: Int] = [:]
    /// The in-flight `load()`, so concurrent callers share one reconciliation.
    private var loadTask: Task<Void, Never>?

    public init(
        store: AppointmentRepository,
        notifications: NotificationScheduler,
        reminderText: NotificationText,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.notifications = notifications
        self.reminderText = reminderText
        self.calendar = calendar
        self.now = now
    }

    public var nextAppointment: AppointmentRecord? { upcoming.first }

    /// Refreshes the lists and reconciles reminders with the store (e.g. after
    /// iCloud sync). Call on launch and whenever the app becomes active.
    /// Never prompts for permission.
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
        let authorized = await notifications.isAuthorized()
        await updateDeniedHint(authorized: authorized)
        guard authorized else { return }

        let pending = await notifications.pendingAppointmentReminderIDs()
        // Read the store after the await, and cancel without awaiting, so an
        // appointment added meanwhile is never treated as an orphan.
        let wanted: [UUID]
        do {
            let time = now()
            wanted = try store.upcoming(now: time).filter { AppointmentRules.wantsReminder($0, now: time) }.map(\.id)
        } catch {
            logger.error("Reading appointments for reminders failed: \(error.localizedDescription)")
            return
        }
        for id in pending.subtracting(wanted) {
            notifications.cancelAppointmentReminder(id: id)
        }
        for id in wanted {
            await syncReminder(id: id, generation: generation(of: id), mayPrompt: false)
        }
    }

    @discardableResult
    public func add(date: Date, title: String, note: String = "", milestoneID: String? = nil) async -> AppointmentRecord? {
        let record = AppointmentRecord(
            date: date, title: Self.trimmed(title), note: Self.trimmed(note), milestoneID: milestoneID
        )
        do {
            try store.add(record)
        } catch {
            logger.error("Saving appointment failed: \(error.localizedDescription)")
            failure = .saveFailed
            return nil
        }
        refresh()
        await syncReminder(id: record.id, generation: bump(record.id), mayPrompt: true)
        return record
    }

    @discardableResult
    public func update(_ appointment: AppointmentRecord) async -> Bool {
        var record = appointment
        record.title = Self.trimmed(record.title)
        record.note = Self.trimmed(record.note)
        do {
            try store.update(record)
        } catch {
            logger.error("Updating appointment failed: \(error.localizedDescription)")
            failure = .saveFailed
            return false
        }
        refresh()
        await syncReminder(id: record.id, generation: bump(record.id), mayPrompt: true)
        return true
    }

    public func delete(id: UUID) async {
        do {
            try store.delete(id: id)
        } catch {
            logger.error("Deleting appointment failed: \(error.localizedDescription)")
            failure = .saveFailed
            return
        }
        bump(id)
        notifications.cancelAppointmentReminder(id: id)
        refresh()
    }

    public func markDone(id: UUID) async {
        do {
            _ = try store.markDone(id: id)
        } catch {
            logger.error("Marking appointment done failed: \(error.localizedDescription)")
            failure = .saveFailed
            return
        }
        bump(id)
        notifications.cancelAppointmentReminder(id: id)
        refresh()
    }

    public func clearFailure() {
        failure = nil
    }

    /// The app language changed: every pending day-before reminder is scheduled
    /// again with the new text. Never prompts for permission.
    public func updateReminderText(_ text: NotificationText) async {
        reminderText = text
        await performLoad()
    }

    /// Brings one appointment's reminder in line with the store. `generation`
    /// is the value captured when the triggering change happened: if another
    /// change bumps it during an `await`, this run stops (before scheduling)
    /// or re-syncs from the store (after scheduling) so the newest state wins.
    private func syncReminder(id: UUID, generation: Int, mayPrompt: Bool) async {
        let record: AppointmentRecord?
        do {
            record = try store.appointment(id: id)
        } catch {
            logger.error("Reading appointment failed: \(error.localizedDescription)")
            return
        }
        guard let record, AppointmentRules.wantsReminder(record, now: now()) else {
            notifications.cancelAppointmentReminder(id: id)
            return
        }

        let authorized: Bool
        if mayPrompt {
            authorized = await notifications.requestAuthorizationIfNeeded()
        } else {
            authorized = await notifications.isAuthorized()
        }
        await updateDeniedHint(authorized: authorized)
        guard authorized, self.generation(of: id) == generation else { return }

        do {
            try await notifications.scheduleAppointmentReminder(
                id: id, date: record.date, title: record.title, now: now(), text: reminderText, calendar: calendar
            )
        } catch {
            logger.error("Scheduling appointment reminder failed: \(error.localizedDescription)")
            return
        }
        // Changed while the request was in flight: this older request may
        // have landed last, so re-apply whatever the store holds now.
        if self.generation(of: id) != generation {
            await syncReminder(id: id, generation: self.generation(of: id), mayPrompt: false)
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
        do {
            let time = now()
            upcoming = try store.upcoming(now: time)
            past = try store.past(now: time)
            return true
        } catch {
            logger.error("Loading appointments failed: \(error.localizedDescription)")
            failure = .loadFailed
            return false
        }
    }

    private func generation(of id: UUID) -> Int {
        generations[id, default: 0]
    }

    @discardableResult
    private func bump(_ id: UUID) -> Int {
        let next = generation(of: id) + 1
        generations[id] = next
        return next
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
