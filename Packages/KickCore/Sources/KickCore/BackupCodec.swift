import Foundation

public enum BackupError: Error, Equatable, Sendable {
    /// Not a Luna Mom backup (wrong or missing `format`).
    case notABackup
    /// Made by a newer Luna Mom (`version` greater than this build reads).
    case newerVersion(Int)
    /// Not JSON, or a required field is missing or of the wrong type.
    case corrupt
}

/// Reads and writes `.lunamom` files. Dates are ISO 8601 with fractional seconds.
public enum BackupCodec {
    /// Pretty-printed JSON with sorted keys.
    public static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatDate(date))
        }
        return try encoder.encode(document)
    }

    /// Never touches any data: it only reads `data`. Unknown extra fields are ignored.
    public static func decode(_ data: Data) throws -> BackupDocument {
        let header: Header
        do {
            header = try JSONDecoder().decode(Header.self, from: data)
        } catch {
            throw BackupError.corrupt
        }
        guard header.format == BackupFormat.name else { throw BackupError.notABackup }
        guard let version = header.version, version >= 1 else { throw BackupError.corrupt }
        guard version <= BackupFormat.version else { throw BackupError.newerVersion(version) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parseDate(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date: \(text)")
            }
            return date
        }
        do {
            return try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw BackupError.corrupt
        }
    }

    static func formatDate(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    /// With or without fractional seconds.
    static func parseDate(_ text: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) {
            return date
        }
        return try? Date.ISO8601FormatStyle().parse(text)
    }

    private struct Header: Decodable {
        var format: String?
        var version: Int?
    }
}

/// What the restore sheet shows before anything is replaced (spec §4.2).
public struct BackupSummary: Equatable, Sendable {
    public var createdAt: Date
    public var sessions: Int
    public var appointments: Int
    public var periods: Int
    public var cycleLogs: Int
    public var weights: Int
    /// The file's `appMode`; missing means pregnant, as in `AppMode.load`.
    public var mode: AppMode
    /// From the earliest to the latest date in the records; nil without records.
    public var dateRange: ClosedRange<Date>?

    public var isEmpty: Bool {
        sessions + appointments + periods + cycleLogs + weights == 0
    }
}

extension BackupDocument {
    public var summary: BackupSummary {
        var dates: [Date] = sessions.map(\.startedAt) + appointments.map(\.date) + cycleLogs.map(\.day) + weights.map(\.day)
        dates += periods.map(\.startDate) + periods.compactMap(\.endDate)
        let mode: AppMode = if case .string(let raw) = settings[SettingsKey.appMode] {
            AppMode(rawValue: raw) ?? .pregnant
        } else {
            .pregnant
        }
        return BackupSummary(
            createdAt: createdAt,
            sessions: sessions.count,
            appointments: appointments.count,
            periods: periods.count,
            cycleLogs: cycleLogs.count,
            weights: weights.count,
            mode: mode,
            dateRange: dates.min().flatMap { first in dates.max().map { first...$0 } }
        )
    }
}

/// Spec §3 "Validation before replacing": every record goes through the rules the
/// app applies when it is entered. Invalid ones are skipped and counted, never fatal.
public enum BackupValidation {
    public static func clean(_ document: BackupDocument, now: Date, calendar: Calendar) -> (BackupDocument, skipped: Int) {
        var skipped = 0
        func keep<DTO>(_ items: [DTO], id: (DTO) -> UUID, isValid: (DTO) -> Bool) -> [DTO] {
            var seen = Set<UUID>()
            return items.filter { item in
                guard isValid(item), seen.insert(id(item)).inserted else {
                    skipped += 1
                    return false
                }
                return true
            }
        }

        var cleaned = document
        // Overlapping periods are kept as in the file: each is checked on its own.
        cleaned.periods = keep(document.periods, id: \.id) {
            (try? CycleRules.validate($0.record, existing: [], today: now, calendar: calendar)) != nil
        }
        cleaned.cycleLogs = keep(document.cycleLogs, id: \.id) {
            (try? CycleRules.validate($0.record, today: now, calendar: calendar)) != nil
        }
        cleaned.weights = keep(document.weights, id: \.id) {
            (try? WeightRules.validate($0.record, today: now, calendar: calendar)) != nil
        }
        cleaned.appointments = keep(document.appointments, id: \.id) {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let sessions = keep(document.sessions, id: \.id) { $0.startedAt <= now }
        cleaned.sessions = closingStaleActiveSessions(sessions, now: now)
        return (cleaned, skipped)
    }

    /// At most one session stays active, the newest, and only while it is not
    /// abandoned (`SessionEngine.isAbandoned`); the others are cancelled at their
    /// last kick (or their start without kicks).
    private static func closingStaleActiveSessions(_ sessions: [SessionDTO], now: Date) -> [SessionDTO] {
        let newestActive = sessions
            .filter { $0.record.state.status == .active }
            .max { $0.startedAt < $1.startedAt }
        return sessions.map { dto in
            var state = dto.record.state
            guard state.status == .active else { return dto }
            if dto.id == newestActive?.id, !SessionEngine.isAbandoned(state, now: now) { return dto }
            SessionEngine.cancel(&state, at: state.kicks.last ?? state.startedAt)
            return SessionDTO(SessionRecord(id: dto.id, state: state))
        }
    }
}
