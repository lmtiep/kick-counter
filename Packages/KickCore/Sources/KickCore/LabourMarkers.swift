import Foundation

/// A moment in labour that is not a contraction, such as "Vỡ ối" (edit spec
/// 2026-11-06). `kind` is the raw value stored, so a kind a newer build wrote
/// travels through a backup unchanged; this build shows only `waterBroke`.
public struct LabourMarkerRecord: Equatable, Sendable, Identifiable {
    public static let waterBroke = "waterBroke"

    public let id: UUID
    public var kind: String
    public var at: Date

    public init(id: UUID = UUID(), kind: String = LabourMarkerRecord.waterBroke, at: Date) {
        self.id = id
        self.kind = kind
        self.at = at
    }

    public var isWaterBroke: Bool { kind == Self.waterBroke }
}

/// Storage for the labour markers.
@MainActor
public protocol LabourMarkerRepository: AnyObject {
    /// Every marker, oldest first.
    func markers() throws -> [LabourMarkerRecord]
    /// Inserts `record`, or replaces the one with its id.
    func save(_ record: LabourMarkerRecord) throws
    /// Ids that are not stored are ignored.
    func delete(ids: [UUID]) throws
}

/// Keeps markers in memory only: the default of `ContractionCoordinator` for
/// callers (and old tests) that do not pass a store.
@MainActor
public final class InMemoryLabourMarkerRepository: LabourMarkerRepository {
    private var stored: [LabourMarkerRecord] = []

    public init() {}

    public func markers() throws -> [LabourMarkerRecord] { stored.sorted { $0.at < $1.at } }

    public func save(_ record: LabourMarkerRecord) throws {
        if let index = stored.firstIndex(where: { $0.id == record.id }) {
            stored[index] = record
        } else {
            stored.append(record)
        }
    }

    public func delete(ids: [UUID]) throws {
        stored.removeAll { ids.contains($0.id) }
    }
}
