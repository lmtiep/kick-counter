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
    case spotting
    case pregnancyTest(PregnancyTestResult)
    case sex(SexLog)
    case sexDrive(SexDrive)
    case note
}

extension CycleLogRecord {
    /// Flow · spotting · moods · that mode's symptoms · temperature · LH · mucus ·
    /// pregnancy test · sex · sex drive · note (spec §3.1, 1.2 spec §1). Values this build cannot read are left out.
    public func summaryItems(mode: AppMode) -> [CycleLogSummaryItem] {
        var items: [CycleLogSummaryItem] = []
        if let flow { items.append(.flow(flow)) }
        if spotting { items.append(.spotting) }
        items += moods.map(CycleLogSummaryItem.mood)
        items += symptoms(for: mode).map(CycleLogSummaryItem.symptom)
        if let bbtCelsius { items.append(.temperature(bbtCelsius)) }
        if let lh { items.append(.lh(lh)) }
        if let mucus { items.append(.mucus(mucus)) }
        if let pregnancyTest { items.append(.pregnancyTest(pregnancyTest)) }
        if let sex { items.append(.sex(sex)) }
        if let sexDrive { items.append(.sexDrive(sexDrive)) }
        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { items.append(.note) }
        return items
    }
}
