import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "weight")

public enum WeightFailure: Error, Equatable, Sendable {
    case loadFailed
    case saveFailed
    case futureDate
    case outOfRange
    case invalidHeight

    init(_ error: Error) {
        switch error {
        case WeightRepositoryError.futureDate: self = .futureDate
        case WeightRepositoryError.outOfRange, MaternalProfileError.invalidWeight: self = .outOfRange
        case MaternalProfileError.invalidHeight: self = .invalidHeight
        default: self = .saveFailed
        }
    }
}

/// Single entry point for the mother's weights and her pre-pregnancy profile,
/// used by the UI. Nothing here schedules reminders, so writes are synchronous;
/// `load()` is shared by concurrent callers like the other coordinators.
@MainActor
@Observable
public final class WeightCoordinator {
    /// Oldest first, one per day.
    public private(set) var entries: [WeightRecord] = []
    public private(set) var profile: MaternalProfile
    /// Store errors for the screen's alert; validation errors are only returned.
    public private(set) var failure: WeightFailure?

    private let store: WeightRepository
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: @MainActor () -> Date
    /// The in-flight `load()`, so concurrent callers share one refresh.
    private var loadTask: Task<Void, Never>?

    public init(
        store: WeightRepository,
        defaults: UserDefaults,
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        profile = MaternalProfile.load(from: defaults)
    }

    public var latest: WeightRecord? { entries.last }

    public func entry(on day: Date) -> WeightRecord? {
        let start = calendar.startOfDay(for: day)
        return entries.first { $0.day == start }
    }

    /// Re-reads the store (e.g. after iCloud sync) and the profile. Call on
    /// launch and whenever the app becomes active.
    public func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { self.refresh() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Stores the weight for that day (one per day: a second save that day
    /// replaces the first). Future days and weights outside 30–200 kg are refused.
    @discardableResult
    public func save(kg: Double, on day: Date) -> WeightFailure? {
        let start = calendar.startOfDay(for: day)
        let record = WeightRecord(id: entry(on: start)?.id ?? UUID(), day: start, kg: kg)
        return write { try store.save(record, today: now()) }
    }

    @discardableResult
    public func delete(id: UUID) -> WeightFailure? {
        write { try store.delete(id: id) }
    }

    /// Pre-pregnancy weight 30–200 kg and height 120–220 cm; nil clears a value.
    @discardableResult
    public func updateProfile(_ newProfile: MaternalProfile) -> WeightFailure? {
        do {
            try newProfile.save(to: defaults)
        } catch {
            return WeightFailure(error)
        }
        profile = MaternalProfile.load(from: defaults)
        return nil
    }

    public func clearFailure() {
        failure = nil
    }

    private func write(_ change: () throws -> Void) -> WeightFailure? {
        do {
            try change()
        } catch {
            logger.error("Saving weight failed: \(error.localizedDescription)")
            let failure = WeightFailure(error)
            if failure == .saveFailed { self.failure = .saveFailed }
            return failure
        }
        refresh()
        return nil
    }

    private func refresh() {
        profile = MaternalProfile.load(from: defaults)
        do {
            entries = try store.entries()
            if failure == .loadFailed { failure = nil }
        } catch {
            logger.error("Loading weights failed: \(error.localizedDescription)")
            failure = .loadFailed
        }
    }
}
