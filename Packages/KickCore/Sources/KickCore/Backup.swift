import Foundation

/// The `.lunamom` backup file (phase 15 spec §3): versioned JSON with every record
/// and the owned settings. DTOs, not the records, are encoded, so storage types can
/// change without breaking old files.
public enum BackupFormat {
    public static let name = "luna-mom-backup"
    public static let version = 1
    public static let fileExtension = "lunamom"
    /// The exported UTType (`project.yml`), conforming to `public.json`.
    public static let typeIdentifier = "com.lmtiep.kickcounter.backup"
}

public struct BackupDocument: Equatable, Sendable, Codable {
    public var format: String
    public var version: Int
    public var createdAt: Date
    public var appVersion: String
    public var sessions: [SessionDTO]
    public var appointments: [AppointmentDTO]
    public var periods: [PeriodDTO]
    public var cycleLogs: [CycleLogDTO]
    public var weights: [WeightDTO]
    /// Typed by `BackupSettings.table`; keys outside the table are dropped on decode.
    public var settings: [String: BackupValue]

    public init(
        createdAt: Date,
        appVersion: String,
        sessions: [SessionRecord],
        appointments: [AppointmentRecord],
        periods: [PeriodRecord],
        cycleLogs: [CycleLogRecord],
        weights: [WeightRecord],
        settings: [String: BackupValue]
    ) {
        format = BackupFormat.name
        version = BackupFormat.version
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.sessions = sessions.map(SessionDTO.init)
        self.appointments = appointments.map(AppointmentDTO.init)
        self.periods = periods.map(PeriodDTO.init)
        self.cycleLogs = cycleLogs.map(CycleLogDTO.init)
        self.weights = weights.map(WeightDTO.init)
        self.settings = settings
    }

    /// "LunaMom-2026-10-09.lunamom", for the local day of `date`.
    public static func fileName(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "LunaMom-\(day).\(BackupFormat.fileExtension)"
    }

    private enum CodingKeys: String, CodingKey {
        case format, version, createdAt, appVersion, sessions, appointments, periods, cycleLogs, weights, settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(String.self, forKey: .format)
        version = try container.decode(Int.self, forKey: .version)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        sessions = try container.decode([SessionDTO].self, forKey: .sessions)
        appointments = try container.decode([AppointmentDTO].self, forKey: .appointments)
        periods = try container.decode([PeriodDTO].self, forKey: .periods)
        cycleLogs = try container.decode([CycleLogDTO].self, forKey: .cycleLogs)
        weights = try container.decode([WeightDTO].self, forKey: .weights)
        let raw = try container.decode([String: BackupJSONScalar].self, forKey: .settings)
        settings = BackupSettings.typed(raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(version, forKey: .version)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(appointments, forKey: .appointments)
        try container.encode(periods, forKey: .periods)
        try container.encode(cycleLogs, forKey: .cycleLogs)
        try container.encode(weights, forKey: .weights)
        try container.encode(settings, forKey: .settings)
    }
}

// MARK: - DTOs

public struct SessionDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    /// `SessionStatus.rawValue`; an unknown value reads as cancelled, like the store.
    public var status: String
    public var exceededThreshold: Bool
    public var kicks: [Date]

    public init(_ record: SessionRecord) {
        id = record.id
        startedAt = record.state.startedAt
        endedAt = record.state.endedAt
        status = record.state.status.rawValue
        exceededThreshold = record.state.exceededThreshold
        kicks = record.state.kicks
    }

    public var record: SessionRecord {
        SessionRecord(id: id, state: SessionState(
            startedAt: startedAt,
            kicks: kicks.sorted(),
            status: SessionStatus(rawValue: status) ?? .cancelled,
            endedAt: endedAt,
            exceededThreshold: exceededThreshold
        ))
    }
}

public struct AppointmentDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var date: Date
    public var title: String
    public var note: String
    public var isDone: Bool
    public var milestoneID: String?

    public init(_ record: AppointmentRecord) {
        id = record.id
        date = record.date
        title = record.title
        note = record.note
        isDone = record.isDone
        milestoneID = record.milestoneID
    }

    public var record: AppointmentRecord {
        AppointmentRecord(id: id, date: date, title: title, note: note, isDone: isDone, milestoneID: milestoneID)
    }
}

