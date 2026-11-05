import Foundation
import Testing
@testable import KickCore

struct DoctorReportTests {
    /// 24w3d on `now`; the last period began 2026-04-14.
    let now = date("2026-10-02T12:00:00Z")
    let dueDate = date("2027-01-19T12:00:00Z")
    let calendar = utcCalendar

    private func at(_ iso: String) -> Date { date("\(iso)Z") }
    private func day(_ iso: String) -> Date { date("\(iso)T00:00:00Z") }

    private func make(
        mode: AppMode = .pregnant,
        range: ReportRange = .weeks(2),
        include: Set<ReportSectionKind>? = nil,
        input: DoctorReportInput,
        name: String? = nil
    ) -> DoctorReport {
        DoctorReport.make(
            mode: mode, range: range, include: include ?? Set(ReportSectionKind.allCases),
            input: input, name: name, now: now, calendar: calendar
        )
    }

    private func session(_ start: String, kicks: Int = 10, minutes: Double = 20, status: SessionStatus = .completed) -> SessionState {
        let begin = at(start)
        return SessionState(
            startedAt: begin,
            kicks: (1...max(kicks, 1)).map { begin.addingTimeInterval(Double($0) * 60) },
            status: status,
            endedAt: begin.addingTimeInterval(minutes * 60)
        )
    }

    private func weight(_ iso: String, _ kg: Double) -> WeightRecord { WeightRecord(day: day(iso), kg: kg) }

    private func kickRows(_ report: DoctorReport) -> [DoctorReport.KickRow] {
        for case .kicks(let rows) in report.sections { return rows }
        return []
    }

    private func weightDays(_ report: DoctorReport) -> [Date] {
        for case .weights(let rows) in report.sections { return rows.map(\.day) }
        return []
    }

    // MARK: - Range

    @Test func weeksRangeIncludesItsFirstDayAndNotTheDayBefore() {
        // Two weeks ending 2026-10-02 start on 2026-09-19.
        let input = DoctorReportInput(weights: [
            weight("2026-09-18", 60), weight("2026-09-19", 61), weight("2026-10-02", 62),
        ])
        let report = make(range: .weeks(2), input: input)
        #expect(weightDays(report) == [day("2026-09-19"), day("2026-10-02")])
        #expect(report.header.start == day("2026-09-19"))
    }

    @Test func rangeEndsWithTodayAndLeavesTomorrowOut() {
        let input = DoctorReportInput(sessions: [
            session("2026-10-02T23:30:00"), session("2026-10-03T00:00:00"),
        ])
        let report = make(range: .weeks(2), input: input)
        #expect(kickRows(report).map(\.startedAt) == [at("2026-10-02T23:30:00")])
        #expect(report.header.end == day("2026-10-02"))
    }

    @Test func fourWeeksCoverTwentyEightDays() {
        let input = DoctorReportInput(weights: [weight("2026-09-04", 60), weight("2026-09-05", 61)])
        let report = make(range: .weeks(4), input: input)
        #expect(weightDays(report) == [day("2026-09-05")])
        #expect(report.header.start == day("2026-09-05"))
    }

    @Test func wholePregnancyStartsOnTheFirstDayOfTheLastPeriod() {
        let input = DoctorReportInput(
            weights: [weight("2026-04-13", 50), weight("2026-04-14", 51), weight("2026-10-02", 60)], dueDate: dueDate
        )
        let report = make(range: .wholePregnancy, input: input)
        #expect(weightDays(report) == [day("2026-04-14"), day("2026-10-02")])
        #expect(report.header.start == day("2026-04-14"))
    }

    @Test func wholePregnancyWithoutADueDateStartsAtTheEarliestRecord() {
        let input = DoctorReportInput(weights: [weight("2026-06-01", 55), weight("2026-10-02", 60)])
        let report = make(range: .wholePregnancy, input: input)
        #expect(weightDays(report).count == 2)
        #expect(report.header.start == day("2026-06-01"))
    }

