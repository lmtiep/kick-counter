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

    /// Larger files are refused before they are parsed (a real backup is far smaller).
    public static let maxFileSize = 20 * 1024 * 1024

    /// Never touches any data: it only reads `data`. Unknown extra fields are ignored.
    /// A valid file is parsed once; only a file that fails is read again, for its
    /// header, to say why.
    public static func decode(_ data: Data) throws -> BackupDocument {
        guard data.count <= maxFileSize else { throw BackupError.corrupt }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parseDate(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date: \(text)")
            }
            return date
        }
        if let document = try? decoder.decode(BackupDocument.self, from: data) {
            try check(format: document.format, version: document.version)
            return document
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw BackupError.corrupt }
        try check(format: header.format, version: header.version)
        throw BackupError.corrupt
    }

    private static func check(format: String?, version: Int?) throws {
        guard format == BackupFormat.name else { throw BackupError.notABackup }
        guard let version, version >= 1 else { throw BackupError.corrupt }
        guard version <= BackupFormat.version else { throw BackupError.newerVersion(version) }
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
    public var pillDoses: Int = 0
    public var contractions: Int = 0
    /// The file's `appMode`; missing means pregnant, as in `AppMode.load`.
    public var mode: AppMode
    /// From the earliest to the latest date in the records; nil without records.
    public var dateRange: ClosedRange<Date>?

    public var isEmpty: Bool {
        sessions + appointments + periods + cycleLogs + weights + pillDoses + contractions == 0
    }
}

extension BackupDocument {
    public var summary: BackupSummary {
        var dates: [Date] = sessions.map(\.startedAt) + appointments.map(\.date) + cycleLogs.map(\.day) + weights.map(\.day)
        dates += pillDoses.compactMap { $0.calendarDay?.date(in: .autoupdatingCurrent) }
        dates += contractions.map(\.startedAt)
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
            pillDoses: pillDoses.count,
            contractions: contractions.count,
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
        // One log and one weight per day, as the stores keep them: the last in the file wins.
        func lastPerDay<DTO>(_ items: [DTO], day: (DTO) -> Date) -> [DTO] {
            var lastIndex: [Date: Int] = [:]
            for (index, item) in items.enumerated() {
                lastIndex[calendar.startOfDay(for: day(item))] = index
            }
            let kept = items.enumerated().filter { lastIndex[calendar.startOfDay(for: day($0.element))] == $0.offset }
            skipped += items.count - kept.count
            return kept.map(\.element)
        }
        cleaned.cycleLogs = lastPerDay(keep(document.cycleLogs, id: \.id) {
            (try? CycleRules.validate($0.record, today: now, calendar: calendar)) != nil
        }, day: \.day)
        cleaned.weights = lastPerDay(keep(document.weights, id: \.id) {
            (try? WeightRules.validate($0.record, today: now, calendar: calendar)) != nil
        }, day: \.day)
        // One dose per calendar day; a day after today or not a real date is skipped.
        let doses = keep(document.pillDoses, id: \.id) { dto in
            dto.calendarDay.map { (try? PillDoseRules.dose(on: $0, takenAt: now, calendar: calendar)) != nil } ?? false
        }
        var lastDose: [Int: Int] = [:]
        for (index, dto) in doses.enumerated() { lastDose[dto.dayKey] = index }
        cleaned.pillDoses = doses.enumerated().filter { lastDose[$0.element.dayKey] == $0.offset }.map(\.element)
        skipped += doses.count - cleaned.pillDoses.count
        // A contraction cannot start in the future, end before it starts or be
        // a mis-tap; only the newest may still run (`ContractionRules`).
        let contractions = keep(document.contractions, id: \.id) { dto in
            dto.startedAt <= now && (dto.endedAt.map { $0 >= dto.startedAt } ?? true) && !ContractionRules.isMisTap(dto.record)
        }
        let newestRunning = contractions.filter { $0.endedAt == nil }.max { $0.startedAt < $1.startedAt }
        let newestStart = contractions.map(\.startedAt).max()
        cleaned.contractions = contractions.map { dto in
            guard dto.endedAt == nil, dto.id != newestRunning?.id || dto.startedAt != newestStart else { return dto }
            return ContractionDTO(ContractionRules.closingForgotten(dto.record))
        }
        cleaned.appointments = keep(document.appointments, id: \.id) {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // A session cannot start in the future or end before it starts; kicks
        // after now cannot have happened and are dropped.
        let sessions = keep(document.sessions, id: \.id) { dto in
            dto.startedAt <= now && (dto.endedAt.map { $0 >= dto.startedAt } ?? true)
        }.map { dto in
            guard dto.kicks.contains(where: { $0 > now }) else { return dto }
            var trimmed = dto
            trimmed.kicks = dto.kicks.filter { $0 <= now }
            return trimmed
        }
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
