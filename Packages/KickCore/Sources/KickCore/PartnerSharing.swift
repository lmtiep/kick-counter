import Foundation

/// Where the mother's share stands (phase 8 spec §4.1).
public enum PartnerShareStatus: Equatable, Sendable {
    case notShared
    /// The share exists; nobody has accepted it yet.
    case invited
    /// This many people (not the mother) accepted the invitation.
    case joined(participantCount: Int)
}

/// Errors every `PartnerSharing` implementation maps its failures to (spec §4.2).
public enum PartnerSharingError: Error, Equatable, Sendable {
    /// Not signed in to iCloud (or iCloud is restricted).
    case iCloudUnavailable
    /// The mother's share zone is gone: she is not sharing.
    case notShared
    /// Network or server trouble: trying again later may work.
    case retryable
    /// The shared snapshot exists but this build cannot read it.
    case unreadableSnapshot
    /// The mother opened her own invitation link.
    case ownInvitation
    /// Anything else, with the underlying error code for the log.
    case failed(code: Int)
}

/// What `prepareShare()` returns. The App target's CloudKit implementation puts
/// its share and container in `payload` for `UICloudSharingController`; the
/// fake leaves it nil, and nothing is presented.
public struct PartnerShareHandle: Sendable {
    public let payload: (any Sendable)?

    public init(payload: (any Sendable)?) {
        self.payload = payload
    }
}

/// An invitation the partner opened. `payload` holds the CloudKit share
/// metadata in the app; KickCore never looks inside.
public struct PartnerInvitation: Sendable, Identifiable {
    public let id: UUID
    public let payload: (any Sendable)?

    public init(id: UUID = UUID(), payload: (any Sendable)?) {
        self.id = id
        self.payload = payload
    }
}

/// The iCloud layer of partner sharing (spec §4.1). The mother calls the first
/// four methods, the partner the last three. Implementations throw only
/// `PartnerSharingError`.
public protocol PartnerSharing: Sendable {
    // Mother
    func shareStatus() async throws -> PartnerShareStatus
    /// Creates the share zone and the share if needed.
    func prepareShare() async throws -> PartnerShareHandle
    func publish(_ snapshot: PartnerSnapshot) async throws
    /// Deletes the share zone, and with it the share and the snapshot.
    func stopSharing() async throws
    // Partner
    func accept(_ invitation: PartnerInvitation) async throws
    /// Nil when the share is gone or was never accepted.
    func fetchSharedSnapshot() async throws -> PartnerSnapshot?
    /// Silent notifications when the shared snapshot changes.
    func registerForChanges() async throws
}
