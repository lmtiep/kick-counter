import Foundation
import Testing
@testable import KickCore

/// Phase 15 spec §3 and §6: the `.lunamom` backup format.
struct BackupCodecTests {
    static let created = date("2026-10-09T09:41:00.250Z")

    static func sampleDocument() -> BackupDocument {
        let session = SessionRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            state: SessionState(
                startedAt: date("2026-10-08T20:00:00.125Z"),
                kicks: [date("2026-10-08T20:01:00Z"), date("2026-10-08T20:02:00.5Z")],
                status: .cancelled,
                endedAt: date("2026-10-08T20:30:00Z"),
                exceededThreshold: false
            )
        )
        let appointment = AppointmentRecord(
            date: date("2026-10-20T08:00:00Z"), title: "Khám thai", note: "Mang sổ", isDone: false, milestoneID: "nt"
        )
        let period = PeriodRecord(startDate: date("2026-09-01T00:00:00Z"), endDate: date("2026-09-05T00:00:00Z"))
        let openPeriod = PeriodRecord(startDate: date("2026-10-01T00:00:00Z"))
        let log = CycleLogRecord(
            day: date("2026-10-02T00:00:00Z"), lh: .positive, bbtCelsius: 36.7, mucus: .eggWhite,
            note: "ghi chú", flow: .light, moods: [.happy, .tired], symptoms: [.cramps],
            unknownMoodsRaw: ["dreamy"], unknownSymptomsRaw: ["futureSymptom"]
        )
        let weight = WeightRecord(day: date("2026-10-03T00:00:00Z"), kg: 56.2)
        return BackupDocument(
            createdAt: created,
            appVersion: "1.0 (21)",
            sessions: [session],
            appointments: [appointment],
            periods: [period, openPeriod],
            cycleLogs: [log],
            weights: [weight],
            settings: [
                SettingsKey.reminderEnabled: .bool(true),
                SettingsKey.reminderHour: .int(21),
                SettingsKey.dueDate: .double(1_800_000_000),
                SettingsKey.appMode: .string("pregnant"),
                SettingsKey.lastBackupAt: .date(date("2026-10-01T10:00:00Z")),
            ]
        )
    }

    @Test func roundTripKeepsRecordsAndSettings() throws {
        let document = Self.sampleDocument()
        let decoded = try BackupCodec.decode(BackupCodec.encode(document))
        #expect(decoded == document)
        #expect(decoded.cycleLogs.first?.record.unknownMoodsRaw == ["dreamy"])
        #expect(decoded.cycleLogs.first?.record.unknownSymptomsRaw == ["futureSymptom"])
        #expect(decoded.sessions.first?.record.state.kicks.count == 2)
    }

    @Test func recordsSurviveTheDTOs() throws {
        let document = Self.sampleDocument()
        let decoded = try BackupCodec.decode(BackupCodec.encode(document))
        #expect(decoded.sessions.map(\.record) == document.sessions.map(\.record))
        #expect(decoded.appointments.map(\.record) == document.appointments.map(\.record))
        #expect(decoded.periods.map(\.record) == document.periods.map(\.record))
        #expect(decoded.cycleLogs.map(\.record) == document.cycleLogs.map(\.record))
        #expect(decoded.weights.map(\.record) == document.weights.map(\.record))
    }

    @Test func encodesTheVersionedHeaderWithFractionalISODates() throws {
        let data = try BackupCodec.encode(Self.sampleDocument())
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"format\" : \"luna-mom-backup\""))
        #expect(text.contains("\"version\" : 1"))
        #expect(text.contains("\"createdAt\" : \"2026-10-09T09:41:00.250Z\""))
        #expect(text.contains("\"appVersion\" : \"1.0 (21)\""))
        // Settings are typed JSON values: a date setting is an ISO string, a bool is a bool.
        #expect(text.contains("\"lastBackupAt\" : \"2026-10-01T10:00:00.000Z\""))
        #expect(text.contains("\"reminderEnabled\" : true"))
    }

    @Test func wrongFormatIsNotABackup() {
        let json = #"{"format":"something-else","version":1}"#
        #expect(throws: BackupError.notABackup) { try BackupCodec.decode(Data(json.utf8)) }
    }

    @Test func missingFormatIsNotABackup() {
        let json = #"{"hello":"world"}"#
        #expect(throws: BackupError.notABackup) { try BackupCodec.decode(Data(json.utf8)) }
    }

    @Test func newerVersionIsReported() {
        let json = #"{"format":"luna-mom-backup","version":2}"#
        #expect(throws: BackupError.newerVersion(2)) { try BackupCodec.decode(Data(json.utf8)) }
    }

    @Test func invalidJSONIsCorrupt() {
        #expect(throws: BackupError.corrupt) { try BackupCodec.decode(Data("not json".utf8)) }
        #expect(throws: BackupError.corrupt) { try BackupCodec.decode(Data()) }
    }

    @Test func missingRequiredFieldsAreCorrupt() {
        let json = #"{"format":"luna-mom-backup","version":1,"createdAt":"2026-10-09T09:41:00Z"}"#
        #expect(throws: BackupError.corrupt) { try BackupCodec.decode(Data(json.utf8)) }
    }

    @Test func aBrokenRecordIsCorrupt() throws {
        var text = try #require(String(data: BackupCodec.encode(Self.sampleDocument()), encoding: .utf8))
        text = text.replacingOccurrences(of: "\"kg\" : 56.2", with: "\"kg\" : \"heavy\"")
        #expect(throws: BackupError.corrupt) { try BackupCodec.decode(Data(text.utf8)) }
    }

    @Test func unknownExtraFieldsAreIgnored() throws {
        let document = Self.sampleDocument()
        let data = try BackupCodec.encode(document)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["futureTopLevel"] = ["a": 1]
        var weights = try #require(object["weights"] as? [[String: Any]])
        weights[0]["futureField"] = "x"
        object["weights"] = weights
        var settings = try #require(object["settings"] as? [String: Any])
        settings["futureSettingKey"] = 42
        object["settings"] = settings
        let decoded = try BackupCodec.decode(JSONSerialization.data(withJSONObject: object))
        #expect(decoded == document)
    }

    @Test func aSettingOfTheWrongTypeIsDropped() throws {
        let data = try BackupCodec.encode(Self.sampleDocument())
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var settings = try #require(object["settings"] as? [String: Any])
        settings[SettingsKey.reminderHour] = "late"
        object["settings"] = settings
        let decoded = try BackupCodec.decode(JSONSerialization.data(withJSONObject: object))
        #expect(decoded.settings[SettingsKey.reminderHour] == nil)
        #expect(decoded.settings[SettingsKey.reminderEnabled] == .bool(true))
    }

    @Test func datesWithoutFractionalSecondsAreAccepted() throws {
        let json = """
        {"format":"luna-mom-backup","version":1,"createdAt":"2026-10-09T09:41:00Z","appVersion":"1.0",
         "sessions":[],"appointments":[],"periods":[{"id":"00000000-0000-0000-0000-0000000000AA",
         "startDate":"2026-09-01T00:00:00Z"}],"cycleLogs":[],"weights":[],"settings":{}}
        """
        let decoded = try BackupCodec.decode(Data(json.utf8))
        #expect(decoded.createdAt == date("2026-10-09T09:41:00Z"))
        #expect(decoded.periods.first?.record.endDate == nil)
    }

    @Test func fileNameUsesTheLocalDay() {
        #expect(BackupDocument.fileName(for: date("2026-10-09T23:30:00Z"), calendar: utcCalendar) == "LunaMom-2026-10-09.lunamom")
        #expect(BackupFormat.fileExtension == "lunamom")
        #expect(BackupFormat.typeIdentifier == "com.lmtiep.kickcounter.backup")
    }
}

