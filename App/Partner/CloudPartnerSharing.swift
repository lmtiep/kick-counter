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
    /// The `prepareShare()` in flight: overlapping calls wait for it instead of
    /// each creating a share.
    private var preparing: Task<PartnerShareHandle, Error>?
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
        if let preparing { return try await preparing.value }
        let task = Task { try await makeShare() }
        preparing = task
        defer { preparing = nil }
        return try await task.value
    }

    private func makeShare() async throws -> PartnerShareHandle {
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
            let savedShare: CKShare
            do {
                let saved = try await database.modifyRecords(saving: [share], deleting: [], savePolicy: .ifServerRecordUnchanged)
                guard let result = saved.saveResults[share.recordID], let value = try result.get() as? CKShare else {
                    throw PartnerSharingError.failed(code: -2)
                }
                savedShare = value
            } catch let error as CKError where Self.primary(error).code == .serverRecordChanged {
                // Another device created the share in the meantime: use that one.
                guard let existing = try await fetchShare() else { throw error }
                savedShare = existing
            }
            return PartnerShareHandle(payload: CloudShareBox(share: savedShare, container: container))
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
        try await save(payload: data, version: snapshot.version)
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
            var unpublished = false
            for zone in zones {
                let recordID = CKRecord.ID(recordName: Self.recordName, zoneID: zone.zoneID)
                let record: CKRecord
                do {
                    record = try await database.record(for: recordID)
                } catch {
                    // The zone is shared but the mother has not published yet.
                    if let ckError = error as? CKError, Self.primary(ckError).code == .unknownItem {
                        unpublished = true
                        continue
                    }
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
            if newest == nil, unpublished { throw PartnerSharingError.notReadyYet }
            return newest
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

    /// Upserts `current` with only the changed keys (`.changedKeys` never
    /// conflicts). A transient error (zone busy, service unavailable, rate
    /// limited) is retried once after `retryAfterSeconds`, at most 5 s (1 s
    /// when CloudKit gives none).
    private func save(payload: Data, version: Int) async throws {
        do {
            try await saveOnce(payload: payload, version: version)
        } catch let error as CKError where Self.isTransient(error) {
            let delay = min(Self.primary(error).retryAfterSeconds ?? 1, 5)
            logger.info("Saving the snapshot hit a transient error; retrying in \(delay) s")
            try? await Task.sleep(for: .seconds(delay))
            do {
                try await saveOnce(payload: payload, version: version)
            } catch {
                throw Self.mapSave(error)
            }
        } catch {
            throw Self.mapSave(error)
        }
    }

    private func saveOnce(payload: Data, version: Int) async throws {
        let recordID = CKRecord.ID(recordName: Self.recordName, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[Self.payloadKey] = payload as NSData
        record[Self.versionKey] = version as NSNumber
        let result = try await container.privateCloudDatabase.modifyRecords(
            saving: [record], deleting: [], savePolicy: .changedKeys, atomically: true
        )
        if let saved = result.saveResults[recordID] { _ = try saved.get() }
    }

    /// A missing zone while publishing means the mother is not sharing.
    private static func mapSave(_ error: Error) -> PartnerSharingError {
        isMissing(error) ? .notShared : map(error)
    }

    /// Worth one more try after a short wait.
    static func isTransient(_ error: CKError) -> Bool {
        switch primary(error).code {
        case .zoneBusy, .serviceUnavailable, .requestRateLimited: true
        default: false
        }
    }

    /// The error that matters: for a partial failure, the first item error
    /// that is not just "the batch failed because of another item".
    static func primary(_ error: CKError) -> CKError {
        guard error.code == .partialFailure, let partial = error.partialErrorsByItemID?.values else { return error }
        let errors = partial.compactMap { $0 as? CKError }
        return errors.first { $0.code != .batchRequestFailed } ?? errors.first ?? error
    }

    /// The zone, the share or the record does not exist (any more).
    static func isMissing(_ error: Error) -> Bool {
        guard let error = error as? CKError else { return false }
        switch error.code {
        case .zoneNotFound, .unknownItem, .userDeletedZone:
            return true
        case .partialFailure:
            let errors = (error.partialErrorsByItemID?.values).map(Array.init) ?? []
            let relevant = errors.filter { ($0 as? CKError)?.code != .batchRequestFailed }
            return !relevant.isEmpty && relevant.allSatisfy(isMissing)
        default:
            return false
        }
    }

    /// Spec §4.2: every CloudKit error becomes a `PartnerSharingError`.
    static func map(_ error: Error) -> PartnerSharingError {
        if let error = error as? PartnerSharingError { return error }
        guard let error = error as? CKError else {
            let nsError = error as NSError
            logger.error("Partner sharing failed: \(nsError.domain) \(nsError.code) \(error.localizedDescription)")
            return .failed(code: -1)
        }
        switch error.code {
        case .notAuthenticated, .accountTemporarilyUnavailable, .managedAccountRestricted:
            return .iCloudUnavailable
        case .quotaExceeded:
            return .iCloudFull
        case .participantMayNeedVerification:
            return .needsVerification
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy, .serverResponseLost:
            return .retryable
        case .zoneNotFound, .unknownItem, .userDeletedZone:
            return .notShared
        case .partialFailure:
            let primary = primary(error)
            if primary.code != .partialFailure { return map(primary) }
            return .failed(code: error.errorCode)
        default:
            logger.error("Partner sharing failed: \(error.code.rawValue) \(error.localizedDescription)")
            return .failed(code: error.errorCode)
        }
    }
}
