import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "partner-share")

/// The mother's side of partner sharing (phase 8 spec §5.1): the share status
/// behind the Profile row, starting and stopping the share. Never blocks the UI:
/// every call is async and failures only change `status`.
@MainActor
@Observable
public final class PartnerShareCoordinator {
    public enum Status: Equatable, Sendable {
        /// Not checked yet.
        case unknown
        case notShared
        case invited
        case joined(participantCount: Int)
        case iCloudUnavailable
        /// The mother's iCloud storage is full; tapping the row checks again.
        case iCloudFull
        /// Network or server trouble; tapping the row checks again.
        case failed
    }

    public private(set) var status: Status = .unknown
    /// True while the share is being created or deleted.
    public private(set) var isWorking = false

    private let sharing: any PartnerSharing

    public init(sharing: any PartnerSharing) {
        self.sharing = sharing
    }

    public var isSharing: Bool {
        switch status {
        case .invited, .joined: true
        case .unknown, .notShared, .iCloudUnavailable, .iCloudFull, .failed: false
        }
    }

    public func refresh() async {
        do {
            switch try await sharing.shareStatus() {
            case .notShared: status = .notShared
            case .invited: status = .invited
            case .joined(let count): status = .joined(participantCount: count)
            }
        } catch {
            status = Self.failureStatus(error)
        }
    }

    /// Creates the zone and the share if needed and returns the handle for the
    /// sharing controller; nil when that failed (`status` says why).
    public func startSharing() async -> PartnerShareHandle? {
        isWorking = true
        defer { isWorking = false }
        do {
            let handle = try await sharing.prepareShare()
            if !isSharing { status = .invited }
            return handle
        } catch {
            status = Self.failureStatus(error)
            return nil
        }
    }

    /// Deletes the zone, the share and the snapshot. Returns false when that failed.
    @discardableResult
    public func stopSharing() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharing.stopSharing()
            status = .notShared
            return true
        } catch {
            status = Self.failureStatus(error)
            return false
        }
    }

    static func failureStatus(_ error: Error) -> Status {
        logger.error("Partner sharing: \(String(describing: error))")
        guard let error = error as? PartnerSharingError else { return .failed }
        switch error {
        case .iCloudUnavailable:
            return .iCloudUnavailable
        case .iCloudFull:
            return .iCloudFull
        // Verification is the partner's step; on the mother's side it is just a retryable failure.
        case .retryable, .needsVerification, .notShared, .unreadableSnapshot, .notReadyYet, .ownInvitation, .failed:
            return .failed
        }
    }
}

/// What the Profile row shows (spec §5.1 table).
public enum PartnerShareRow: Equatable, Sendable {
    case checking
    case notShared
    case invited
    case joined
    case needsDueDate
    case iCloudUnavailable
    case iCloudFull
    case failed

    /// A mother already sharing can still manage or stop the share without a due date.
    public init(status: PartnerShareCoordinator.Status, hasDueDate: Bool) {
        switch status {
        case .invited: self = .invited
        case .joined: self = .joined
        case .iCloudUnavailable: self = .iCloudUnavailable
        case _ where !hasDueDate: self = .needsDueDate
        case .unknown: self = .checking
        case .notShared: self = .notShared
        case .iCloudFull: self = .iCloudFull
        case .failed: self = .failed
        }
    }

    public var isEnabled: Bool {
        switch self {
        case .notShared, .invited, .joined, .iCloudFull, .failed: true
        case .checking, .needsDueDate, .iCloudUnavailable: false
        }
    }

    /// "Stop sharing" appears under the row.
    public var canStop: Bool {
        self == .invited || self == .joined
    }
}
