import Foundation
import KickCore
import SwiftData

// CloudKit-compatible: every attribute has a default or is optional,
// relationships are optional, and no unique constraints are used.

@Model
public final class KickSession {
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var endedAt: Date?
    public var targetCount: Int = 10
    public var statusRaw: String = "active"
    public var exceededThreshold: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Kick.session)
    public var kicks: [Kick]? = []

    public init(id: UUID = UUID(), startedAt: Date) {
        self.id = id
        self.startedAt = startedAt
    }

    public var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .cancelled }
        set { statusRaw = newValue.rawValue }
    }

    public var state: SessionState {
        SessionState(
            startedAt: startedAt,
            kicks: (kicks ?? []).map(\.timestamp).sorted(),
            status: status,
            endedAt: endedAt,
            exceededThreshold: exceededThreshold
        )
    }

    public var record: SessionRecord {
        SessionRecord(id: id, state: state)
    }
}

@Model
public final class Kick {
    public var timestamp: Date = Date()
    public var session: KickSession?

    public init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

/// A check-up the mother added. Synced through iCloud like sessions.
@Model
public final class Appointment {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var title: String = ""
    public var note: String = ""
    public var isDone: Bool = false
    /// Id of the suggested milestone this was created from, if any.
    public var milestoneID: String?

    public init(record: AppointmentRecord) {
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

    func apply(_ record: AppointmentRecord) {
        date = record.date
        title = record.title
        note = record.note
        isDone = record.isDone
        milestoneID = record.milestoneID
    }
}

/// A logged period. Synced through iCloud; `CycleStore` merges overlapping
/// duplicates that sync can create.
@Model
public final class PeriodEntry {
    public var id: UUID = UUID()
    /// Start of the first day.
    public var startDate: Date = Date()
    /// Start of the last day; nil while the period is still going on.
    public var endDate: Date?

    public init(record: PeriodRecord) {
        id = record.id
        startDate = record.startDate
        endDate = record.endDate
    }

    public var record: PeriodRecord {
        PeriodRecord(id: id, startDate: startDate, endDate: endDate)
    }

    func apply(_ record: PeriodRecord) {
        startDate = record.startDate
        endDate = record.endDate
    }
}

/// Body signals for one day. At most one per day (kept so by `CycleStore`).
@Model
public final class CycleLog {
    public var id: UUID = UUID()
    /// Start of the day.
    public var day: Date = Date()
    /// `LHResult.rawValue`: "positive" | "negative".
    public var lhRaw: String?
    /// 35.0–38.5 °C.
    public var bbtCelsius: Double?
    /// `CervicalMucus.rawValue`: "dry" | "sticky" | "creamy" | "eggWhite".
    public var mucusRaw: String?
    public var note: String = ""
    /// `MenstrualFlow.rawValue`: "none" | "light" | "medium" | "heavy".
    public var flowRaw: String?
    /// Comma-separated `Mood` raw values (`RawList`), e.g. "happy,tired".
    public var moodsRaw: String?
    /// Comma-separated `Symptom` raw values of both modes.
    public var symptomsRaw: String?

    public init(record: CycleLogRecord) {
        id = record.id
        day = record.day
        lhRaw = record.lh?.rawValue
        bbtCelsius = record.bbtCelsius
        mucusRaw = record.mucus?.rawValue
        note = record.note
        flowRaw = record.flow?.rawValue
        moodsRaw = RawList.encode(record.moods, unknown: record.unknownMoodsRaw)
        symptomsRaw = RawList.encode(record.symptoms, unknown: record.unknownSymptomsRaw)
    }

    public var record: CycleLogRecord {
        let moods: (known: [Mood], unknown: [String]) = RawList.decode(moodsRaw)
        let symptoms: (known: [Symptom], unknown: [String]) = RawList.decode(symptomsRaw)
        return CycleLogRecord(
            id: id,
            day: day,
            lh: lhRaw.flatMap(LHResult.init(rawValue:)),
            bbtCelsius: bbtCelsius,
            mucus: mucusRaw.flatMap(CervicalMucus.init(rawValue:)),
            note: note,
            flow: flowRaw.flatMap(MenstrualFlow.init(rawValue:)),
            moods: moods.known,
            symptoms: symptoms.known,
            unknownMoodsRaw: moods.unknown,
            unknownSymptomsRaw: symptoms.unknown
        )
    }

    /// Raw values this build cannot decode (e.g. synced from a newer app version)
    /// are kept unless the record actually changes that field; unknown moods and
    /// symptoms travel in the record and are written back with it.
    func apply(_ record: CycleLogRecord) {
        day = record.day
        if lhRaw.flatMap(LHResult.init(rawValue:)) != record.lh {
            lhRaw = record.lh?.rawValue
        }
        bbtCelsius = record.bbtCelsius
        if mucusRaw.flatMap(CervicalMucus.init(rawValue:)) != record.mucus {
            mucusRaw = record.mucus?.rawValue
        }
        note = record.note
        if flowRaw.flatMap(MenstrualFlow.init(rawValue:)) != record.flow {
            flowRaw = record.flow?.rawValue
        }
        let moods = RawList.encode(record.moods, unknown: record.unknownMoodsRaw)
        if moodsRaw != moods {
            moodsRaw = moods
        }
        let symptoms = RawList.encode(record.symptoms, unknown: record.unknownSymptomsRaw)
        if symptomsRaw != symptoms {
            symptomsRaw = symptoms
        }
    }
}

/// The mother's weight on one day. At most one per day (kept so by `WeightStore`).
@Model
public final class WeightEntry {
    public var id: UUID = UUID()
    /// Start of the day.
    public var day: Date = Date()
    /// 30.0–200.0 kg, one decimal.
    public var kg: Double = 0

    public init(record: WeightRecord) {
        id = record.id
        day = record.day
        kg = record.kg
    }

    public var record: WeightRecord {
        WeightRecord(id: id, day: day, kg: kg)
    }

    func apply(_ record: WeightRecord) {
        day = record.day
        kg = record.kg
    }
}
