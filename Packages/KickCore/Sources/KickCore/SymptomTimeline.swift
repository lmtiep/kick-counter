import Foundation

/// One pregnancy week of the Symptoms screen's list.
public struct SymptomWeekSection: Equatable, Sendable, Identifiable {
    public let week: Int
    /// Newest first.
    public let logs: [CycleLogRecord]

    public var id: Int { week }
}

/// The Symptoms screen's list (spec §3.2): days logged in pregnancy mode,
/// grouped by gestational week.
public enum SymptomTimeline {
    /// Logs with a mood, a pregnancy symptom or a note, from the first day of
    /// the last period to today; newest week first, newest day first.
    public static func sections(
        _ logs: [CycleLogRecord],
        dueDate: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [SymptomWeekSection] {
        let today = calendar.startOfDay(for: now)
        var weeks: [Int] = []
        var grouped: [Int: [CycleLogRecord]] = [:]
        for log in logs.sorted(by: { $0.day > $1.day }) where log.day <= today && showsInPregnancy(log) {
            guard let week = PregnancyTimeline(dueDate: dueDate, now: log.day, calendar: calendar)?.week.weeks else { continue }
            if grouped[week] == nil { weeks.append(week) }
            grouped[week, default: []].append(log)
        }
        return weeks.sorted(by: >).map { SymptomWeekSection(week: $0, logs: grouped[$0] ?? []) }
    }

    static func showsInPregnancy(_ log: CycleLogRecord) -> Bool {
        !log.moods.isEmpty || !log.symptoms(for: .pregnant).isEmpty
            || !log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
