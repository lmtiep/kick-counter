import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Parses an ISO-8601 timestamp such as "2026-09-01T20:00:00Z".
func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

/// Spins on `Task.yield()` until `condition` becomes true, failing the test
/// (via `#require`) after `maxYields` iterations instead of hanging forever
/// when a regression means some gated fake call never reaches its hold point.
@MainActor
func waitUntil(
    _ condition: @autoclosure () -> Bool,
    maxYields: Int = 10_000,
    sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    var yields = 0
    while !condition() {
        yields += 1
        try #require(yields < maxYields, "Timed out waiting for condition to become true", sourceLocation: sourceLocation)
        await Task.yield()
    }
}

@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    var added: [UNNotificationRequest] = []
    var removed: [String] = []
    var status: UNAuthorizationStatus = .authorized
    var grantOnRequest = true
    var requestCount = 0

    struct AddFailed: Error {}

    /// One-shot: the next `add(_:)` call throws instead of scheduling.
    var failNextAdd = false

    func add(_ request: UNNotificationRequest) async throws {
        if failNextAdd {
            failNextAdd = false
            throw AddFailed()
        }
        if holdAdd {
            holdAdd = false
            addPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                addContinuations.append(continuation)
            }
            addPending = false
        }
        added.removeAll { $0.identifier == request.identifier }
        added.append(request)
    }

    /// One-shot gate: the next `add(_:)` call suspends until `releaseAdd()` is
    /// called, simulating a scheduling request still in flight.
    var holdAdd = false
    private(set) var addPending = false
    private var addContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseAdd() {
        let continuations = addContinuations
        addContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    func removePending(ids: [String]) {
        removed.append(contentsOf: ids)
        added.removeAll { ids.contains($0.identifier) }
    }

    func requestAuthorization() async throws -> Bool {
        if holdRequestAuthorization {
            holdRequestAuthorization = false
            requestAuthorizationPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                requestAuthorizationContinuations.append(continuation)
            }
            requestAuthorizationPending = false
        }
        requestCount += 1
        status = grantOnRequest ? .authorized : .denied
        return grantOnRequest
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        if holdAuthorizationStatus {
            holdAuthorizationStatus = false
            authorizationStatusPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                authorizationStatusContinuations.append(continuation)
            }
            authorizationStatusPending = false
        }
        return status
    }

    func pendingRequestIDs() async -> [String] { added.map(\.identifier) }

    /// One-shot gate: the next `authorizationStatus()` call suspends until
    /// `releaseAuthorizationStatus()` is called, simulating an in-flight
    /// authorization check (e.g. `isAuthorized()` during `load()`).
    var holdAuthorizationStatus = false
    private(set) var authorizationStatusPending = false
    private var authorizationStatusContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseAuthorizationStatus() {
        let continuations = authorizationStatusContinuations
        authorizationStatusContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    /// One-shot gate: the next `requestAuthorization()` call suspends until
    /// `releaseRequestAuthorization()` is called, simulating a permission prompt
    /// the user hasn't answered yet.
    var holdRequestAuthorization = false
    private(set) var requestAuthorizationPending = false
    private var requestAuthorizationContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseRequestAuthorization() {
        let continuations = requestAuthorizationContinuations
        requestAuthorizationContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }
}

/// In-memory SessionRepository with the same rules as KickStore.
@MainActor
final class FakeSessionRepository: SessionRepository {
    struct WriteFailed: Error {}

    private(set) var sessions: [UUID: SessionState] = [:]
    private var activeID: UUID?
    var failNextWrite = false
    var failNextCancel = false

    func activeSession() throws -> SessionRecord? {
        guard let id = activeID, let state = sessions[id] else { return nil }
        return SessionRecord(id: id, state: state)
    }

    func addKick(at now: Date) throws -> KickResult {
        if failNextWrite {
            failNextWrite = false
            throw WriteFailed()
        }
        var didStart = false
        if activeID == nil {
            let id = UUID()
            sessions[id] = SessionState(startedAt: now)
            activeID = id
            didStart = true
        }
        let id = activeID!
        var state = sessions[id]!
        let outcome = SessionEngine.addKick(to: &state, at: now)
        sessions[id] = state
        if state.status != .active { activeID = nil }
        return KickResult(record: SessionRecord(id: id, state: state), outcome: outcome, didStartSession: didStart)
    }

    func undoLastKick() throws -> SessionRecord? {
        guard let id = activeID, var state = sessions[id] else { return nil }
        SessionEngine.undoLastKick(&state)
        sessions[id] = state
        return SessionRecord(id: id, state: state)
    }

