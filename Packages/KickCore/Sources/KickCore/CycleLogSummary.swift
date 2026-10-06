import Foundation

/// One part of a day's one-line summary (Today's "How are you feeling today?"
/// card, the calendar's day card): the app turns each into words.
public enum CycleLogSummaryItem: Equatable, Sendable {
    case flow(MenstrualFlow)
    case mood(Mood)
    case symptom(Symptom)
    case temperature(Double)
    case lh(LHResult)
    case mucus(CervicalMucus)
    case note
}

extension CycleLogRecord {
    /// Flow · moods · that mode's symptoms · temperature · LH · mucus · note
    /// (spec §3.1). Values this build cannot read are left out.
    public func summaryItems(mode: AppMode) -> [CycleLogSummaryItem] {
        var items: [CycleLogSummaryItem] = []
        if let flow { items.append(.flow(flow)) }
        items += moods.map(CycleLogSummaryItem.mood)
        items += symptoms(for: mode).map(CycleLogSummaryItem.symptom)
        if let bbtCelsius { items.append(.temperature(bbtCelsius)) }
        if let lh { items.append(.lh(lh)) }
        if let mucus { items.append(.mucus(mucus)) }
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { items.append(.note) }
        return items
    }
}
