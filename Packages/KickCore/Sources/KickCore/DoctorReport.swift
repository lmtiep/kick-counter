import Foundation

/// How far back "Report for your doctor" looks. The range always ends with today.
public enum ReportRange: Equatable, Sendable {
    /// The last `7 × n` days, today included.
    case weeks(Int)
    /// From the first day of the last period (due date − 280 days), or from the
    /// earliest record when there is no due date.
    case wholePregnancy
    /// From the start of the n-th latest period; the current cycle counts as one.
    case cycles(Int)
}

/// The sections a report can hold, by mode.
public enum ReportSectionKind: String, CaseIterable, Sendable {
    // Pregnancy
    case kicks
    case contractions
    case weights
    case symptoms
    case appointments
    // Cycle tracking
    case periods
    case cycleLengths
    case moodsAndSymptoms
    case bbtAndLH

    /// The sections of one mode, in the order the report prints them.
    public static func kinds(for mode: AppMode) -> [ReportSectionKind] {
        switch mode {
        case .pregnant: [.kicks, .contractions, .weights, .symptoms, .appointments]
        case .tryingToConceive: [.periods, .cycleLengths, .moodsAndSymptoms, .bbtAndLH]
        case .partner: []
        }
    }
}

/// Everything `DoctorReport.make` reads, as the mother's own records.
public struct DoctorReportInput: Sendable {
    public var sessions: [SessionState]
    public var contractions: [ContractionRecord]
    public var weights: [WeightRecord]
    public var logs: [CycleLogRecord]
    public var appointments: [AppointmentRecord]
    public var periods: [PeriodRecord]
    public var dueDate: Date?

    public init(
        sessions: [SessionState] = [],
        contractions: [ContractionRecord] = [],
        weights: [WeightRecord] = [],
        logs: [CycleLogRecord] = [],
        appointments: [AppointmentRecord] = [],
        periods: [PeriodRecord] = [],
        dueDate: Date? = nil
    ) {
        self.sessions = sessions
        self.contractions = contractions
        self.weights = weights
        self.logs = logs
        self.appointments = appointments
        self.periods = periods
        self.dueDate = dueDate
    }
}

/// The data of the printable report for the doctor: a header and sections of
/// typed rows, numbers only. It holds no wording, so no interpretation or
/// advice can enter here; the app formats it in its language and lays it out.
public struct DoctorReport: Equatable, Sendable {
    public struct Header: Equatable, Sendable {
        public var mode: AppMode
        public var generatedAt: Date
        /// First and last day of the range (start of the day).
        public var start: Date
        public var end: Date
        /// Typed at export time; trimmed, nil when blank. Never stored.
        public var name: String?
        /// Pregnancy: the week on `generatedAt` and the due date.
        public var week: GestationalWeek?
        public var dueDate: Date?
        /// Cycle tracking: the averages of `CycleHistory`.
        public var averageCycleLength: Int?
        public var averagePeriodLength: Int?
    }

    public struct KickRow: Equatable, Sendable {
        public var startedAt: Date
        public var count: Int
        /// Start to end; nil when the session has no end.
        public var duration: TimeInterval?
        /// The session reached its target (completed) rather than being stopped.
        public var reachedTarget: Bool
    }

    public struct ContractionRow: Equatable, Sendable {
        public var startedAt: Date
        public var count: Int
        public var averageDuration: TimeInterval?
        public var averageInterval: TimeInterval?
        /// Hook for `feat/contraction-edit`'s "water broke" mark: nothing sets it yet.
        public var waterBrokeAt: Date?
    }

    public struct WeightRow: Equatable, Sendable {
        public var day: Date
        public var kg: Double
    }

    public struct SymptomRow: Equatable, Sendable {
        public var day: Date
        public var symptoms: [Symptom]
    }

    public struct AppointmentRow: Equatable, Sendable {
        public var date: Date
        public var title: String
        public var note: String
        public var isDone: Bool
    }

    public struct PeriodRow: Equatable, Sendable {
        public var start: Date
        public var lengthDays: Int
        public var isOngoing: Bool
    }

    public struct CycleLengthRow: Equatable, Sendable {
        public var start: Date
        public var days: Int
    }

