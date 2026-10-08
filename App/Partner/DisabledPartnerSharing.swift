import KickCore

/// Partner sharing while `AppFeatures.cloudSync` is off (version 1.0, App Review
/// 5.1.3(ii)): never touches CloudKit. The mother is never sharing, and every
/// action fails as if iCloud were unavailable.
struct DisabledPartnerSharing: PartnerSharing {
    // Mother
    func shareStatus() async throws -> PartnerShareStatus { .notShared }
    func prepareShare() async throws -> PartnerShareHandle { throw PartnerSharingError.iCloudUnavailable }
    func publish(_ snapshot: PartnerSnapshot) async throws { throw PartnerSharingError.iCloudUnavailable }
    func stopSharing() async throws { throw PartnerSharingError.iCloudUnavailable }
    // Partner
    func accept(_ invitation: PartnerInvitation) async throws { throw PartnerSharingError.iCloudUnavailable }
    func fetchSharedSnapshot() async throws -> PartnerSnapshot? { nil }
    func registerForChanges() async throws { throw PartnerSharingError.iCloudUnavailable }
}