/// Final review fixes: one decode on the happy path, a size limit, raw values kept.
struct BackupCodecReviewTests {
    @Test func aWholeFileFromANewerVersionIsStillNewer() throws {
        var document = BackupCodecTests.sampleDocument()
        document.version = 2
        #expect(throws: BackupError.newerVersion(2)) { try BackupCodec.decode(BackupCodec.encode(document)) }
    }

    @Test func aWholeFileWithAnotherFormatIsNotABackup() throws {
        var document = BackupCodecTests.sampleDocument()
        document.format = "other-app"
        #expect(throws: BackupError.notABackup) { try BackupCodec.decode(BackupCodec.encode(document)) }
    }

    @Test func aFileOverTheSizeLimitIsCorruptWithoutReadingIt() {
        let big = Data(count: BackupCodec.maxFileSize + 1)
        #expect(throws: BackupError.corrupt) { try BackupCodec.decode(big) }
        #expect(BackupCodec.maxFileSize == 20 * 1024 * 1024)
    }

    @Test func unknownLHMucusAndFlowValuesSurvive() throws {
        let json = """
        {"format":"luna-mom-backup","version":1,"createdAt":"2026-10-09T09:41:00Z","appVersion":"2.0",
         "sessions":[],"appointments":[],"periods":[],"weights":[],"settings":{},
         "cycleLogs":[{"id":"00000000-0000-0000-0000-0000000000AB","day":"2026-10-02T00:00:00Z",
           "lh":"faint","mucus":"watery","flow":"spotting","note":"","moods":[],"symptoms":[],
           "unknownMoods":[],"unknownSymptoms":[]}]}
        """
        let document = try BackupCodec.decode(Data(json.utf8))
        let log = try #require(document.records.logs.first)
        #expect(log.lh == "faint" && log.mucus == "watery" && log.flow == "spotting")
        #expect(log.record.lh == nil && log.record.flow == nil)
        let again = try BackupCodec.decode(BackupCodec.encode(document))
        #expect(again.records.logs.first?.flow == "spotting")
    }

    @Test func partnerModeIsReportedAsPartner() {
        let document = BackupDocument(
            createdAt: BackupCodecTests.created, appVersion: "1.0",
            sessions: [], appointments: [], periods: [], cycleLogs: [], weights: [],
            settings: [SettingsKey.appMode: .string("partner")]
        )
        #expect(document.summary.mode == .partner)
    }
}
