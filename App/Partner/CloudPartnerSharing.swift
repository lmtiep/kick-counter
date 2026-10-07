import CloudKit
import KickCore
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "partner-sharing")

/// The share and its container, for `UICloudSharingController` (`PartnerShareHandle.payload`).
struct CloudShareBox: @unchecked Sendable {
    let share: CKShare
    let container: CKContainer
}

/// The metadata of an opened invitation (`PartnerInvitation.payload`).
struct CloudInvitationBox: @unchecked Sendable {
    let metadata: CKShare.Metadata
}

/// `PartnerSharing` over CloudKit (phase 8 spec §4.2). The mother's private
/// database holds the zone `PartnerShare` with one `Snapshot` record named
/// `current` and a zone-wide, read-only `CKShare`; the partner reads it from
/// the shared database. The SwiftData store and its sync are not touched.
/// Tested by hand (`docs/partner-sharing-manual-test.md`): CI has no iCloud.
actor CloudPartnerSharing: PartnerSharing {
    static let containerIdentifier = "iCloud.com.lmtiep.kickcounter"
    static let zoneName = "PartnerShare"
    static let recordType = "Snapshot"
    static let recordName = "current"
    static let payloadKey = "payload"
    static let versionKey = "version"
    static let subscriptionID = "partner-shared-database"

    private let container: CKContainer
    private let zoneID = CKRecordZone.ID(zoneName: CloudPartnerSharing.zoneName, ownerName: CKCurrentUserDefaultName)

    init(container: CKContainer = CKContainer(identifier: CloudPartnerSharing.containerIdentifier)) {
        self.container = container
    }

    // MARK: - Mother

    func shareStatus() async throws -> PartnerShareStatus {
        try await ensureAccount()
        do {
            guard let share = try await fetchShare() else { return .notShared }
            let joined = share.participants.filter { $0.role != .owner && $0.acceptanceStatus == .accepted }.count
            return joined > 0 ? .joined(participantCount: joined) : .invited
        } catch {
            if Self.isMissing(error) { return .notShared }
            throw Self.map(error)
        }
    }

    func prepareShare() async throws -> PartnerShareHandle {
        try await ensureAccount()
        do {
            let database = container.privateCloudDatabase
            // Saving a zone that already exists changes nothing.
            let zones = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
            if let result = zones.saveResults[zoneID] { _ = try result.get() }
            if let existing = try await fetchShare() {
                return PartnerShareHandle(payload: CloudShareBox(share: existing, container: container))
            }
            let share = CKShare(recordZoneID: zoneID)
            share[CKShare.SystemFieldKey.title] = "Luna Mom" as NSString
            share.publicPermission = .none
            let saved = try await database.modifyRecords(saving: [share], deleting: [], savePolicy: .ifServerRecordUnchanged)
            guard let result = saved.saveResults[share.recordID], let savedShare = try result.get() as? CKShare else {
                throw PartnerSharingError.failed(code: -2)
            }
            return PartnerShareHandle(payload: CloudShareBox(share: savedShare, container: container))
        } catch let error as PartnerSharingError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func publish(_ snapshot: PartnerSnapshot) async throws {
        try await ensureAccount()
        let data: Data
        do {
            data = try snapshot.encoded()
        } catch {
            throw PartnerSharingError.failed(code: -3)
        }
        try await save(payload: data, version: snapshot.version, retryOnConflict: true)
    }

    func stopSharing() async throws {
        try await ensureAccount()
        do {
            let result = try await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
            if let deletion = result.deleteResults[zoneID] { try deletion.get() }
        } catch {
            if Self.isMissing(error) { return }
            throw Self.map(error)
        }
    }

    // MARK: - Partner

    func accept(_ invitation: PartnerInvitation) async throws {
        guard let box = invitation.payload as? CloudInvitationBox else { throw PartnerSharingError.failed(code: -4) }
        if box.metadata.participantRole == .owner { throw PartnerSharingError.ownInvitation }
        try await ensureAccount()
        do {
            _ = try await container.accept(box.metadata)
        } catch {
            throw Self.map(error)
        }
    }

    func fetchSharedSnapshot() async throws -> PartnerSnapshot? {
        try await ensureAccount()
        let database = container.sharedCloudDatabase
        do {
            let zones = try await database.allRecordZones().filter { $0.zoneID.zoneName == Self.zoneName }
            var newest: PartnerSnapshot?
            var unreadable = false
            for zone in zones {
                let recordID = CKRecord.ID(recordName: Self.recordName, zoneID: zone.zoneID)
                let record: CKRecord
                do {
                    record = try await database.record(for: recordID)
                } catch {
                    if Self.isMissing(error) { continue }
                    throw error
                }
                guard let data = record[Self.payloadKey] as? Data, let snapshot = PartnerSnapshot.decode(data) else {
                    unreadable = true
                    continue
                }
                if newest.map({ snapshot.updatedAt > $0.updatedAt }) ?? true { newest = snapshot }
            }
            if newest == nil, unreadable { throw PartnerSharingError.unreadableSnapshot }
            return newest
        } catch let error as PartnerSharingError {
            throw error
        } catch {
            if Self.isMissing(error) { return nil }
            throw Self.map(error)
        }
    }

    func registerForChanges() async throws {
        try await ensureAccount()
        let subscription = CKDatabaseSubscription(subscriptionID: Self.subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            let result = try await container.sharedCloudDatabase.modifySubscriptions(saving: [subscription], deleting: [])
            if let saved = result.saveResults[Self.subscriptionID] { _ = try saved.get() }
        } catch {
            throw Self.map(error)
        }
    }

    // MARK: - Helpers

    private func ensureAccount() async throws {
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            throw Self.map(error)
        }
        guard status == .available else { throw PartnerSharingError.iCloudUnavailable }
    }

    /// The zone-wide share of `PartnerShare`, or nil when there is none.
    private func fetchShare() async throws -> CKShare? {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        do {
            return try await container.privateCloudDatabase.record(for: shareID) as? CKShare
        } catch {
            if Self.isMissing(error) { return nil }
            throw error
        }
    }

    /// Upserts `current` with only the changed keys; a `serverRecordChanged`
    /// conflict is retried once.
    private func save(payload: Data, version: Int, retryOnConflict: Bool) async throws {
        let recordID = CKRecord.ID(recordName: Self.recordName, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[Self.payloadKey] = payload as NSData
        record[Self.versionKey] = version as NSNumber
        do {
            let result = try await container.privateCloudDatabase.modifyRecords(
                saving: [record], deleting: [], savePolicy: .changedKeys, atomically: true
            )
            if let saved = result.saveResults[recordID] { _ = try saved.get() }
        } catch let error as CKError where error.code == .serverRecordChanged && retryOnConflict {
            logger.info("Snapshot changed on the server; saving again")
            try await save(payload: payload, version: version, retryOnConflict: false)
        } catch let error as PartnerSharingError {
            throw error
        } catch {
            if Self.isMissing(error) { throw PartnerSharingError.notShared }
            throw Self.map(error)
        }
    }

    /// The zone, the share or the record does not exist (any more).
    static func isMissing(_ error: Error) -> Bool {
        guard let error = error as? CKError else { return false }
        switch error.code {
        case .zoneNotFound, .unknownItem, .userDeletedZone:
            return true
        case .partialFailure:
            guard let partial = error.partialErrorsByItemID, !partial.isEmpty else { return false }
            return partial.values.allSatisfy(isMissing)
        default:
            return false
        }
    }

    /// Spec §4.2: every CloudKit error becomes a `PartnerSharingError`.
    static func map(_ error: Error) -> PartnerSharingError {
        if let error = error as? PartnerSharingError { return error }
        guard let error = error as? CKError else {
            logger.error("Partner sharing failed: \(error.localizedDescription)")
            return .failed(code: -1)
        }
        switch error.code {
        case .notAuthenticated, .accountTemporarilyUnavailable, .managedAccountRestricted:
            return .iCloudUnavailable
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .serverResponseLost:
            return .retryable
        case .zoneNotFound, .unknownItem, .userDeletedZone:
            return .notShared
        case .partialFailure:
            if let first = error.partialErrorsByItemID?.values.first { return map(first) }
            return .failed(code: error.errorCode)
        default:
            logger.error("Partner sharing failed: \(error.code.rawValue) \(error.localizedDescription)")
            return .failed(code: error.errorCode)
        }
    }
}
