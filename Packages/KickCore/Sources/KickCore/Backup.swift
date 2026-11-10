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
    /// Marked pills (phase 17). Optional in the file: missing means none, and an
    /// empty list is not written, so version 1 files stay as they were.
    public var pillDoses: [PillDoseDTO] = []
    /// Timed contractions (phase 20). Optional in the file like `pillDoses`:
    /// missing means none, and an empty list is not written.
    public var contractions: [ContractionDTO] = []
    /// Hospital bag overrides and custom items, and questions for the doctor (1.1).
    /// Optional in the file like `pillDoses`: missing means none, and an empty list is not written.
    public var checklistItems: [ChecklistItemDTO] = []
    /// Labour markers such as "Vỡ ối" (edit spec 2026-11-06). Optional in the
    /// file like `contractions`: missing means none, and an empty list is not written.
    public var labourMarkers: [LabourMarkerDTO] = []
    /// Kept pregnancy journeys (1.1 item 4). Optional in the file like
    /// `contractions`: missing means none, and an empty list is not written.
    public var pregnancyMemories: [PregnancyMemoryDTO] = []
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
        case format, version, createdAt, appVersion, sessions, appointments, periods, cycleLogs, weights, pillDoses, contractions, checklistItems, labourMarkers, pregnancyMemories, settings
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
        pillDoses = try container.decodeIfPresent([PillDoseDTO].self, forKey: .pillDoses) ?? []
        contractions = try container.decodeIfPresent([ContractionDTO].self, forKey: .contractions) ?? []
        checklistItems = try container.decodeIfPresent([ChecklistItemDTO].self, forKey: .checklistItems) ?? []
        labourMarkers = try container.decodeIfPresent([LabourMarkerDTO].self, forKey: .labourMarkers) ?? []
        pregnancyMemories = try container.decodeIfPresent([PregnancyMemoryDTO].self, forKey: .pregnancyMemories) ?? []
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
        if !pillDoses.isEmpty {
            try container.encode(pillDoses, forKey: .pillDoses)
        }
        if !contractions.isEmpty {
            try container.encode(contractions, forKey: .contractions)
        }
        if !checklistItems.isEmpty {
            try container.encode(checklistItems, forKey: .checklistItems)
        }
        if !labourMarkers.isEmpty {
            try container.encode(labourMarkers, forKey: .labourMarkers)
        }
        if !pregnancyMemories.isEmpty {
            try container.encode(pregnancyMemories, forKey: .pregnancyMemories)
        }
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
    /// 1.2, written only when set (a 1.1 file has none of them). Raw values, as stored.
    public var spotting: Bool?
    public var sex: String?
    public var sexDrive: String?
    public var pregnancyTest: String?

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
        spotting = record.spotting ? true : nil
        sex = record.sex?.rawValue
        sexDrive = record.sexDrive?.rawValue
        pregnancyTest = record.pregnancyTest?.rawValue
    }

    /// The record with the stored raw single values, which may be values this
    /// build cannot read (the record drops them).
    public init(
        _ record: CycleLogRecord, lhRaw: String?, mucusRaw: String?, flowRaw: String?,
        sexRaw: String? = nil, sexDriveRaw: String? = nil, pregnancyTestRaw: String? = nil
    ) {
        self.init(record)
        lh = lhRaw
        mucus = mucusRaw
        flow = flowRaw
        sex = sexRaw
        sexDrive = sexDriveRaw
        pregnancyTest = pregnancyTestRaw
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
            spotting: spotting ?? false,
            sex: sex.flatMap(SexLog.init(rawValue:)),
            sexDrive: sexDrive.flatMap(SexDrive.init(rawValue:)),
            pregnancyTest: pregnancyTest.flatMap(PregnancyTestResult.init(rawValue:)),
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

/// A marked pill. Written with `dayKey` (yyyymmdd, a calendar date); files
/// from earlier builds of this branch carry `day` (an instant) instead, read
/// as its local day.
public struct PillDoseDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var dayKey: Int
    public var takenAt: Date

    public init(_ record: PillDoseRecord) {
        id = record.id
        dayKey = record.day.key
        takenAt = record.takenAt
    }

    /// Nil when `dayKey` is not a real date (validation skips it).
    public var calendarDay: CalendarDay? { CalendarDay(key: dayKey) }

    public var record: PillDoseRecord {
        PillDoseRecord(id: id, day: calendarDay ?? CalendarDay(takenAt, calendar: .autoupdatingCurrent), takenAt: takenAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, dayKey, day, takenAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        takenAt = try container.decode(Date.self, forKey: .takenAt)
        if let key = try container.decodeIfPresent(Int.self, forKey: .dayKey) {
            dayKey = key
        } else {
            let day = try container.decode(Date.self, forKey: .day)
            dayKey = CalendarDay(day, calendar: .autoupdatingCurrent).key
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(dayKey, forKey: .dayKey)
        try container.encode(takenAt, forKey: .takenAt)
    }
}

/// A timed contraction; `endedAt` is missing while it runs.
public struct ContractionDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?

    public init(_ record: ContractionRecord) {
        id = record.id
        startedAt = record.startedAt
        endedAt = record.endedAt
    }

    public var record: ContractionRecord {
        ContractionRecord(id: id, startedAt: startedAt, endedAt: endedAt)
    }
}

/// A labour marker; `kind` is the raw value, kept as written.
public struct LabourMarkerDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var kind: String
    public var at: Date

    public init(_ record: LabourMarkerRecord) {
        id = record.id
        kind = record.kind
        at = record.at
    }

    public var record: LabourMarkerRecord {
        LabourMarkerRecord(id: id, kind: kind, at: at)
    }
}