    public struct MoodSymptomRow: Equatable, Sendable {
        public var day: Date
        public var moods: [Mood]
        public var symptoms: [Symptom]
    }

    public struct BodyRow: Equatable, Sendable {
        public var day: Date
        public var bbtCelsius: Double?
        public var lh: LHResult?
    }

    public enum Section: Equatable, Sendable {
        case kicks([KickRow])
        case contractions([ContractionRow])
        case weights([WeightRow])
        case symptoms([SymptomRow])
        case appointments([AppointmentRow])
        case periods([PeriodRow])
        case cycleLengths([CycleLengthRow])
        case moodsAndSymptoms([MoodSymptomRow])
        case bbtAndLH([BodyRow])

        public var kind: ReportSectionKind {
            switch self {
            case .kicks: .kicks
            case .contractions: .contractions
            case .weights: .weights
            case .symptoms: .symptoms
            case .appointments: .appointments
            case .periods: .periods
            case .cycleLengths: .cycleLengths
            case .moodsAndSymptoms: .moodsAndSymptoms
            case .bbtAndLH: .bbtAndLH
            }
        }
    }

    public let header: Header
    /// Selected sections of the mode that have rows, in `ReportSectionKind.kinds(for:)` order.
    public let sections: [Section]

    /// Nothing to print: the export is pointless.
    public var isEmpty: Bool { sections.isEmpty }

    public static func make(
        mode: AppMode,
        range: ReportRange,
        include: Set<ReportSectionKind>,
        input: DoctorReportInput,
        name: String? = nil,
        now: Date,
        calendar: Calendar = .current
    ) -> DoctorReport {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let start = rangeStart(range, input: input, today: today, calendar: calendar)
        let window = start..<max(tomorrow, start)
        let periods = input.periods
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { $0.startDate <= today }
            .sorted { $0.startDate < $1.startDate }
        let logs = input.logs
            .map { CycleRules.normalized($0, calendar: calendar) }
            .filter { window.contains($0.day) }
            .sorted { $0.day < $1.day }

        var header = Header(
            mode: mode, generatedAt: now, start: start, end: today,
            name: trimmed(name), week: nil, dueDate: nil, averageCycleLength: nil, averagePeriodLength: nil
        )
        switch mode {
        case .pregnant:
            header.dueDate = input.dueDate
            header.week = input.dueDate.flatMap { PregnancyTimeline(dueDate: $0, now: now, calendar: calendar)?.week }
        case .tryingToConceive:
            // The averages cover the chosen cycles only, not the whole history.
            let chosen = input.periods.filter { calendar.startOfDay(for: $0.startDate) >= start }
            let history = CycleHistory.make(periods: chosen, logs: [], now: now, calendar: calendar)
            header.averageCycleLength = history.averageCycleLength
            header.averagePeriodLength = history.averagePeriodLength
        case .partner:
            break
        }

        let sections: [Section?] = ReportSectionKind.kinds(for: mode).map { kind in
            guard include.contains(kind) else { return nil }
            switch kind {
            case .kicks:
                return .kicks(kickRows(input.sessions, in: window))
            case .contractions:
                return .contractions(contractionRows(input.contractions, in: window, now: now))
            case .weights:
                let rows = input.weights
                    .map { WeightRules.normalized($0, calendar: calendar) }
                    .filter { window.contains($0.day) }
                    .sorted { $0.day < $1.day }
                    .map { WeightRow(day: $0.day, kg: $0.kg) }
                return .weights(rows)
            case .symptoms:
                let rows = logs.compactMap { log -> SymptomRow? in
                    let symptoms = log.symptoms(for: .pregnant)
                    return symptoms.isEmpty ? nil : SymptomRow(day: log.day, symptoms: symptoms)
                }
                return .symptoms(rows)
            case .appointments:
                let rows = input.appointments
                    .filter { window.contains($0.date) }
                    .sorted { $0.date < $1.date }
                    .map { AppointmentRow(date: $0.date, title: $0.title, note: $0.note, isDone: $0.isDone) }
                return .appointments(rows)
            case .periods:
                let rows = periods.filter { window.contains($0.startDate) }.map { period in
                    let days = CycleRules.dayRange(of: period, today: today, calendar: calendar)
                    let length = (calendar.dateComponents([.day], from: days.lowerBound, to: days.upperBound).day ?? 0) + 1
                    return PeriodRow(start: period.startDate, lengthDays: length, isOngoing: period.endDate == nil)
                }
                return .periods(rows)
            case .cycleLengths:
                let cycles = CycleHistory.make(periods: input.periods, logs: [], now: now, calendar: calendar).cycles
                let rows = cycles.reversed().compactMap { cycle -> CycleLengthRow? in
                    guard let length = cycle.length, window.contains(cycle.start) else { return nil }
                    return CycleLengthRow(start: cycle.start, days: length)
                }
                return .cycleLengths(rows)
            case .moodsAndSymptoms:
                let rows = logs.compactMap { log -> MoodSymptomRow? in
                    let symptoms = log.symptoms(for: .tryingToConceive)
                    return log.moods.isEmpty && symptoms.isEmpty
                        ? nil : MoodSymptomRow(day: log.day, moods: log.moods, symptoms: symptoms)
                }
                return .moodsAndSymptoms(rows)
            case .bbtAndLH:
                let rows = logs.compactMap { log -> BodyRow? in
                    log.bbtCelsius == nil && log.lh == nil ? nil : BodyRow(day: log.day, bbtCelsius: log.bbtCelsius, lh: log.lh)
                }
                return .bbtAndLH(rows)
            }
        }
        return DoctorReport(header: header, sections: sections.compactMap { $0 }.filter { !$0.isEmpty })
    }