    @Test func cyclesRangeStartsAtTheNthLatestPeriod() {
        let periods = ["2026-06-01", "2026-06-29", "2026-07-27", "2026-08-24", "2026-09-21"]
            .map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
        let logs = [
            CycleLogRecord(day: day("2026-07-26"), bbtCelsius: 36.4),
            CycleLogRecord(day: day("2026-07-27"), bbtCelsius: 36.5),
        ]
        let report = make(mode: .tryingToConceive, range: .cycles(3), input: DoctorReportInput(logs: logs, periods: periods))
        #expect(report.sections.map(\.kind) == [.periods, .cycleLengths, .bbtAndLH])
        #expect(report.header.start == day("2026-07-27"))
        for case .periods(let rows) in report.sections {
            #expect(rows.map(\.start) == [day("2026-07-27"), day("2026-08-24"), day("2026-09-21")])
        }
        for case .bbtAndLH(let rows) in report.sections {
            #expect(rows.map(\.day) == [day("2026-07-27")])
        }
    }

    @Test func cyclesRangeWithFewerPeriodsStartsAtTheFirst() {
        let periods = [PeriodRecord(startDate: day("2026-09-01"), endDate: day("2026-09-05"))]
        let report = make(mode: .tryingToConceive, range: .cycles(6), input: DoctorReportInput(periods: periods))
        #expect(report.header.start == day("2026-09-01"))
    }

    // MARK: - Pregnancy sections

    @Test func kicksListCompletedSessionsOnly() {
        let input = DoctorReportInput(sessions: [
            session("2026-10-01T20:00:00", kicks: 10, minutes: 24),
            session("2026-10-02T09:00:00", kicks: 4, minutes: 15, status: .cancelled),
            SessionState(startedAt: at("2026-10-02T11:00:00")),
        ])
        let rows = kickRows(make(input: input))
        #expect(rows == [DoctorReport.KickRow(startedAt: at("2026-10-01T20:00:00"), count: 10, duration: 24 * 60)])
    }

    @Test func contractionsAreSummarisedPerEpisode() {
        // Three contractions 10 minutes apart, 60 s each, then a later lone one.
        let start = at("2026-10-01T22:00:00")
        let records = (0..<3).map {
            ContractionRecord(
                startedAt: start.addingTimeInterval(Double($0) * 600),
                endedAt: start.addingTimeInterval(Double($0) * 600 + 60)
            )
        }
        let lone = ContractionRecord(startedAt: at("2026-10-02T08:00:00"), endedAt: at("2026-10-02T08:00:45"))
        let report = make(input: DoctorReportInput(contractions: records + [lone]))
        var rows: [DoctorReport.ContractionRow] = []
        for case .contractions(let found) in report.sections { rows = found }
        #expect(rows.map(\.count) == [3, 1])
        #expect(rows[0].startedAt == start)
        #expect(rows[0].averageDuration == 60)
        #expect(rows[0].averageInterval == 600)
        #expect(rows[1].averageInterval == nil)
        #expect(rows.allSatisfy { $0.waterBrokeAt == nil })
    }

