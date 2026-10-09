import Foundation
import Testing
@testable import KickCore

/// `UITests/Fixtures/sample.lunamom` is made by KickCore's encoder, so the UI tests'
/// file always matches the format. Regenerate it with
/// `WRITE_BACKUP_FIXTURE=1 scripts/test-core.sh --filter BackupFixtureTests`.
struct BackupFixtureTests {
    /// Pregnant at 24w3d on `UITestDates.fixedNow` (2026-10-02 12:00 UTC): three
    /// sessions, two check-ups, one period, two day logs, three weights.
    static func fixture() -> BackupDocument {
        func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))! }
        func session(_ n: Int, start: String) -> SessionRecord {
            let startDate = date(start)
            let kicks = (1...10).map { startDate.addingTimeInterval(Double($0) * 120) }
            return SessionRecord(id: id(n), state: SessionState(
                startedAt: startDate, kicks: kicks, status: .completed, endedAt: kicks.last
            ))
        }
        return BackupDocument(
            createdAt: date("2026-10-01T09:41:00Z"),
            appVersion: "1.0 (21)",
            sessions: [
                session(1, start: "2026-09-30T13:00:00Z"),
                session(2, start: "2026-10-01T13:00:00Z"),
                session(3, start: "2026-10-02T08:00:00Z"),
            ],
            appointments: [
                AppointmentRecord(id: id(11), date: date("2026-10-20T02:00:00Z"), title: "Siêu âm hình thái", note: "Nhịn ăn sáng"),
                AppointmentRecord(id: id(12), date: date("2026-09-15T02:00:00Z"), title: "Khám thai định kỳ", isDone: true),
            ],
            periods: [
                PeriodRecord(id: id(21), startDate: date("2026-04-14T00:00:00Z"), endDate: date("2026-04-18T00:00:00Z")),
            ],
            cycleLogs: [
                CycleLogRecord(id: id(31), day: date("2026-09-28T00:00:00Z"), note: "Hơi mệt", moods: [.tired], symptoms: [.nausea]),
                CycleLogRecord(id: id(32), day: date("2026-10-01T00:00:00Z"), moods: [.happy]),
            ],
            weights: [
                WeightRecord(id: id(41), day: date("2026-08-01T00:00:00Z"), kg: 54.0),
                WeightRecord(id: id(42), day: date("2026-09-01T00:00:00Z"), kg: 56.4),
                WeightRecord(id: id(43), day: date("2026-10-01T00:00:00Z"), kg: 58.1),
            ],
            settings: [
                SettingsKey.appMode: .string("pregnant"),
                SettingsKey.dueDate: .double(1_800_360_000),
                SettingsKey.pregnancyDateSource: .string("dueDate"),
                SettingsKey.reminderEnabled: .bool(false),
                SettingsKey.maternalPreWeightKg: .double(52),
                SettingsKey.maternalHeightCm: .double(158),
            ]
        )
    }

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // KickCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // KickCore
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // repo
            .appendingPathComponent("UITests/Fixtures/sample.lunamom")
    }

    @Test func fixtureFileMatchesTheEncoder() throws {
        let encoded = try BackupCodec.encode(Self.fixture())
        if ProcessInfo.processInfo.environment["WRITE_BACKUP_FIXTURE"] == "1" {
            try encoded.write(to: fixtureURL)
        }
        let stored = try Data(contentsOf: fixtureURL)
        #expect(stored == encoded, "Regenerate UITests/Fixtures/sample.lunamom (see the doc comment)")
        let decoded = try BackupCodec.decode(stored)
        #expect(decoded == Self.fixture())
    }

    @Test func fixtureIsValidOnTheUITestDay() {
        let (_, skipped) = BackupValidation.clean(Self.fixture(), now: date("2026-10-02T12:00:00Z"), calendar: utcCalendar)
        #expect(skipped == 0)
    }
}