    private static func rangeStart(_ range: ReportRange, input: DoctorReportInput, today: Date, calendar: Calendar) -> Date {
        switch range {
        case .weeks(let weeks):
            return calendar.date(byAdding: .day, value: 1 - 7 * max(weeks, 1), to: today) ?? today
        case .wholePregnancy:
            if let dueDate = input.dueDate,
               let lmp = calendar.date(
                   byAdding: .day, value: -PregnancyTimeline.pregnancyLengthDays, to: calendar.startOfDay(for: dueDate)
               ) {
                return min(lmp, today)
            }
            let dates = input.sessions.map(\.startedAt) + input.contractions.map(\.startedAt) + input.weights.map(\.day)
                + input.logs.map(\.day) + input.appointments.map(\.date)
            return min(dates.min().map { calendar.startOfDay(for: $0) } ?? today, today)
        case .cycles(let cycles):
            let starts = input.periods.map { calendar.startOfDay(for: $0.startDate) }.filter { $0 <= today }.sorted()
            return starts.suffix(max(cycles, 1)).first ?? today
        }
    }

    private static func trimmed(_ name: String?) -> String? {
        let text = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private static func kickRows(_ sessions: [SessionState], in window: Range<Date>) -> [KickRow] {
        // Every finished session: reached the target, stopped by her, or ended by the app.
        sessions
            .filter { $0.status != .active && window.contains($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }
            .map {
                KickRow(startedAt: $0.startedAt, count: $0.count, duration: $0.duration, reachedTarget: $0.status == .completed)
            }
    }

    private static func contractionRows(_ records: [ContractionRecord], in window: Range<Date>, now: Date) -> [ContractionRow] {
        ContractionStats(contractions: records, now: now, week: nil).episodes
            .filter { window.contains($0.startedAt) }
            .map {
                ContractionRow(
                    startedAt: $0.startedAt, count: $0.count,
                    averageDuration: $0.averageDuration, averageInterval: $0.averageInterval, waterBrokeAt: nil
                )
            }
    }
}

private extension DoctorReport.Section {
    var isEmpty: Bool {
        switch self {
        case .kicks(let rows): rows.isEmpty
        case .contractions(let rows): rows.isEmpty
        case .weights(let rows): rows.isEmpty
        case .symptoms(let rows): rows.isEmpty
        case .appointments(let rows): rows.isEmpty
        case .periods(let rows): rows.isEmpty
        case .cycleLengths(let rows): rows.isEmpty
        case .moodsAndSymptoms(let rows): rows.isEmpty
        case .bbtAndLH(let rows): rows.isEmpty
        }
    }
}