    @Test func weightsAreListedOldestFirst() {
        let input = DoctorReportInput(weights: [weight("2026-10-02", 62.5), weight("2026-09-25", 61.8)])
        let report = make(input: input)
        #expect(report.sections.map(\.kind) == [.weights])
        for case .weights(let rows) in report.sections {
            #expect(rows == [
                DoctorReport.WeightRow(day: day("2026-09-25"), kg: 61.8),
                DoctorReport.WeightRow(day: day("2026-10-02"), kg: 62.5),
            ])
        }
    }

    @Test func symptomsKeepPregnancySymptomsOnly() {
        let logs = [
            CycleLogRecord(day: day("2026-10-01"), symptoms: [.cramps, .nausea, .backPain]),
            CycleLogRecord(day: day("2026-10-02"), symptoms: [.cramps]),
            CycleLogRecord(day: day("2026-09-30"), note: "private note"),
        ]
        let report = make(input: DoctorReportInput(logs: logs))
        var rows: [DoctorReport.SymptomRow] = []
        for case .symptoms(let found) in report.sections { rows = found }
        #expect(rows == [DoctorReport.SymptomRow(day: day("2026-10-01"), symptoms: [.nausea, .backPain])])
    }

    @Test func appointmentsKeepTheirNotes() {
        let appointments = [
            AppointmentRecord(date: at("2026-10-01T09:30:00"), title: "Ultrasound", note: "Bring the booklet", isDone: true),
            AppointmentRecord(date: at("2026-08-01T09:30:00"), title: "Too early"),
        ]
        let report = make(input: DoctorReportInput(appointments: appointments))
        #expect(report.sections.map(\.kind) == [.appointments])
        for case .appointments(let rows) in report.sections {
            #expect(rows == [DoctorReport.AppointmentRow(date: at("2026-10-01T09:30:00"), title: "Ultrasound", note: "Bring the booklet", isDone: true)])
        }
    }

    @Test func emptyAndUnselectedSectionsAreOmitted() {
        let input = DoctorReportInput(
            sessions: [session("2026-10-01T20:00:00")], weights: [weight("2026-10-01", 61)]
        )
        let all = make(input: input)
        #expect(all.sections.map(\.kind) == [.kicks, .weights])
        let onlyWeights = make(include: [.weights, .appointments], input: input)
        #expect(onlyWeights.sections.map(\.kind) == [.weights])
        let nothing = make(input: DoctorReportInput())
        #expect(nothing.sections.isEmpty)
        #expect(nothing.isEmpty)
        #expect(!all.isEmpty)
    }

    @Test func cycleSectionsAreNotInAPregnancyReport() {
        let input = DoctorReportInput(
            logs: [CycleLogRecord(day: day("2026-10-01"), lh: .positive, bbtCelsius: 36.6, moods: [.calm])],
            periods: [PeriodRecord(startDate: day("2026-09-28"), endDate: day("2026-10-01"))]
        )
        #expect(make(mode: .pregnant, input: input).sections.isEmpty)
    }

    // MARK: - Headers

    @Test func pregnancyHeaderHasWeekAndDueDate() {
        let report = make(input: DoctorReportInput(dueDate: dueDate), name: "Lan")
        #expect(report.header.mode == .pregnant)
        #expect(report.header.week == GestationalWeek(weeks: 24, days: 3))
        #expect(report.header.dueDate == dueDate)
        #expect(report.header.generatedAt == now)
        #expect(report.header.averageCycleLength == nil)
        #expect(report.header.name == "Lan")
    }

    @Test func cycleHeaderHasAverages() {
        let starts = ["2026-07-01", "2026-07-29", "2026-08-27", "2026-09-24"]
        let periods = starts.map { PeriodRecord(startDate: day($0), endDate: calendar.date(byAdding: .day, value: 4, to: day($0))) }
        let report = make(mode: .tryingToConceive, range: .cycles(3), input: DoctorReportInput(periods: periods))
        #expect(report.header.averageCycleLength == 28) // 28, 29, 28
        #expect(report.header.averagePeriodLength == 5)
        #expect(report.header.week == nil)
        #expect(report.header.dueDate == nil)
    }

    @Test func theNameIsTrimmedAndBlankMeansNone() {
        #expect(make(input: DoctorReportInput(), name: "  Lan  ").header.name == "Lan")
        #expect(make(input: DoctorReportInput(), name: "   ").header.name == nil)
        #expect(make(input: DoctorReportInput(), name: nil).header.name == nil)
    }

    // MARK: - Cycle sections

    @Test func periodsAndCycleLengths() {
        let periods = [
            PeriodRecord(startDate: day("2026-08-20"), endDate: day("2026-08-24")),
            PeriodRecord(startDate: day("2026-09-17"), endDate: day("2026-09-21")),
            PeriodRecord(startDate: day("2026-10-01"), endDate: nil),
        ]
        let report = make(mode: .tryingToConceive, range: .cycles(3), input: DoctorReportInput(periods: periods))
        #expect(report.sections.map(\.kind) == [.periods, .cycleLengths])
        for case .periods(let rows) in report.sections {
            #expect(rows == [
                DoctorReport.PeriodRow(start: day("2026-08-20"), lengthDays: 5, isOngoing: false),
                DoctorReport.PeriodRow(start: day("2026-09-17"), lengthDays: 5, isOngoing: false),
                DoctorReport.PeriodRow(start: day("2026-10-01"), lengthDays: 2, isOngoing: true),
            ])
        }
        for case .cycleLengths(let rows) in report.sections {
            #expect(rows == [
                DoctorReport.CycleLengthRow(start: day("2026-08-20"), days: 28),
                DoctorReport.CycleLengthRow(start: day("2026-09-17"), days: 14),
            ])
        }
    }

    @Test func moodsAndSymptomsOfCycleMode() {
        let logs = [
            CycleLogRecord(day: day("2026-09-30"), moods: [.tired], symptoms: [.cramps, .nausea]),
            CycleLogRecord(day: day("2026-10-01"), symptoms: [.nausea]),
            CycleLogRecord(day: day("2026-10-02"), flow: .light),
        ]
        let periods = [PeriodRecord(startDate: day("2026-09-20"), endDate: day("2026-09-24"))]
        let report = make(mode: .tryingToConceive, range: .cycles(3), input: DoctorReportInput(logs: logs, periods: periods))
        #expect(report.sections.map(\.kind) == [.periods, .moodsAndSymptoms])
        for case .moodsAndSymptoms(let rows) in report.sections {
            #expect(rows == [DoctorReport.MoodSymptomRow(day: day("2026-09-30"), moods: [.tired], symptoms: [.cramps])])
        }
    }

    @Test func bbtAndLH() {
        let logs = [
            CycleLogRecord(day: day("2026-09-29"), lh: .negative),
            CycleLogRecord(day: day("2026-09-30"), lh: .positive, bbtCelsius: 36.55),
            CycleLogRecord(day: day("2026-10-01"), mucus: .creamy),
        ]
        let periods = [PeriodRecord(startDate: day("2026-09-20"), endDate: day("2026-09-24"))]
        let report = make(mode: .tryingToConceive, range: .cycles(3), input: DoctorReportInput(logs: logs, periods: periods))
        #expect(report.sections.map(\.kind) == [.periods, .bbtAndLH])
        for case .bbtAndLH(let rows) in report.sections {
            #expect(rows == [
                DoctorReport.BodyRow(day: day("2026-09-29"), bbtCelsius: nil, lh: .negative),
                DoctorReport.BodyRow(day: day("2026-09-30"), bbtCelsius: 36.55, lh: .positive),
            ])
        }
    }

    @Test func partnerModeHasNoSections() {
        let input = DoctorReportInput(weights: [weight("2026-10-01", 61)])
        #expect(make(mode: .partner, input: input).sections.isEmpty)
        #expect(ReportSectionKind.kinds(for: .partner).isEmpty)
        #expect(ReportSectionKind.kinds(for: .pregnant) == [.kicks, .contractions, .weights, .symptoms, .appointments])
        #expect(ReportSectionKind.kinds(for: .tryingToConceive) == [.periods, .cycleLengths, .moodsAndSymptoms, .bbtAndLH])
    }

    @Test func thePreviewFlagNeedsUITesting() {
        #expect(UITestLaunchOptions(arguments: ["-uiTesting", "-uiTestingReportPreview"]).reportPreview)
        #expect(!UITestLaunchOptions(arguments: ["-uiTestingReportPreview"]).reportPreview)
        #expect(!UITestLaunchOptions(arguments: ["-uiTesting"]).reportPreview)
    }
}
