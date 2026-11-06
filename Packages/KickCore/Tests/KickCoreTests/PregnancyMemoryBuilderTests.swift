import Foundation
import Testing
@testable import KickCore

/// 1.1 item 4 (spec §4.3, §4.6): what a memory keeps, and which raw rows the
/// archive deletes.
struct PregnancyMemoryBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return calendar
    }

    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00+07:00") }
    private func at(_ iso: String) -> Date { date("\(iso)+07:00") }

    /// LMP 2026-03-01, so the due date is 2026-12-06.
    private let profile = PregnancyProfile(source: .lmp, dueDate: date("2026-12-06T00:00:00+07:00"), lmpDate: date("2026-03-01T00:00:00+07:00"))
    private let noDates = PregnancyProfile(source: .dueDate, dueDate: nil, lmpDate: nil)

    private func session(_ start: String, kicks: Int, minutes: Double, status: SessionStatus = .completed) -> SessionRecord {
        let startedAt = at(start)
        let end = startedAt.addingTimeInterval(minutes * 60)
        let times = (0..<kicks).map { startedAt.addingTimeInterval(Double($0 + 1) * (minutes * 60) / Double(max(kicks, 1))) }
        return SessionRecord(id: UUID(), state: SessionState(
            startedAt: startedAt, kicks: times, status: status, endedAt: status == .active ? nil : end
        ))
    }

    private func make(
        branch: PregnancyEndBranch = .birth,
        profile: PregnancyProfile? = nil,
        endDate: String = "2026-11-20",
        sessions: [SessionRecord] = [],
        contractions: [ContractionRecord] = [],
        appointments: [AppointmentRecord] = [],
        weights: [WeightRecord] = [],
        logs: [CycleLogRecord] = []
    ) -> PregnancyMemoryContent {
        PregnancyMemoryBuilder.make(
            branch: branch, profile: profile ?? self.profile, endDate: day(endDate),
            sessions: sessions, contractions: contractions, appointments: appointments,
            weights: weights, logs: logs, calendar: calendar
        )
    }

    @Test func kicksAreGroupedPerDay() throws {
        let content = make(sessions: [
            session("2026-10-01T09:00:00", kicks: 10, minutes: 30),
            session("2026-10-01T20:00:00", kicks: 10, minutes: 20),
            session("2026-10-02T09:00:00", kicks: 10, minutes: 40),
            session("2026-10-02T21:00:00", kicks: 4, minutes: 10, status: .cancelled),
            session("2026-10-03T09:00:00", kicks: 3, minutes: 5, status: .active),
        ])
        #expect(content.kickDays.count == 2)
        let first = try #require(content.kickDays.first)
        #expect(first.day == day("2026-10-01"))
        #expect(first.sessionCount == 2)
        #expect(first.totalKicks == 20)
        #expect(abs((first.bestDuration ?? 0) - 20 * 60) < 0.001)
        #expect(content.kickDays[1].sessionCount == 1)
    }

    @Test func contractionEpisodesUseContractionStats() throws {
        let start = at("2026-11-19T22:00:00")
        let contractions = (0..<4).map { index in
            let begin = start.addingTimeInterval(Double(index) * 300)
            return ContractionRecord(startedAt: begin, endedAt: begin.addingTimeInterval(60))
        }
        let content = make(contractions: contractions)
        let episode = try #require(content.contractionEpisodes.first)
        #expect(content.contractionEpisodes.count == 1)
        #expect(episode.start == start)
        #expect(episode.count == 4)
        #expect(episode.averageDuration == 60)
        #expect(episode.averageInterval == 300)
    }

    @Test func appointmentsOutsideRangeAreLeftOut() {
        let content = make(appointments: [
            AppointmentRecord(date: at("2026-02-10T09:00:00"), title: "Before"),
            AppointmentRecord(date: at("2026-06-10T09:00:00"), title: "Scan", note: "All fine"),
            AppointmentRecord(date: at("2026-11-25T09:00:00"), title: "After"),
        ])
        #expect(content.appointments == [MemoryAppointment(date: at("2026-06-10T09:00:00"), title: "Scan", note: "All fine")])
    }

    @Test func weightsInRangeOnly() {
        let content = make(weights: [
            WeightRecord(day: day("2026-02-20"), kg: 50),
            WeightRecord(day: day("2026-05-01"), kg: 53.2),
            WeightRecord(day: day("2026-11-20"), kg: 61),
            WeightRecord(day: day("2026-11-21"), kg: 60),
        ])
        #expect(content.weights == [
            MemoryWeight(day: day("2026-05-01"), kg: 53.2),
            MemoryWeight(day: day("2026-11-20"), kg: 61),
        ])
    }

    @Test func logsKeepOnlyPregnancyFields() {
        let content = make(logs: [
            CycleLogRecord(
                day: day("2026-06-01"), lh: .positive, bbtCelsius: 36.7, mucus: .creamy, note: " Felt the first flutter ",
                flow: .light, moods: [.happy], symptoms: [.cramps, .nausea]
            ),
            // Only cycle data: not a pregnancy entry.
            CycleLogRecord(day: day("2026-06-02"), bbtCelsius: 36.5, flow: .noFlow),
            // Outside the range.
            CycleLogRecord(day: day("2026-02-01"), note: "Before"),
        ])
        #expect(content.notes == [
            MemoryNote(day: day("2026-06-01"), text: "Felt the first flutter", moods: ["happy"], pregnancySymptoms: ["nausea"]),
        ])
    }

    @Test func furthestWeekForLossAt12Weeks() {
        // LMP 2026-03-01 + 12 weeks 3 days.
        let content = make(branch: .loss, endDate: "2026-05-27")
        #expect(content.furthestWeek == 12)
        #expect(content.start == day("2026-03-01"))
        #expect(content.end == day("2026-05-27"))
    }

    @Test func furthestWeekClampsAt42() {
        let content = make(endDate: "2027-01-10")
        #expect(content.furthestWeek == 42)
    }

    @Test func noDatesUsesFallbackStart() {
        let content = make(
            profile: noDates,
            sessions: [session("2026-09-01T09:00:00", kicks: 10, minutes: 30)],
            appointments: [AppointmentRecord(date: at("2026-08-15T09:00:00"), title: "Check")],
            weights: [WeightRecord(day: day("2026-08-01"), kg: 55), WeightRecord(day: day("2026-08-20"), kg: 56)]
        )
        #expect(content.start == day("2026-08-15"))
        #expect(content.furthestWeek == nil)
        #expect(content.appointments.count == 1)
        #expect(content.weights == [MemoryWeight(day: day("2026-08-20"), kg: 56)])
    }

    @Test func contentRoundTripsThroughJSON() throws {
        let start = at("2026-11-19T22:00:00").addingTimeInterval(0.25)
        let content = make(
            sessions: [session("2026-10-01T09:00:00", kicks: 10, minutes: 30)],
            contractions: [ContractionRecord(startedAt: start, endedAt: start.addingTimeInterval(55))],
            appointments: [AppointmentRecord(date: at("2026-06-10T09:00:00"), title: "Scan", note: "Ổn")],
            weights: [WeightRecord(day: day("2026-05-01"), kg: 53.2)],
            logs: [CycleLogRecord(day: day("2026-06-01"), note: "Bé đạp", moods: [.calm])]
        )
        let data = try PregnancyMemoryContent.encoder.encode(content)
        let decoded = try PregnancyMemoryContent.decoder.decode(PregnancyMemoryContent.self, from: data)
        #expect(decoded == content)
        #expect(String(decoding: data, as: UTF8.self).contains("2026-"))
    }

    @Test func rowsToDeleteNeverIncludesOutOfRange() throws {
        let range = try #require(PregnancyRange.make(profile: profile, endDate: day("2026-11-20"), fallbackStarts: [], calendar: calendar))
        let inside = AppointmentRecord(date: at("2026-06-10T09:00:00"), title: "Scan")
        let before = AppointmentRecord(date: at("2026-02-10T09:00:00"), title: "Before")
        let after = AppointmentRecord(date: at("2026-12-01T09:00:00"), title: "After")
        let inWeight = WeightRecord(day: day("2026-05-01"), kg: 53)
        let outWeight = WeightRecord(day: day("2026-01-01"), kg: 50)
        let thisSession = session("2026-10-01T09:00:00", kicks: 10, minutes: 30)
        let earlierSession = session("2025-06-01T09:00:00", kicks: 10, minutes: 30)
        let thisContraction = ContractionRecord(startedAt: at("2026-11-19T22:00:00"), endedAt: at("2026-11-19T22:01:00"))
        let earlierContraction = ContractionRecord(startedAt: at("2025-07-01T22:00:00"), endedAt: at("2025-07-01T22:01:00"))
        let rows = PregnancyMemoryBuilder.rowsToDelete(
            range: range, sessions: [thisSession, earlierSession], contractions: [thisContraction, earlierContraction],
            appointments: [inside, before, after], weights: [inWeight, outWeight]
        )
        #expect(rows.appointments == [inside.id])
        #expect(rows.weights == [inWeight.id])
        #expect(rows.sessions == [thisSession.id])
        #expect(rows.contractions == [thisContraction.id])
        let none = PregnancyMemoryBuilder.rowsToDelete(
            range: nil, sessions: [thisSession], contractions: [thisContraction], appointments: [inside], weights: [inWeight]
        )
        #expect(none.isEmpty)
    }

    @Test func sameContentForBothBranches() {
        let sessions = [session("2026-10-01T09:00:00", kicks: 10, minutes: 30)]
        let logs = [CycleLogRecord(day: day("2026-06-01"), note: "Note")]
        var birth = make(branch: .birth, sessions: sessions, logs: logs)
        let loss = make(branch: .loss, sessions: sessions, logs: logs)
        #expect(birth != loss)
        birth.branch = .loss
        #expect(birth == loss)
    }

    /// Review fix 2: an earlier pregnancy's kicks and contractions are not in this memory.
    @Test func earlierPregnancyKicksAndContractionsAreLeftOut() {
        let content = make(
            sessions: [
                session("2025-06-01T09:00:00", kicks: 10, minutes: 30),
                session("2026-10-01T09:00:00", kicks: 10, minutes: 30),
            ],
            contractions: [
                ContractionRecord(startedAt: at("2025-07-01T22:00:00"), endedAt: at("2025-07-01T22:01:00")),
                ContractionRecord(startedAt: at("2026-11-19T22:00:00"), endedAt: at("2026-11-19T22:01:00")),
            ]
        )
        #expect(content.kickDays.map(\.day) == [day("2026-10-01")])
        #expect(content.contractionEpisodes.map(\.start) == [at("2026-11-19T22:00:00")])
    }
}
