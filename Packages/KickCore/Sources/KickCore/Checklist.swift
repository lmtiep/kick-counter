import Foundation

/// Which list a stored checklist row belongs to.
public enum ChecklistKind: String, CaseIterable, Sendable {
    case bag
    case question
}

/// The four groups of the hospital bag, in the order they are shown.
public enum BagGroup: String, CaseIterable, Identifiable, Sendable {
    case documents
    case mother
    case baby
    case companion

    public var id: String { rawValue }
}

/// Value snapshot of the SwiftData `ChecklistItem`. A built-in bag item is stored only
/// once the mother touches it (ticks or hides it), with `builtInID` set and empty `text`;
/// a custom bag item or a question carries its own `text`.
public struct ChecklistItemRecord: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var kind: ChecklistKind
    /// The bag group of a custom bag item; nil for built-ins (the catalog knows) and questions.
    public var group: BagGroup?
    public var builtInID: String?
    public var text: String
    public var isDone: Bool
    public var isHidden: Bool
    public var order: Int
    /// The appointment a question is for; nil while it is unassigned.
    public var appointmentID: UUID?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: ChecklistKind,
        group: BagGroup? = nil,
        builtInID: String? = nil,
        text: String = "",
        isDone: Bool = false,
        isHidden: Bool = false,
        order: Int = 0,
        appointmentID: UUID? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.group = group
        self.builtInID = builtInID
        self.text = text
        self.isDone = isDone
        self.isHidden = isHidden
        self.order = order
        self.appointmentID = appointmentID
        self.createdAt = createdAt
    }
}

public enum ChecklistText {
    public static let maxLength = 300

    /// The text as stored: trimmed and capped; nil when nothing is left.
    public static func clean(_ text: String, maxLength: Int = ChecklistText.maxLength) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}

public struct ChecklistProgress: Equatable, Sendable {
    public var done: Int
    public var total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }

    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

/// One built-in bag item: its id and group. The text is localised by id
/// (`bag.item.<id>` in the string catalog), so no wording lives here.
public struct BagBuiltIn: Equatable, Sendable {
    public let id: String
    public let group: BagGroup
}

/// Practical items only: no medicines and no medical items, so nothing here needs a doctor's review.
public enum BagCatalog {
    public static let items: [BagBuiltIn] = [
        (BagGroup.documents, ["cccd", "prenatalBook", "bhyt", "referral", "cash", "fatherId", "marriageCert"]),
        (.mother, [
            "maternityPads", "nursingBra", "pajamas", "underwear", "slippers",
            "toiletries", "towel", "phoneCharger", "snacks", "socks",
        ]),
        (.baby, [
            "babyClothes", "babyHat", "babyMitts", "babyBlanket", "diapers", "muslin", "babyTowel", "babyWipes",
        ]),
        (.companion, [
            "companionClothes", "companionMat", "companionFood", "companionCharger", "companionCash", "companionToiletries",
        ]),
    ].flatMap { group, ids in ids.map { BagBuiltIn(id: $0, group: group) } }

    public static func stringKey(forItem id: String) -> String { "bag.item.\(id)" }
    public static func stringKey(forGroup group: BagGroup) -> String { "bag.group.\(group.rawValue)" }
}

/// One row of the bag screen: a built-in (with or without a stored override) or a custom item.
public struct BagEntry: Equatable, Sendable, Identifiable {
    public var builtInID: String?
    /// The stored row's id; nil for a built-in the mother has not touched.
    public var itemID: UUID?
    public var group: BagGroup
    /// Empty for built-ins: they are localised by `builtInID`.
    public var text: String
    public var isDone: Bool

    public var id: String { builtInID ?? itemID?.uuidString ?? text }
    public var isCustom: Bool { builtInID == nil }
}

public struct BagSection: Equatable, Sendable, Identifiable {
    public var group: BagGroup
    public var entries: [BagEntry]

    public var id: BagGroup { group }
}

public enum BagList {
    /// The built-in list merged with the stored rows: hidden built-ins leave their group, ticks
    /// come from the overrides, and custom items follow the built-ins of their group by
    /// `order` (then creation time). Rows for built-ins this build does not know are ignored.
    public static func sections(overrides: [ChecklistItemRecord]) -> [BagSection] {
        let bag = overrides.filter { $0.kind == .bag }
        var byBuiltIn: [String: ChecklistItemRecord] = [:]
        for row in bag.filter({ $0.builtInID != nil }).sorted(by: { $0.createdAt < $1.createdAt }) {
            byBuiltIn[row.builtInID ?? ""] = row
        }
        let customs = bag
            .filter { $0.builtInID == nil && $0.group != nil }
            .sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
        return BagGroup.allCases.map { group in
            let builtIns: [BagEntry] = BagCatalog.items
                .filter { $0.group == group }
                .compactMap { item in
                    let row = byBuiltIn[item.id]
                    guard row?.isHidden != true else { return nil }
                    return BagEntry(builtInID: item.id, itemID: row?.id, group: group, text: "", isDone: row?.isDone ?? false)
                }
            let own = customs.filter { $0.group == group }.map {
                BagEntry(builtInID: nil, itemID: $0.id, group: group, text: $0.text, isDone: $0.isDone)
            }
            return BagSection(group: group, entries: builtIns + own)
        }
    }

    public static func progress(_ sections: [BagSection]) -> ChecklistProgress {
        let entries = sections.flatMap(\.entries)
        return ChecklistProgress(done: entries.filter(\.isDone).count, total: entries.count)
    }

    /// How many built-ins are hidden (the screen offers to show them again).
    public static func hiddenCount(overrides: [ChecklistItemRecord]) -> Int {
        let known = Set(BagCatalog.items.map(\.id))
        return Set(overrides.filter { $0.kind == .bag && $0.isHidden }.compactMap(\.builtInID).filter(known.contains)).count
    }
}

public enum BagRules {
    /// The Today card shows from this week; the Profile row is there in any week.
    public static let todayCardFromWeek = 32

    public static func showsTodayCard(week: Int) -> Bool { week >= todayCardFromWeek }
}
