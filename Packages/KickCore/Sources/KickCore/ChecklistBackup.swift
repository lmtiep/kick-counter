import Foundation

/// A bag or question row in the backup. Kind and group stay raw strings so a value this
/// build does not know is read (and skipped by validation) instead of failing the file.
public struct ChecklistItemDTO: Equatable, Sendable, Codable {
    public var id: UUID
    public var list: String
    public var group: String?
    public var builtInID: String?
    public var text: String
    public var isDone: Bool
    public var isHidden: Bool
    public var order: Int
    public var appointmentID: UUID?
    public var createdAt: Date

    public init(_ record: ChecklistItemRecord) {
        id = record.id
        list = record.kind.rawValue
        group = record.group?.rawValue
        builtInID = record.builtInID
        text = record.text
        isDone = record.isDone
        isHidden = record.isHidden
        order = record.order
        appointmentID = record.appointmentID
        createdAt = record.createdAt
    }

    public var record: ChecklistItemRecord {
        ChecklistItemRecord(
            id: id,
            kind: ChecklistKind(rawValue: list) ?? .bag,
            group: group.flatMap(BagGroup.init(rawValue:)),
            builtInID: builtInID,
            text: text,
            isDone: isDone,
            isHidden: isHidden,
            order: order,
            appointmentID: appointmentID,
            createdAt: createdAt
        )
    }

    /// What the app would accept when entering it: a known list; a built-in override (any id,
    /// the merge ignores one it does not know); otherwise some text, and for a bag item a known group.
    var isValid: Bool {
        guard let kind = ChecklistKind(rawValue: list) else { return false }
        if kind == .bag, builtInID != nil { return true }
        guard ChecklistText.clean(text) != nil else { return false }
        return kind == .question || group.flatMap(BagGroup.init(rawValue:)) != nil
    }
}

extension BackupValidation {
    /// Valid, unique rows; a question for an appointment the file does not carry becomes unassigned.
    static func cleanChecklist(_ items: [ChecklistItemDTO], appointmentIDs: Set<UUID>) -> (items: [ChecklistItemDTO], skipped: Int) {
        var seen = Set<UUID>()
        var kept: [ChecklistItemDTO] = []
        for var item in items {
            guard item.isValid, seen.insert(item.id).inserted else { continue }
            if let appointmentID = item.appointmentID, !appointmentIDs.contains(appointmentID) {
                item.appointmentID = nil
            }
            kept.append(item)
        }
        return (kept, items.count - kept.count)
    }
}