    func cancelActive(at now: Date) throws -> SessionRecord? {
        if failNextCancel {
            failNextCancel = false
            throw WriteFailed()
        }
        guard let id = activeID, var state = sessions[id] else { return nil }
        SessionEngine.cancel(&state, at: now)
        sessions[id] = state
        activeID = nil
        return SessionRecord(id: id, state: state)
    }
}

@MainActor
final class FakeLiveActivities: LiveActivityManaging {
    var isAvailable = true
    var activeIDs: Set<UUID> = []
    var started: [(id: UUID, startedAt: Date, count: Int)] = []
    /// Calls that found an activity for that session and were applied.
    var updates: [(sessionID: UUID, count: Int, completedAt: Date?)] = []
    var ended: [(sessionID: UUID, dismissAfter: TimeInterval)] = []
    /// Calls that found no activity for that session and were dropped (no-op).
    var droppedUpdates: [(sessionID: UUID, count: Int, completedAt: Date?)] = []
    var droppedEnds: [(sessionID: UUID, dismissAfter: TimeInterval)] = []
    var endAllCount = 0

    /// One-shot gate: the next `start(...)` call suspends until `releaseStart()`
    /// is called, simulating an in-flight ActivityKit request.
    var holdStart = false
    private(set) var startPending = false
    private var startContinuations: [CheckedContinuation<Void, Never>] = []

    func hasActivity(for sessionID: UUID) -> Bool { activeIDs.contains(sessionID) }

    func start(sessionID: UUID, startedAt: Date, count: Int) async {
        if holdStart {
            holdStart = false
            startPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                startContinuations.append(continuation)
            }
            startPending = false
        }
        activeIDs = activeIDs.filter { $0 == sessionID } // ending activities of any other session
        activeIDs.insert(sessionID)
        started.append((sessionID, startedAt, count))
    }

    func releaseStart() {
        let continuations = startContinuations
        startContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    /// One-shot gate: the next `update(...)` call suspends until `releaseUpdate()`
    /// is called, simulating an in-flight ActivityKit update.
    var holdUpdate = false
    private(set) var updatePending = false
    private var updateContinuations: [CheckedContinuation<Void, Never>] = []

    func update(sessionID: UUID, count: Int, completedAt: Date?) async {
        if holdUpdate {
            holdUpdate = false
            updatePending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                updateContinuations.append(continuation)
            }
            updatePending = false
        }
        guard activeIDs.contains(sessionID) else {
            droppedUpdates.append((sessionID, count, completedAt))
            return
        }
        updates.append((sessionID, count, completedAt))
    }

    func releaseUpdate() {
        let continuations = updateContinuations
        updateContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    func end(sessionID: UUID, dismissAfter: TimeInterval) async {
        guard activeIDs.contains(sessionID) else {
            droppedEnds.append((sessionID, dismissAfter))
            return
        }
        ended.append((sessionID, dismissAfter))
        activeIDs.remove(sessionID)
    }

    func endAll() async {
        if holdEndAll {
            holdEndAll = false
            endAllPending = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                endAllContinuations.append(continuation)
            }
            endAllPending = false
        }
        endAllCount += 1
        activeIDs.removeAll()
    }

    /// One-shot gate: the next `endAll()` call suspends until `releaseEndAll()`
    /// is called, simulating an in-flight ActivityKit request.
    var holdEndAll = false
    private(set) var endAllPending = false
    private var endAllContinuations: [CheckedContinuation<Void, Never>] = []

    func releaseEndAll() {
        let continuations = endAllContinuations
        endAllContinuations.removeAll()
        for continuation in continuations { continuation.resume() }
    }
}

@MainActor
final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

struct MissingFixture: Error {
    let name: String
}

/// Decodes `Tests/KickCoreTests/Fixtures/<name>.json`.
func fixtureContent(_ name: String = "content-fixture") throws -> PregnancyContent {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
        throw MissingFixture(name: name)
    }
    return try JSONDecoder().decode(PregnancyContent.self, from: Data(contentsOf: url))
}

/// In-memory AppointmentRepository with the same rules as AppointmentStore.
@MainActor
final class FakeAppointmentRepository: AppointmentRepository {
    struct Failed: Error {}

    private(set) var appointments: [UUID: AppointmentRecord] = [:]
    var calendar = utcCalendar
    var failNextRead = false
    var failNextWrite = false

    func seed(_ records: AppointmentRecord...) {
        for record in records { appointments[record.id] = record }
    }

    private func checkRead() throws {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
    }

