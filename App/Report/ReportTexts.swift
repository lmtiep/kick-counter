import KickCore

/// Words of the report for the doctor (screen and PDF), in the app language.
extension L10n {
    static var reportRow: String { t("report.row") }
    static var reportIntro: String { t("report.intro") }
    static var reportRangeTitle: String { t("report.range.title") }
    static var reportSectionsTitle: String { t("report.sections.title") }
    static var reportNameTitle: String { t("report.name.title") }
    static var reportNamePlaceholder: String { t("report.name.placeholder") }
    static var reportNameFootnote: String { t("report.name.footnote") }
    static var reportExport: String { t("report.export") }
    static var reportEmpty: String { t("report.empty") }
    static var reportFailed: String { t("report.failed") }

    static func reportRange(_ range: ReportRange) -> String {
        switch range {
        case .weeks(2): t("report.range.weeks2")
        case .weeks: t("report.range.weeks4")
        case .wholePregnancy: t("report.range.pregnancy")
        case .cycles(3): t("report.range.cycles3")
        case .cycles: t("report.range.cycles6")
        }
    }

    static func reportSection(_ kind: ReportSectionKind) -> String {
        switch kind {
        case .kicks: t("report.section.kicks")
        case .contractions: t("report.section.contractions")
        case .weights: t("report.section.weights")
        case .symptoms: t("report.section.symptoms")
        case .appointments: t("report.section.appointments")
        case .periods: t("report.section.periods")
        case .cycleLengths: t("report.section.cycleLengths")
        case .moodsAndSymptoms: t("report.section.moodsAndSymptoms")
        case .bbtAndLH: t("report.section.bbtAndLH")
        }
    }

    // MARK: - The PDF

    static var reportPDFTitle: String { t("report.pdf.title") }
    static var reportPDFFooter: String { t("report.pdf.footer") }
    static func reportPDFGenerated(_ date: String) -> String { String(format: t("report.pdf.generated"), date) }
    static func reportPDFRange(_ from: String, _ to: String) -> String { String(format: t("report.pdf.range"), from, to) }
    static func reportPDFName(_ name: String) -> String { String(format: t("report.pdf.name"), name) }
    static func reportPDFWeek(_ week: String) -> String { String(format: t("report.pdf.week"), week) }
    static func reportPDFDue(_ date: String) -> String { String(format: t("report.pdf.due"), date) }
    static func reportPDFAverageCycle(_ days: Int) -> String { String(format: t("report.pdf.avgCycle"), days) }
    static func reportPDFAveragePeriod(_ days: Int) -> String { String(format: t("report.pdf.avgPeriod"), days) }
    static func reportPDFPage(_ page: Int, of total: Int) -> String { String(format: t("report.pdf.page"), page, total) }

    static var reportColDate: String { t("report.col.date") }
    static var reportColTime: String { t("report.col.time") }
    static var reportColMovements: String { t("report.col.movements") }
    static var reportColDuration: String { t("report.col.duration") }
    static var reportColWeight: String { t("report.col.weight") }
    static var reportColSymptoms: String { t("report.col.symptoms") }
    static var reportColMoods: String { t("report.col.moods") }
    static var reportColAppointment: String { t("report.col.appointment") }
    static var reportColNote: String { t("report.col.note") }
    static var reportColCount: String { t("report.col.count") }
    static var reportColAvgDuration: String { t("report.col.avgDuration") }
    static var reportColAvgInterval: String { t("report.col.avgInterval") }
    static var reportColStart: String { t("report.col.start") }
    static var reportColDays: String { t("report.col.days") }
    static var reportColBBT: String { t("report.col.bbt") }
    static var reportColLH: String { t("report.col.lh") }
    static var reportColStatus: String { t("report.col.status") }
    static var reportValueReached: String { t("report.value.reached") }
    static var reportValueStopped: String { t("report.value.stopped") }
    static var reportValueOngoing: String { t("report.value.ongoing") }
    static var reportValueDone: String { t("report.value.done") }
}