public struct PeriodDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var startDate: Date
    public var endDate: Date?

    public init(_ record: PeriodRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
    }

    public var record: PeriodRecord {
        PeriodRecord(id: id, startDate: startDate, endDate: endDate)
    }
}

public struct CycleLogDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var day: Date
    /// Raw values, as stored: one this build does not know is kept and written back.
    public var lh: String?
    public var bbtCelsius: Double?
    public var mucus: String?
    public var note: String
    public var flow: String?
    public var moods: [String]
    public var symptoms: [String]
    /// Values this build does not know, kept so nothing is lost.
    public var unknownMoods: [String]
    public var unknownSymptoms: [String]

    public init(_ record: CycleLogRecord) {
        id = record.id
        day = record.day
        lh = record.lh?.rawValue
        bbtCelsius = record.bbtCelsius
        mucus = record.mucus?.rawValue
        note = record.note
        flow = record.flow?.rawValue
        moods = record.moods.map(\.rawValue)
        symptoms = record.symptoms.map(\.rawValue)
        unknownMoods = record.unknownMoodsRaw
        unknownSymptoms = record.unknownSymptomsRaw
    }

    /// The record with the stored raw LH, mucus and flow values, which may be
    /// values this build cannot read (the record drops them).
    public init(_ record: CycleLogRecord, lhRaw: String?, mucusRaw: String?, flowRaw: String?) {
        self.init(record)
        lh = lhRaw
        mucus = mucusRaw
        flow = flowRaw
    }

    /// A mood or symptom this build cannot read joins the unknown list.
    public var record: CycleLogRecord {
        CycleLogRecord(
            id: id,
            day: day,
            lh: lh.flatMap(LHResult.init(rawValue:)),
            bbtCelsius: bbtCelsius,
            mucus: mucus.flatMap(CervicalMucus.init(rawValue:)),
            note: note,
            flow: flow.flatMap(MenstrualFlow.init(rawValue:)),
            moods: moods.compactMap(Mood.init(rawValue:)),
            symptoms: symptoms.compactMap(Symptom.init(rawValue:)),
            unknownMoodsRaw: unknownMoods + moods.filter { Mood(rawValue: $0) == nil },
            unknownSymptomsRaw: unknownSymptoms + symptoms.filter { Symptom(rawValue: $0) == nil }
        )
    }
}

public struct WeightDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var day: Date
    public var kg: Double

    public init(_ record: WeightRecord) {
        id = record.id
        day = record.day
        kg = record.kg
    }

    public var record: WeightRecord {
        WeightRecord(id: id, day: day, kg: kg)
    }
}

// MARK: - Records

/// Every record a backup carries, as the stores hold them (`BackupStore` in KickData).
/// Day logs stay DTOs so raw values this build cannot read travel unchanged.
public struct BackupRecords: Equatable, Sendable {
    public var sessions: [SessionRecord]
    public var appointments: [AppointmentRecord]
    public var periods: [PeriodRecord]
    public var logs: [CycleLogDTO]
    public var weights: [WeightRecord]

    public init(
        sessions: [SessionRecord],
        appointments: [AppointmentRecord],
        periods: [PeriodRecord],
        logs: [CycleLogDTO],
        weights: [WeightRecord]
    ) {
        self.sessions = sessions
        self.appointments = appointments
        self.periods = periods
        self.logs = logs
        self.weights = weights
    }
}

extension BackupDocument {
    public init(createdAt: Date, appVersion: String, records: BackupRecords, settings: [String: BackupValue]) {
        self.init(
            createdAt: createdAt, appVersion: appVersion,
            sessions: records.sessions, appointments: records.appointments, periods: records.periods,
            cycleLogs: [], weights: records.weights, settings: settings
        )
        cycleLogs = records.logs
    }

    public var records: BackupRecords {
        BackupRecords(
            sessions: sessions.map(\.record),
            appointments: appointments.map(\.record),
            periods: periods.map(\.record),
            logs: cycleLogs,
            weights: weights.map(\.record)
        )
    }
}