/// A kept pregnancy journey. The payload travels as its stored bytes (base64), so
/// the round trip is lossless whatever the content (even one this build cannot read).
public struct PregnancyMemoryDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var createdAt: Date
    public var title: String
    public var branch: String
    public var payload: Data

    public init(_ stored: StoredPregnancyMemory) {
        id = stored.id
        createdAt = stored.createdAt
        title = stored.title
        branch = stored.branchRaw
        payload = stored.payload
    }

    public var stored: StoredPregnancyMemory {
        StoredPregnancyMemory(id: id, createdAt: createdAt, title: title, branchRaw: branch, payload: payload)
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
    public var pillDoses: [PillDoseRecord]
    public var contractions: [ContractionRecord]
    public var checklistItems: [ChecklistItemRecord]
    public var labourMarkers: [LabourMarkerRecord]
    public var pregnancyMemories: [StoredPregnancyMemory]

    public init(
        sessions: [SessionRecord],
        appointments: [AppointmentRecord],
        periods: [PeriodRecord],
        logs: [CycleLogDTO],
        weights: [WeightRecord],
        pillDoses: [PillDoseRecord] = [],
        contractions: [ContractionRecord] = [],
        checklistItems: [ChecklistItemRecord] = [],
        labourMarkers: [LabourMarkerRecord] = [],
        pregnancyMemories: [StoredPregnancyMemory] = []
    ) {
        self.sessions = sessions
        self.appointments = appointments
        self.periods = periods
        self.logs = logs
        self.weights = weights
        self.pillDoses = pillDoses
        self.contractions = contractions
        self.checklistItems = checklistItems
        self.labourMarkers = labourMarkers
        self.pregnancyMemories = pregnancyMemories
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
        pillDoses = records.pillDoses.map(PillDoseDTO.init)
        contractions = records.contractions.map(ContractionDTO.init)
        checklistItems = records.checklistItems.map(ChecklistItemDTO.init)
        labourMarkers = records.labourMarkers.map(LabourMarkerDTO.init)
        pregnancyMemories = records.pregnancyMemories.map(PregnancyMemoryDTO.init)
    }

    public var records: BackupRecords {
        BackupRecords(
            sessions: sessions.map(\.record),
            appointments: appointments.map(\.record),
            periods: periods.map(\.record),
            logs: cycleLogs,
            weights: weights.map(\.record),
            pillDoses: pillDoses.map(\.record),
            contractions: contractions.map(\.record),
            checklistItems: checklistItems.map(\.record),
            labourMarkers: labourMarkers.map(\.record),
            pregnancyMemories: pregnancyMemories.map(\.stored)
        )
    }
}