    private func checkWrite() throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
    }

    func appointment(id: UUID) throws -> AppointmentRecord? {
        try checkRead()
        return appointments[id]
    }

    func upcoming(now: Date) throws -> [AppointmentRecord] {
        try checkRead()
        return AppointmentRules.upcoming(Array(appointments.values), now: now, calendar: calendar)
    }

    func past(now: Date) throws -> [AppointmentRecord] {
        try checkRead()
        return AppointmentRules.past(Array(appointments.values), now: now, calendar: calendar)
    }

    func add(_ appointment: AppointmentRecord) throws {
        try checkWrite()
        appointments[appointment.id] = appointment
    }

    func update(_ appointment: AppointmentRecord) throws {
        try checkWrite()
        guard appointments[appointment.id] != nil else { throw AppointmentRepositoryError.notFound }
        appointments[appointment.id] = appointment
    }

    func delete(id: UUID) throws {
        try checkWrite()
        appointments[id] = nil
    }

    func markDone(id: UUID) throws -> AppointmentRecord? {
        try checkWrite()
        guard var appointment = appointments[id] else { return nil }
        appointment.isDone = true
        appointments[id] = appointment
        return appointment
    }
}

/// A fresh, empty defaults domain (one per call).
func makeTestDefaults() -> UserDefaults {
    let name = "KickCoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}


/// In-memory CycleRepository with the same rules as CycleStore.
@MainActor
final class FakeCycleRepository: CycleRepository {
    struct Failed: Error {}

    private(set) var storedPeriods: [PeriodRecord] = []
    private(set) var storedLogs: [CycleLogRecord] = []
    var calendar = utcCalendar
    var failNextRead = false
    var failNextWrite = false
    /// One-shot: the next `logs()` call throws (after `periods()` succeeded).
    var failNextLogsRead = false

    func seed(periods: [PeriodRecord] = [], logs: [CycleLogRecord] = []) {
        storedPeriods += periods
        storedLogs += logs
    }

    private func checkRead() throws {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
    }

    private func checkWrite() throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
    }

    private(set) var periodReads = 0

    func periods() throws -> [PeriodRecord] {
        try checkRead()
        periodReads += 1
        let merged = CycleRules.mergingDuplicates(storedPeriods, calendar: calendar)
        storedPeriods = merged.periods
        return merged.periods
    }

    func logs() throws -> [CycleLogRecord] {
        try checkRead()
        if failNextLogsRead {
            failNextLogsRead = false
            throw Failed()
        }
        let merged = CycleRules.mergingDuplicates(storedLogs, calendar: calendar)
        storedLogs = merged.logs
        return merged.logs
    }

    func addPeriod(_ period: PeriodRecord, today: Date) throws {
        try CycleRules.validate(period, existing: storedPeriods, today: today, calendar: calendar)
        try checkWrite()
        storedPeriods.append(CycleRules.normalized(period, calendar: calendar))
    }

    func updatePeriod(_ period: PeriodRecord, today: Date) throws {
        guard let index = storedPeriods.firstIndex(where: { $0.id == period.id }) else {
            throw CycleRepositoryError.notFound
        }
        try CycleRules.validate(period, existing: storedPeriods, today: today, calendar: calendar)
        try checkWrite()
        storedPeriods[index] = CycleRules.normalized(period, calendar: calendar)
    }

    func deletePeriod(id: UUID) throws {
        try checkWrite()
        storedPeriods.removeAll { $0.id == id }
    }

    func saveLog(_ log: CycleLogRecord, today: Date) throws {
        let normalized = CycleRules.normalized(log, calendar: calendar)
        try CycleRules.validate(normalized, today: today, calendar: calendar)
        try checkWrite()
        let existing = storedLogs.first { $0.day == normalized.day }
        storedLogs.removeAll { $0.day == normalized.day }
        guard !normalized.isEmpty else { return }
        storedLogs.append(existing.map { normalized.withID($0.id) } ?? normalized)
    }
}

/// In-memory WeightRepository with the same rules as WeightStore.
@MainActor
final class FakeWeightRepository: WeightRepository {
    struct Failed: Error {}

    private(set) var stored: [WeightRecord] = []
    var calendar = utcCalendar
    var failNextRead = false
    var failNextWrite = false
    private(set) var reads = 0

    func seed(_ entries: WeightRecord...) {
        stored += entries
    }

    func entries() throws -> [WeightRecord] {
        if failNextRead {
            failNextRead = false
            throw Failed()
        }
        reads += 1
        let merged = WeightRules.mergingDuplicates(stored, calendar: calendar)
        stored = merged.entries
        return merged.entries
    }

    func save(_ entry: WeightRecord, today: Date) throws {
        try WeightRules.validate(entry, today: today, calendar: calendar)
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        let normalized = WeightRules.normalized(entry, calendar: calendar)
        if let index = stored.firstIndex(where: { $0.day == normalized.day }) {
            stored[index].kg = normalized.kg
        } else {
            stored.append(normalized)
        }
    }

    func delete(id: UUID) throws {
        if failNextWrite {
            failNextWrite = false
            throw Failed()
        }
        stored.removeAll { $0.id == id }
    }
}
