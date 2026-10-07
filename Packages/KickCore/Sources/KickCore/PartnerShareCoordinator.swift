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
    /// A short diagnostic code set whenever `status` becomes `.failed`, shown
    /// in the Profile row so TestFlight reports can tell which error occurred.
    /// Cleared on any other status.
    public private(set) var failureCode: String?
    /// True while the share is being created or deleted.
    public private(set) var isWorking = false

    private let sharing: any PartnerSharing
    /// Remembers a stop that did not finish (`SettingsKey.partnerPendingZoneDeletion`); nil keeps it in memory only.
    private let defaults: UserDefaults?
    private var pendingZoneDeletionInMemory = false

    public init(sharing: any PartnerSharing, defaults: UserDefaults? = nil) {
        self.sharing = sharing
        self.defaults = defaults
    }

    /// A stop failed after it was asked for (e.g. the system sheet already
    /// deleted the CKShare but deleting the zone failed): `refresh()` deletes
    /// the zone before anything else.
    public private(set) var hasPendingZoneDeletion: Bool {
        get { defaults?.bool(forKey: SettingsKey.partnerPendingZoneDeletion) ?? pendingZoneDeletionInMemory }
        set {
            if let defaults {
                if newValue {
                    defaults.set(true, forKey: SettingsKey.partnerPendingZoneDeletion)
                } else {
                    defaults.removeObject(forKey: SettingsKey.partnerPendingZoneDeletion)
                }
            } else {
                pendingZoneDeletionInMemory = newValue
            }
        }
    }

    public var isSharing: Bool {
        switch status {
        case .invited, .joined: true
        case .unknown, .notShared, .iCloudUnavailable, .iCloudFull, .failed: false
        }
    }

    public func refresh() async {
        if hasPendingZoneDeletion {
            await stopSharing()
            return
        }
        do {
            switch try await sharing.shareStatus() {
            case .notShared: setStatus(.notShared)
            case .invited: setStatus(.invited)
            case .joined(let count): setStatus(.joined(participantCount: count))
            }
        } catch {
            setStatus(Self.failureStatus(error), failureCode: Self.failureCodeString(error))
        }
    }

    /// Creates the zone and the share if needed and returns the handle for the
    /// sharing controller; nil when that failed (`status` says why).
    public func startSharing() async -> PartnerShareHandle? {
        isWorking = true
        defer { isWorking = false }
        // Sharing again: the zone an earlier stop left behind is the one to use.
        hasPendingZoneDeletion = false
        do {
            let handle = try await sharing.prepareShare()
            if !isSharing { setStatus(.invited) }
            return handle
        } catch {
            setStatus(Self.failureStatus(error), failureCode: Self.failureCodeString(error))
            return nil
        }
    }

    /// Deletes the zone, the share and the snapshot. Returns false when that
    /// failed; the next `refresh()` then tries again.
    @discardableResult
    public func stopSharing() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        hasPendingZoneDeletion = true
        do {
            try await sharing.stopSharing()
            hasPendingZoneDeletion = false
            setStatus(.notShared)
            return true
        } catch {
            setStatus(Self.failureStatus(error), failureCode: Self.failureCodeString(error))
            return false
        }
    }

    /// The mother left pregnancy mode (ended pregnancy tracking or switched to
    /// trying to conceive): what she shared must not stay visible to the
    /// partner. Stops the share unless it is known not to exist and forgets
    /// the last upload. A stop that fails is remembered and finished by the
    /// next `refresh()` / `refreshOutsidePregnancy(publisher:)`.
    public func stopSharingAfterLeavingPregnancy(publisher: PartnerPublisher?) async {
        guard status != .notShared || hasPendingZoneDeletion else { return }
        await stopSharing()
        publisher?.forgetPublished()
    }

    /// The check made outside pregnancy mode: finishes a stop that did not
    /// complete, and stops a share that is somehow still active.
    public func refreshOutsidePregnancy(publisher: PartnerPublisher?) async {
        if !hasPendingZoneDeletion {
            await refresh()
            guard isSharing else { return }
        }
        await stopSharing()
        publisher?.forgetPublished()
    }

    /// Sets `status` and, only when it becomes `.failed`, the diagnostic
    /// `failureCode`; any other status clears it.
    private func setStatus(_ newStatus: Status, failureCode: String? = nil) {
        status = newStatus
        self.failureCode = newStatus == .failed ? failureCode : nil
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

    /// The short diagnostic code shown in the Profile row (only used when
    /// `failureStatus(_:)` returns `.failed`).
    static func failureCodeString(_ error: Error) -> String {
        guard let error = error as? PartnerSharingError else { return "x" }
        switch error {
        case .failed(let code): return "\(code)"
        case .retryable: return "net"
        case .needsVerification: return "verify"
        case .notReadyYet: return "notready"
        case .unreadableSnapshot: return "data"
        case .ownInvitation: return "own"
        case .notShared: return "zone"
        case .iCloudUnavailable, .iCloudFull: return "x"
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
