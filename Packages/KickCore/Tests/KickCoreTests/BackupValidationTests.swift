import Foundation
import Testing
@testable import KickCore

/// Spec §3 "Validation before replacing": invalid records are skipped and counted.
struct BackupValidationTests {
    let now = date("2026-10-09T12:00:00Z")

    private func document(
        sessions: [SessionRecord] = [],
        appointments: [AppointmentRecord] = [],
        periods: [PeriodRecord] = [],
        logs: [CycleLogRecord] = [],
        weights: [WeightRecord] = []
    ) -> BackupDocument {
        BackupDocument(
            createdAt: now, appVersion: "1.0",
            sessions: sessions, appointments: appointments, periods: periods,
            cycleLogs: logs, weights: weights, settings: [SettingsKey.appMode: .string("pregnant")]
        )
    }

    private func clean(_ document: BackupDocument) -> (BackupDocument, skipped: Int) {
        BackupValidation.clean(document, now: now, calendar: utcCalendar)
    }

    @Test func validDocumentIsUnchanged() {
        let original = BackupCodecTests.sampleDocument()
        let (cleaned, skipped) = clean(original)
        #expect(skipped == 0)
        #expect(cleaned == original)
    }

    @Test func futureAndInvalidCycleRecordsAreSkipped() {
        let (cleaned, skipped) = clean(document(
            periods: [
                PeriodRecord(startDate: date("2026-09-01T00:00:00Z"), endDate: date("2026-09-05T00:00:00Z")),
                PeriodRecord(startDate: date("2026-10-20T00:00:00Z")), // future
                PeriodRecord(startDate: date("2026-08-10T00:00:00Z"), endDate: date("2026-08-01T00:00:00Z")), // ends before start
            ],
            logs: [
                CycleLogRecord(day: date("2026-10-02T00:00:00Z"), note: "ok"),
                CycleLogRecord(day: date("2026-10-12T00:00:00Z"), note: "future"),
                CycleLogRecord(day: date("2026-10-03T00:00:00Z"), bbtCelsius: 41),
            ]
        ))
        #expect(skipped == 4)
        #expect(cleaned.periods.map(\.record.startDate) == [date("2026-09-01T00:00:00Z")])
        #expect(cleaned.cycleLogs.map(\.record.note) == ["ok"])
    }

    @Test func overlappingPeriodsAreKeptAsInTheFile() {
        let (cleaned, skipped) = clean(document(periods: [
            PeriodRecord(startDate: date("2026-09-01T00:00:00Z"), endDate: date("2026-09-05T00:00:00Z")),
            PeriodRecord(startDate: date("2026-09-03T00:00:00Z"), endDate: date("2026-09-07T00:00:00Z")),
        ]))
        #expect(skipped == 0)
        #expect(cleaned.periods.count == 2)
    }

    @Test func invalidWeightsAreSkipped() {
        let (cleaned, skipped) = clean(document(weights: [
            WeightRecord(day: date("2026-10-01T00:00:00Z"), kg: 55),
            WeightRecord(day: date("2026-10-01T00:00:00Z"), kg: 500),
            WeightRecord(day: date("2026-10-11T00:00:00Z"), kg: 55),
        ]))
        #expect(skipped == 2)
        #expect(cleaned.weights.map(\.record.kg) == [55])
    }

    @Test func appointmentsWithoutATitleAreSkipped() {
        let (cleaned, skipped) = clean(document(appointments: [
            AppointmentRecord(date: date("2026-12-01T08:00:00Z"), title: "Siêu âm"),
            AppointmentRecord(date: date("2026-12-02T08:00:00Z"), title: "   "),
        ]))
        #expect(skipped == 1)
        #expect(cleaned.appointments.map(\.record.title) == ["Siêu âm"])
    }

    @Test func duplicateIDsKeepTheFirst() {
        let id = UUID()
        let (cleaned, skipped) = clean(document(weights: [
            WeightRecord(id: id, day: date("2026-10-01T00:00:00Z"), kg: 55),
            WeightRecord(id: id, day: date("2026-10-02T00:00:00Z"), kg: 56),
        ]))
        #expect(skipped == 1)
        #expect(cleaned.weights.map(\.record.kg) == [55])
    }

    @Test func futureSessionsAreSkipped() {
        let (cleaned, skipped) = clean(document(sessions: [
            SessionRecord(id: UUID(), state: SessionState(startedAt: date("2026-10-10T08:00:00Z"))),
        ]))
        #expect(skipped == 1)
        #expect(cleaned.sessions.isEmpty)
    }

