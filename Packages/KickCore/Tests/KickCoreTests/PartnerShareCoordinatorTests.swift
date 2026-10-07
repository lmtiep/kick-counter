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

    /// A diagnostic code (phase: TestFlight error visibility) lets a failed
    /// share be told apart in a report; it is cleared once sharing succeeds.
    @Test func failureCodeIsSetOnFailureAndClearedOnSuccess() async {
        let sharing = FakePartnerSharing()
        let coordinator = PartnerShareCoordinator(sharing: sharing)
        await sharing.setFailure(.failed(code: 15))
        await coordinator.refresh()
        #expect(coordinator.status == .failed)
        #expect(coordinator.failureCode == "15")
        await sharing.setFailure(nil)
        await coordinator.refresh()
        #expect(coordinator.status == .notShared)
        #expect(coordinator.failureCode == nil)
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

    // MARK: - Leaving pregnancy mode (final review fix 1)

    private func publisherRemembering(_ sharing: FakePartnerSharing, in defaults: UserDefaults) throws -> PartnerPublisher {
        defaults.set(try PartnerSnapshotTests.sample.encoded(), forKey: SettingsKey.partnerPublishedSnapshot)
        return PartnerPublisher(sharing: sharing, isActive: { false }, defaults: defaults)
    }

    /// Ending pregnancy tracking (or switching to trying to conceive) stops the
    /// share: the partner must not keep seeing the last snapshot.
    @Test func leavingPregnancyStopsTheShareAndForgetsTheUpload() async throws {
        let defaults = makeTestDefaults()
        let sharing = FakePartnerSharing(mother: .joined)
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: defaults)
        let publisher = try publisherRemembering(sharing, in: defaults)
        await coordinator.refresh()
        await coordinator.stopSharingAfterLeavingPregnancy(publisher: publisher)
        #expect(coordinator.status == .notShared)
        #expect(!coordinator.hasPendingZoneDeletion)
        #expect(try await sharing.shareStatus() == .notShared)
        #expect(defaults.data(forKey: SettingsKey.partnerPublishedSnapshot) == nil)
    }

    /// The status is not known yet (e.g. right after launch): stop anyway.
    @Test func leavingPregnancyStopsEvenBeforeTheStatusIsKnown() async throws {
        let sharing = FakePartnerSharing(mother: .invited)
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: makeTestDefaults())
        await coordinator.stopSharingAfterLeavingPregnancy(publisher: nil)
        #expect(try await sharing.shareStatus() == .notShared)
    }

    @Test func leavingPregnancyWithoutAShareDoesNothing() async throws {
        let sharing = FakePartnerSharing()
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: makeTestDefaults())
        await coordinator.refresh()
        // Any call to iCloud would fail and leave a pending deletion behind.
        await sharing.setFailure(.retryable)
        await coordinator.stopSharingAfterLeavingPregnancy(publisher: nil)
        #expect(coordinator.status == .notShared)
        #expect(!coordinator.hasPendingZoneDeletion)
    }

    /// Offline when she ends tracking: the stop is remembered and finished by
    /// the next check in trying-to-conceive mode, even after a relaunch.
    @Test func aStopThatFailedWhenLeavingIsFinishedOutsidePregnancy() async throws {
        let defaults = makeTestDefaults()
        let sharing = FakePartnerSharing(mother: .joined)
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: defaults)
        await coordinator.refresh()
        await sharing.setFailure(.retryable)
        await coordinator.stopSharingAfterLeavingPregnancy(publisher: nil)
        #expect(coordinator.hasPendingZoneDeletion)
        await sharing.setFailure(nil)
        #expect(try await sharing.shareStatus() != .notShared)

        let relaunched = PartnerShareCoordinator(sharing: sharing, defaults: defaults)
        let publisher = try publisherRemembering(sharing, in: defaults)
        await relaunched.refreshOutsidePregnancy(publisher: publisher)
        #expect(relaunched.status == .notShared)
        #expect(!relaunched.hasPendingZoneDeletion)
        #expect(try await sharing.shareStatus() == .notShared)
        #expect(defaults.data(forKey: SettingsKey.partnerPublishedSnapshot) == nil)
    }

    /// A share found still active outside pregnancy mode (the mode changed
    /// while the app could not stop it) is stopped.
    @Test func aShareStillActiveOutsidePregnancyIsStopped() async throws {
        let sharing = FakePartnerSharing(mother: .invited)
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: makeTestDefaults())
        await coordinator.refreshOutsidePregnancy(publisher: nil)
        #expect(coordinator.status == .notShared)
        #expect(try await sharing.shareStatus() == .notShared)
    }

    @Test func refreshingOutsidePregnancyWithoutAShareOnlyChecks() async throws {
        let defaults = makeTestDefaults()
        let sharing = FakePartnerSharing()
        let coordinator = PartnerShareCoordinator(sharing: sharing, defaults: defaults)
        let publisher = try publisherRemembering(sharing, in: defaults)
        await coordinator.refreshOutsidePregnancy(publisher: publisher)
        #expect(coordinator.status == .notShared)
        #expect(!coordinator.hasPendingZoneDeletion)
        #expect(defaults.data(forKey: SettingsKey.partnerPublishedSnapshot) != nil)
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
