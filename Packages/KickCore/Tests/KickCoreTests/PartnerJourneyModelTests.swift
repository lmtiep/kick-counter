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

    /// An error or no iCloud does not reset the Knowledge tab's trimester; leaving does.
    @Test func theTrimesterSurvivesTransientStates() async throws {
        let now = date("2026-10-02T12:00:00Z")
        let sharing = try await accepted(publishing: sample)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        await model.refresh()
        await sharing.setFailure(.iCloudUnavailable)
        await model.refresh()
        #expect(model.state == .iCloudUnavailable)
        #expect(model.trimester(now: now, calendar: utcCalendar) == 2)
        model.leave()
        #expect(model.trimester(now: now, calendar: utcCalendar) == nil)
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

    /// Overlapping refreshes (appear, push, pull) share one fetch.
    @Test func overlappingRefreshesShareOneFetch() async throws {
        let sharing = GatedJourneySharing(snapshot: sample, gateFetch: true)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        let first = Task { await model.refresh() }
        let second = Task { await model.refresh() }
        await sharing.waitUntilFetchIsWaiting()
        for _ in 0..<5 { await Task.yield() }
        await sharing.release()
        await first.value
        await second.value
        #expect(await sharing.fetchCount == 1)
        #expect(model.state == .snapshot(sample))
    }

    /// A fetch that finishes after "Leave" changes nothing.
    @Test func aFetchFinishingAfterLeavingIsIgnored() async throws {
        let sharing = GatedJourneySharing(snapshot: sample, gateFetch: true)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        let refresh = Task { await model.refresh() }
        await sharing.waitUntilFetchIsWaiting()
        model.leave()
        await sharing.release()
        await refresh.value
        #expect(model.state == .loading)
        #expect(defaults.data(forKey: SettingsKey.partnerCachedSnapshot) == nil)
    }

    /// Subscribing that finishes after "Leave" does not count: the next refresh subscribes again.
    @Test func subscribingThatFinishesAfterLeavingIsDoneAgain() async throws {
        let sharing = GatedJourneySharing(snapshot: sample, gateRegister: true)
        let model = PartnerJourneyModel(sharing: sharing, defaults: defaults)
        let refresh = Task { await model.refresh() }
        await sharing.waitUntilRegisterIsWaiting()
        model.leave()
        await sharing.release()
        await refresh.value
        #expect(await sharing.fetchCount == 0)
        await model.refresh()
        #expect(await sharing.registerCount == 2)
        #expect(model.state == .snapshot(sample))
    }
}

/// A `PartnerSharing` whose first fetch or subscription waits for `release()`.
private actor GatedJourneySharing: PartnerSharing {
    let snapshot: PartnerSnapshot
    private var gateFetch: Bool
    private var gateRegister: Bool
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private(set) var fetchCount = 0
    private(set) var registerCount = 0
    private var fetchWaiting = false
    private var registerWaiting = false

    init(snapshot: PartnerSnapshot, gateFetch: Bool = false, gateRegister: Bool = false) {
        self.snapshot = snapshot
        self.gateFetch = gateFetch
        self.gateRegister = gateRegister
    }

    func release() {
        let waiting = continuations
        continuations.removeAll()
        waiting.forEach { $0.resume() }
    }

    func waitUntilFetchIsWaiting() async {
        while !fetchWaiting { await Task.yield() }
    }

    func waitUntilRegisterIsWaiting() async {
        while !registerWaiting { await Task.yield() }
    }

    private func gate() async {
        await withCheckedContinuation { continuations.append($0) }
    }

    func shareStatus() async throws -> PartnerShareStatus { .notShared }
    func prepareShare() async throws -> PartnerShareHandle { PartnerShareHandle(payload: nil) }
    func publish(_ snapshot: PartnerSnapshot) async throws {}
    func stopSharing() async throws {}
    func accept(_ invitation: PartnerInvitation) async throws {}

    func fetchSharedSnapshot() async throws -> PartnerSnapshot? {
        fetchCount += 1
        if gateFetch {
            gateFetch = false
            fetchWaiting = true
            await gate()
        }
        return snapshot
    }

    func registerForChanges() async throws {
        registerCount += 1
        if gateRegister {
            gateRegister = false
            registerWaiting = true
            await gate()
        }
    }
}
