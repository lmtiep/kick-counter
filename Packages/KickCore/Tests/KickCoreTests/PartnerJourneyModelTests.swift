import Foundation
import Testing
@testable import KickCore

/// Phase 8 spec §5.2–§5.3: the partner's states, cache and leaving.
@MainActor
struct PartnerJourneyModelTests {
    let defaults = makeTestDefaults()
    let sample = PartnerSnapshotTests.sample

    private func accepted(publishing snapshot: PartnerSnapshot?) async throws -> FakePartnerSharing {
        let sharing = FakePartnerSharing()
        _ = try await sharing.prepareShare()
        try await sharing.accept(PartnerInvitation(payload: nil))
        if let snapshot { try await sharing.publish(snapshot) }
        return sharing
    }

    @Test func loadsTheSnapshotCachesItAndSubscribes() async throws {
        let sharing = try await accepted(publishing: sample)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        #expect(model.state == .loading)
        await model.refresh()
        #expect(model.state == .snapshot(sample))
        #expect(defaults.data(forKey: SettingsKey.partnerCachedSnapshot).flatMap(PartnerSnapshot.decode) == sample)
        #expect(await sharing.isRegisteredForChanges)
    }

    @Test func startsFromTheCachedSnapshot() async throws {
        defaults.set(try sample.encoded(), forKey: SettingsKey.partnerCachedSnapshot)
        let model = PartnerJourneyModel(sharing: FakePartnerSharing(), defaults: defaults)
        #expect(model.state == .snapshot(sample))
        #expect(model.snapshot == sample)
    }

    @Test func aShareThatIsGoneIsStoppedAndClearsTheCache() async throws {
        let sharing = try await accepted(publishing: sample)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        try await sharing.stopSharing()
        await model.refresh()
        #expect(model.state == .stopped)
        #expect(defaults.data(forKey: SettingsKey.partnerCachedSnapshot) == nil)
    }

    @Test func aCorruptSnapshotIsTheErrorState() async throws {
        let sharing = try await accepted(publishing: nil)
        await sharing.storeRawPayload(Data("corrupt".utf8))
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        #expect(model.state == .failed)
    }

    @Test func aNetworkFailureKeepsTheCachedSnapshot() async throws {
        let sharing = try await accepted(publishing: sample)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        await sharing.setFailure(.retryable)
        await model.refresh()
        #expect(model.state == .snapshot(sample))
    }

    @Test func aNetworkFailureWithoutACacheIsTheErrorState() async {
        let sharing = FakePartnerSharing()
        await sharing.setFailure(.retryable)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        #expect(model.state == .failed)
        await sharing.setFailure(nil)
        await model.refresh()
        #expect(model.state == .stopped)
        #expect(await sharing.isRegisteredForChanges)
    }

    @Test func noICloudIsItsOwnState() async {
        let sharing = FakePartnerSharing()
        await sharing.setFailure(.iCloudUnavailable)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        #expect(model.state == .iCloudUnavailable)
    }

    @Test func theTrimesterComesFromTheSharedDueDate() async throws {
        let now = date("2026-10-02T12:00:00Z")
        let model = PartnerJourneyModel(sharing: try await accepted(publishing: sample), defaults: defaults)
        #expect(model.trimester(now: now, calendar: utcCalendar) == nil)
        await model.refresh()
        #expect(model.trimester(now: now, calendar: utcCalendar) == 2)
    }

    @Test func leavingRestoresTheModeAndClearsTheCache() async throws {
        AppMode.save(.tryingToConceive, to: defaults)
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        _ = await PartnerAcceptance.accept(PartnerInvitation(payload: nil), sharing: try await accepted(publishing: sample), defaults: defaults)
        let model = PartnerJourneyModel(sharing: try await accepted(publishing: sample), defaults: defaults)
        await model.refresh()
        #expect(model.leave() == .tryingToConceive)
        #expect(AppMode.load(from: defaults) == .tryingToConceive)
        #expect(defaults.data(forKey: SettingsKey.partnerCachedSnapshot) == nil)
        #expect(defaults.bool(forKey: SettingsKey.hasCompletedOnboarding))
        #expect(model.state == .loading)
    }

    @Test func leavingAfterAFreshInstallShowsOnboarding() async throws {
        _ = await PartnerAcceptance.accept(PartnerInvitation(payload: nil), sharing: FakePartnerSharing(), defaults: defaults)
        #expect(defaults.bool(forKey: SettingsKey.hasCompletedOnboarding))
        let model = PartnerJourneyModel(sharing: FakePartnerSharing(), defaults: defaults)
        #expect(model.leave() == .pregnant)
        #expect(!defaults.bool(forKey: SettingsKey.hasCompletedOnboarding))
        #expect(!defaults.bool(forKey: SettingsKey.partnerSkippedOnboarding))
    }

    /// The share is there but the mother has not published yet: still loading,
    /// not an error and not "stopped sharing".
    @Test func aShareWithNothingPublishedYetKeepsLoading() async throws {
        let sharing = try await accepted(publishing: nil)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        #expect(model.state == .loading)
        #expect(defaults.data(forKey: SettingsKey.partnerCachedSnapshot) == nil)
        #expect(await sharing.isRegisteredForChanges)
        try await sharing.publish(sample)
        await model.refresh()
        #expect(model.state == .snapshot(sample))
    }

    @Test func notReadyYetKeepsTheCachedSnapshot() async throws {
        defaults.set(try sample.encoded(), forKey: SettingsKey.partnerCachedSnapshot)
        let model = PartnerJourneyModel(sharing: try await accepted(publishing: nil), defaults: defaults)
        await model.refresh()
        #expect(model.state == .snapshot(sample))
        #expect(defaults.data(forKey: SettingsKey.partnerCachedSnapshot) != nil)
    }

    /// A full iCloud or an account to verify is trouble "Try again" may fix.
    @Test(arguments: [PartnerSharingError.iCloudFull, .needsVerification])
    func iCloudTroubleIsARetryableError(_ failure: PartnerSharingError) async throws {
        let sharing = try await accepted(publishing: sample)
        await sharing.setFailure(failure)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        #expect(model.state == .failed)
        await sharing.setFailure(nil)
        await model.refresh()
        #expect(model.state == .snapshot(sample))
        await sharing.setFailure(failure)
        await model.refresh()
        #expect(model.state == .snapshot(sample))
    }
}
