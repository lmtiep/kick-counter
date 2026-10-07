import Foundation
import Testing
@testable import KickCore

/// Phase 8 spec §5.1: the mother's share status and the Profile row.
@MainActor
struct PartnerShareCoordinatorTests {
    @Test func startsUnknownThenReadsTheStatus() async {
        let coordinator = PartnerShareCoordinator(sharing: FakePartnerSharing(mother: .joined))
        #expect(coordinator.status == .unknown)
        await coordinator.refresh()
        #expect(coordinator.status == .joined(participantCount: 1))
        #expect(coordinator.isSharing)
    }

    @Test func startingSharingCreatesTheShare() async throws {
        let sharing = FakePartnerSharing()
        let coordinator = PartnerShareCoordinator(sharing: sharing)
        await coordinator.refresh()
        #expect(coordinator.status == .notShared)
        #expect(!coordinator.isSharing)
        let handle = await coordinator.startSharing()
        #expect(handle != nil)
        #expect(coordinator.status == .invited)
        #expect(!coordinator.isWorking)
        #expect(try await sharing.shareStatus() == .invited)
    }

    @Test func startingAgainKeepsJoined() async {
        let coordinator = PartnerShareCoordinator(sharing: FakePartnerSharing(mother: .joined))
        await coordinator.refresh()
        _ = await coordinator.startSharing()
        #expect(coordinator.status == .joined(participantCount: 1))
    }

    @Test func stoppingSharingResetsTheStatus() async throws {
        let sharing = FakePartnerSharing(mother: .invited)
        let coordinator = PartnerShareCoordinator(sharing: sharing)
        await coordinator.refresh()
        #expect(await coordinator.stopSharing())
        #expect(coordinator.status == .notShared)
        #expect(try await sharing.shareStatus() == .notShared)
    }

    @Test func failuresBecomeICloudUnavailableOrFailed() async {
        let sharing = FakePartnerSharing()
        let coordinator = PartnerShareCoordinator(sharing: sharing)
        await sharing.setFailure(.iCloudUnavailable)
        await coordinator.refresh()
        #expect(coordinator.status == .iCloudUnavailable)
        await sharing.setFailure(.retryable)
        #expect(await coordinator.startSharing() == nil)
        #expect(coordinator.status == .failed)
        #expect(await coordinator.stopSharing() == false)
        #expect(coordinator.status == .failed)
        await sharing.setFailure(nil)
        await coordinator.refresh()
        #expect(coordinator.status == .notShared)
    }

    @Test func aFullICloudHasItsOwnStatusAndVerificationIsRetryable() async {
        let sharing = FakePartnerSharing()
        let coordinator = PartnerShareCoordinator(sharing: sharing)
        await coordinator.refresh()
        await sharing.setFailure(.iCloudFull)
        #expect(await coordinator.startSharing() == nil)
        #expect(coordinator.status == .iCloudFull)
        #expect(!coordinator.isSharing)
        await sharing.setFailure(.needsVerification)
        #expect(await coordinator.startSharing() == nil)
        #expect(coordinator.status == .failed)
    }

    /// Review fix 2: a stop that failed (the system sheet already removed the
    /// CKShare) deletes the zone on the next check, even after a relaunch.
    @Test func anInterruptedStopIsFinishedOnTheNextRefresh() async throws {
        let defaults = makeTestDefaults()
        let sharing = FakePartnerSharing(mother: .invited)
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: defaults)
        await coordinator.refresh()
        await sharing.setFailure(.retryable)
        #expect(await coordinator.stopSharing() == false)
        #expect(coordinator.hasPendingZoneDeletion)
        #expect(defaults.bool(forKey: SettingsKey.partnerPendingZoneDeletion))

        await sharing.setFailure(nil)
        let relaunched = PartnerShareCoordinator(sharing: sharing, defaults: defaults)
        await relaunched.refresh()
        #expect(relaunched.status == .notShared)
        #expect(!relaunched.hasPendingZoneDeletion)
        #expect(defaults.object(forKey: SettingsKey.partnerPendingZoneDeletion) == nil)
        #expect(try await sharing.shareStatus() == .notShared)
    }

    @Test func sharingAgainDropsThePendingZoneDeletion() async throws {
        let sharing = FakePartnerSharing(mother: .invited)
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: makeTestDefaults())
        await sharing.setFailure(.retryable)
        #expect(await coordinator.stopSharing() == false)
        await sharing.setFailure(nil)
        #expect(await coordinator.startSharing() != nil)
        #expect(!coordinator.hasPendingZoneDeletion)
        await coordinator.refresh()
        #expect(coordinator.status == .invited)
    }

    @Test func theRowFollowsTheSpecTable() {
        #expect(PartnerShareRow(status: .iCloudFull, hasDueDate: true) == .iCloudFull)
        #expect(PartnerShareRow(status: .notShared, hasDueDate: true) == .notShared)
        #expect(PartnerShareRow(status: .invited, hasDueDate: true) == .invited)
        #expect(PartnerShareRow(status: .joined(participantCount: 1), hasDueDate: true) == .joined)
        #expect(PartnerShareRow(status: .notShared, hasDueDate: false) == .needsDueDate)
        #expect(PartnerShareRow(status: .unknown, hasDueDate: false) == .needsDueDate)
        #expect(PartnerShareRow(status: .iCloudUnavailable, hasDueDate: true) == .iCloudUnavailable)
        #expect(PartnerShareRow(status: .unknown, hasDueDate: true) == .checking)
        #expect(PartnerShareRow(status: .failed, hasDueDate: true) == .failed)
        // Already sharing: still manageable without a due date.
        #expect(PartnerShareRow(status: .invited, hasDueDate: false) == .invited)
    }

    @Test func onlySomeRowsAreTappableOrStoppable() {
        #expect(PartnerShareRow.notShared.isEnabled && !PartnerShareRow.notShared.canStop)
        #expect(PartnerShareRow.invited.isEnabled && PartnerShareRow.invited.canStop)
        #expect(PartnerShareRow.joined.isEnabled && PartnerShareRow.joined.canStop)
        #expect(PartnerShareRow.failed.isEnabled && !PartnerShareRow.failed.canStop)
        // Tapping checks again, like a failure.
        #expect(PartnerShareRow.iCloudFull.isEnabled && !PartnerShareRow.iCloudFull.canStop)
        #expect(!PartnerShareRow.needsDueDate.isEnabled)
        #expect(!PartnerShareRow.iCloudUnavailable.isEnabled)
        #expect(!PartnerShareRow.checking.isEnabled)
    }
}