    @Test func aRecentRunningSessionIsRestoredAsIs() {
        let running = SessionRecord(id: UUID(), state: SessionState(
            startedAt: date("2026-10-09T09:00:00Z"), kicks: [date("2026-10-09T09:05:00Z")]
        ))
        let (cleaned, skipped) = clean(document(sessions: [running]))
        #expect(skipped == 0)
        #expect(cleaned.sessions.map(\.record) == [running])
    }

    @Test func anAbandonedRunningSessionIsClosedAtItsLastKick() throws {
        let old = SessionRecord(id: UUID(), state: SessionState(
            startedAt: date("2026-10-08T20:00:00Z"),
            kicks: [date("2026-10-08T20:05:00Z"), date("2026-10-08T20:09:00Z")]
        ))
        let (cleaned, skipped) = clean(document(sessions: [old]))
        #expect(skipped == 0)
        let state = try #require(cleaned.sessions.first?.record.state)
        #expect(state.status == .cancelled)
        #expect(state.endedAt == date("2026-10-08T20:09:00Z"))
        #expect(state.kicks.count == 2)
    }

    @Test func anAbandonedSessionWithoutKicksClosesAtItsStart() throws {
        let old = SessionRecord(id: UUID(), state: SessionState(startedAt: date("2026-10-07T20:00:00Z")))
        let (cleaned, _) = clean(document(sessions: [old]))
        let state = try #require(cleaned.sessions.first?.record.state)
        #expect(state.status == .cancelled)
        #expect(state.endedAt == date("2026-10-07T20:00:00Z"))
    }

    @Test func onlyTheNewestRunningSessionStaysActive() throws {
        let older = SessionRecord(id: UUID(), state: SessionState(
            startedAt: date("2026-10-09T08:00:00Z"), kicks: [date("2026-10-09T08:01:00Z")]
        ))
        let newer = SessionRecord(id: UUID(), state: SessionState(startedAt: date("2026-10-09T10:00:00Z")))
        let (cleaned, _) = clean(document(sessions: [older, newer]))
        let byID = Dictionary(uniqueKeysWithValues: cleaned.sessions.map { ($0.id, $0.record.state) })
        #expect(byID[newer.id]?.status == .active)
        #expect(byID[older.id]?.status == .cancelled)
        #expect(byID[older.id]?.endedAt == date("2026-10-09T08:01:00Z"))
    }
}

/// Final review: the stores' one-per-day invariants and impossible sessions.
struct BackupValidationReviewTests {
    let now = date("2026-10-09T12:00:00Z")

    private func clean(sessions: [SessionRecord] = [], logs: [CycleLogRecord] = [], weights: [WeightRecord] = []) -> (BackupDocument, skipped: Int) {
        BackupValidation.clean(
            BackupDocument(
                createdAt: now, appVersion: "1.0", sessions: sessions, appointments: [], periods: [],
                cycleLogs: logs, weights: weights, settings: [:]
            ),
            now: now, calendar: utcCalendar
        )
    }

    @Test func twoLogsOnOneDayKeepTheLast() {
        let (cleaned, skipped) = clean(logs: [
            CycleLogRecord(day: date("2026-10-02T00:00:00Z"), note: "first"),
            CycleLogRecord(day: date("2026-10-02T15:00:00Z"), note: "second"),
            CycleLogRecord(day: date("2026-10-03T00:00:00Z"), note: "other day"),
        ])
        #expect(skipped == 1)
        #expect(cleaned.cycleLogs.map(\.note) == ["second", "other day"])
    }

    @Test func twoWeightsOnOneDayKeepTheLast() {
        let (cleaned, skipped) = clean(weights: [
            WeightRecord(day: date("2026-10-02T00:00:00Z"), kg: 55),
            WeightRecord(day: date("2026-10-02T08:00:00Z"), kg: 56),
        ])
        #expect(skipped == 1)
        #expect(cleaned.weights.map(\.kg) == [56])
    }

    @Test func aSessionEndingBeforeItStartsIsSkipped() {
        let (cleaned, skipped) = clean(sessions: [
            SessionRecord(id: UUID(), state: SessionState(
                startedAt: date("2026-10-08T20:00:00Z"), status: .cancelled, endedAt: date("2026-10-08T19:00:00Z")
            )),
        ])
        #expect(skipped == 1)
        #expect(cleaned.sessions.isEmpty)
    }

    @Test func futureKicksAreDropped() throws {
        let (cleaned, skipped) = clean(sessions: [
            SessionRecord(id: UUID(), state: SessionState(
                startedAt: date("2026-10-09T11:00:00Z"),
                kicks: [date("2026-10-09T11:01:00Z"), date("2026-10-09T13:00:00Z")]
            )),
        ])
        #expect(skipped == 0)
        let state = try #require(cleaned.sessions.first?.record.state)
        #expect(state.kicks == [date("2026-10-09T11:01:00Z")])
    }
}
