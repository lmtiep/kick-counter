import Foundation
import KickCore

/// A `DoctorReport` as text in the app language, ready to lay out: header
/// lines and tables of strings. Numbers only; nothing is interpreted here.
struct ReportContent: Equatable {
    struct Column: Equatable {
        let title: String
        /// Relative width.
        let weight: CGFloat
    }

    struct Table: Equatable {
        let title: String
        let columns: [Column]
        let rows: [[String]]
    }

    let title: String
    let headerLines: [String]
    let tables: [Table]
    let footer: String

    init(_ report: DoctorReport) {
        let header = report.header
        var lines = [
            L10n.reportPDFGenerated(Formatting.dayMonthYear(header.generatedAt)),
            L10n.reportPDFRange(Formatting.dayMonthYear(header.start), Formatting.dayMonthYear(header.end)),
        ]
        if let name = header.name { lines.insert(L10n.reportPDFName(name), at: 0) }
        if let week = header.week { lines.append(L10n.reportPDFWeek(L10n.pregnancyWeekLabel(week))) }
        if let due = header.dueDate { lines.append(L10n.reportPDFDue(Formatting.dayMonthYear(due))) }
        if let days = header.averageCycleLength { lines.append(L10n.reportPDFAverageCycle(days)) }
        if let days = header.averagePeriodLength { lines.append(L10n.reportPDFAveragePeriod(days)) }
        title = L10n.reportPDFTitle
        headerLines = lines
        tables = report.sections.map(Self.table)
        footer = L10n.reportPDFFooter
    }

    private static let dash = "–"

    private static func table(_ section: DoctorReport.Section) -> Table {
        let title = L10n.reportSection(section.kind)
        switch section {
        case .kicks(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColDate, weight: 3), .init(title: L10n.reportColTime, weight: 2),
                          .init(title: L10n.reportColMovements, weight: 2), .init(title: L10n.reportColDuration, weight: 2)],
                rows: rows.map {
                    [Formatting.dayMonthYear($0.startedAt), Formatting.time($0.startedAt), "\($0.count)", Formatting.duration($0.duration)]
                }
            )
        case .contractions(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColDate, weight: 3), .init(title: L10n.reportColTime, weight: 2),
                          .init(title: L10n.reportColCount, weight: 2), .init(title: L10n.reportColAvgDuration, weight: 2),
                          .init(title: L10n.reportColAvgInterval, weight: 2)],
                rows: rows.map {
                    [Formatting.dayMonthYear($0.startedAt), Formatting.time($0.startedAt), "\($0.count)",
                     $0.averageDuration.map(Formatting.duration) ?? dash, $0.averageInterval.map(Formatting.duration) ?? dash]
                }
            )
        case .weights(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColDate, weight: 3), .init(title: L10n.reportColWeight, weight: 3)],
                rows: rows.map { [Formatting.dayMonthYear($0.day), Formatting.kilograms($0.kg)] }
            )
        case .symptoms(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColDate, weight: 2), .init(title: L10n.reportColSymptoms, weight: 5)],
                rows: rows.map { [Formatting.dayMonthYear($0.day), $0.symptoms.map(L10n.symptom).joined(separator: ", ")] }
            )
        case .appointments(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColDate, weight: 3), .init(title: L10n.reportColAppointment, weight: 3),
                          .init(title: L10n.reportColNote, weight: 4)],
                rows: rows.map {
                    [Formatting.dateTime($0.date), $0.isDone ? "\($0.title) (\(L10n.reportValueDone))" : $0.title, $0.note.isEmpty ? dash : $0.note]
                }
            )
        case .periods(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColStart, weight: 3), .init(title: L10n.reportColDays, weight: 3)],
                rows: rows.map {
                    [Formatting.dayMonthYear($0.start), $0.isOngoing ? "\($0.lengthDays) (\(L10n.reportValueOngoing))" : "\($0.lengthDays)"]
                }
            )
        case .cycleLengths(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColStart, weight: 3), .init(title: L10n.reportColDays, weight: 3)],
                rows: rows.map { [Formatting.dayMonthYear($0.start), "\($0.days)"] }
            )
        case .moodsAndSymptoms(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColDate, weight: 2), .init(title: L10n.reportColMoods, weight: 3),
                          .init(title: L10n.reportColSymptoms, weight: 4)],
                rows: rows.map {
                    [Formatting.dayMonthYear($0.day),
                     $0.moods.isEmpty ? dash : $0.moods.map(L10n.mood).joined(separator: ", "),
                     $0.symptoms.isEmpty ? dash : $0.symptoms.map(L10n.symptom).joined(separator: ", ")]
                }
            )
        case .bbtAndLH(let rows):
            return Table(
                title: title,
                columns: [.init(title: L10n.reportColDate, weight: 3), .init(title: L10n.reportColBBT, weight: 2),
                          .init(title: L10n.reportColLH, weight: 2)],
                rows: rows.map {
                    [Formatting.dayMonthYear($0.day), $0.bbtCelsius.map(Formatting.temperature) ?? dash,
                     $0.lh.map { $0 == .positive ? L10n.dayLogLHPositive : L10n.dayLogLHNegative } ?? dash]
                }
            )
        }
    }
}
