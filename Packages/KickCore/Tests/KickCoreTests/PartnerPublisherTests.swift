import Foundation
import Testing
@testable import KickCore

/// A clock the fake `sleep` moves forward, so the 5 s wait takes no real time.
@MainActor
final class PartnerTestClock {
    var now = date("2026-10-02T12:00:00Z")
}

/// Phase 8 spec §5.1: when the mother's snapshot is uploaded.
@MainActor
struct PartnerPublisherTests {
    let clock = PartnerTestClock()
    let defaults = makeTestDefaults()

    private func snapshot(sessions: Int) -> PartnerSnapshot {
        var snapshot = PartnerSnapshotTests.sample
        snapshot.kicks.sessionsLast7Days = sessions
        return snapshot
    }

    private func makePublisher(_ sharing: FakePartnerSharing, active: Bool = true) -> PartnerPublisher {
        let clock = clock
        return PartnerPublisher(
            sharing: sharing,
            isActive: { active },
            defaults: defaults,
            now: { clock.now },
            sleep: { seconds in await MainActor.run { clock.now += seconds } }
        )
    }

    /// Shared and accepted, so the test can read back what was published.
    private func sharedFake() async throws -> FakePartnerSharing {
        let sharing = FakePartnerSharing(mother: .invited)
        try await sharing.accept(PartnerInvitation(payload: nil))
        return sharing
    }

    @Test func aBurstOfChangesIsOneUploadOfTheLatestSnapshot() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        let start = clock.now
        for sessions in 1...4 { publisher.update(snapshot(sessions: sessions)) }
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 1)
        let uploaded = try #require(try await sharing.fetchSharedSnapshot())
        #expect(uploaded.kicks.sessionsLast7Days == 4)
        #expect(uploaded.updatedAt == start.addingTimeInterval(5))
    }

    @Test func whatWasUploadedIsNotUploadedAgainEvenAfterARelaunch() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        publisher.update(snapshot(sessions: 1))
        await publisher.waitUntilIdle()
        var later = snapshot(sessions: 1)
        later.updatedAt = later.updatedAt.addingTimeInterval(60)
        publisher.update(later)
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 1)

        let relaunched = makePublisher(sharing)
        relaunched.update(later)
        await relaunched.waitUntilIdle()
        #expect(await sharing.publishCount == 1)
    }

    @Test func aPassingStateThatSettlesBackIsNotUploaded() async throws {
        let sharing = try await sharedFake()
        let first = makePublisher(sharing)
        first.update(snapshot(sessions: 3))
        await first.waitUntilIdle()
        // A relaunch first sees the store before appointments load, then the same content again.
        let relaunched = makePublisher(sharing)
        relaunched.update(snapshot(sessions: 0))
        relaunched.update(snapshot(sessions: 3))
        await relaunched.waitUntilIdle()
        #expect(await sharing.publishCount == 1)
    }

    @Test func nothingIsUploadedWhileNotSharingOrWithoutADueDate() async throws {
        let sharing = try await sharedFake()
        let inactive = makePublisher(sharing, active: false)
        inactive.update(snapshot(sessions: 1))
        await inactive.waitUntilIdle()
        let noDueDate = makePublisher(sharing)
        noDueDate.update(nil)
        noDueDate.requestPublish()
        await noDueDate.waitUntilIdle()
        #expect(await sharing.publishCount == 0)
    }

    @Test func requestPublishUploadsEvenWithoutAChange() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        publisher.update(snapshot(sessions: 1))
        await publisher.waitUntilIdle()
        publisher.requestPublish()
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 2)
    }

    /// Review: right after the share is created the record must exist before
    /// the sharing controller shows, so a partner who accepts at once finds it.
    @Test func publishNowUploadsAtOnceWithoutWaiting() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        let start = clock.now
        publisher.update(snapshot(sessions: 2))
        #expect(await publisher.publishNow())
        #expect(await sharing.publishCount == 1)
        let uploaded = try #require(try await sharing.fetchSharedSnapshot())
        #expect(uploaded.kicks.sessionsLast7Days == 2)
        #expect(uploaded.updatedAt == start)
        // The pending change from `update` is already covered by that upload.
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 1)
    }

    @Test func publishNowUploadsEvenWhatWasAlreadyUploaded() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        publisher.update(snapshot(sessions: 2))
        await publisher.waitUntilIdle()
        #expect(await publisher.publishNow())
        #expect(await sharing.publishCount == 2)
    }

    @Test func publishNowWithoutASnapshotOrWhileNotSharingUploadsNothing() async throws {
        let sharing = try await sharedFake()
        let empty = makePublisher(sharing)
        #expect(await empty.publishNow() == false)
        let inactive = makePublisher(sharing, active: false)
        inactive.update(snapshot(sessions: 1))
        #expect(await inactive.publishNow() == false)
        await inactive.waitUntilIdle()
        #expect(await sharing.publishCount == 0)
    }

    @Test func aFailedPublishNowIsRetried() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        await sharing.setFailure(.retryable)
        publisher.update(snapshot(sessions: 2))
        #expect(await publisher.publishNow() == false)
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 0)

        await sharing.setFailure(nil)
        publisher.noteBecameActive()
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 1)
    }

    @Test func stoppingForgetsWhatWasUploaded() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        publisher.update(snapshot(sessions: 1))
        await publisher.waitUntilIdle()
        #expect(defaults.data(forKey: SettingsKey.partnerPublishedSnapshot) != nil)
        publisher.forgetPublished()
        #expect(defaults.data(forKey: SettingsKey.partnerPublishedSnapshot) == nil)
        // The same content counts as new again.
        publisher.update(snapshot(sessions: 1))
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 2)
    }

    @Test func becomingActiveUploadsAtMostEverySixHours() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        publisher.update(snapshot(sessions: 1))
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 1)

        clock.now += 3_600
        publisher.noteBecameActive()
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 1)

        // A relaunch remembers the last upload.
        clock.now += 5 * 3_600 - 60
        let relaunched = makePublisher(sharing)
        relaunched.update(snapshot(sessions: 1))
        relaunched.noteBecameActive()
        await relaunched.waitUntilIdle()
        #expect(await sharing.publishCount == 1)

        clock.now += 60
        relaunched.noteBecameActive()
        await relaunched.waitUntilIdle()
        #expect(await sharing.publishCount == 2)
        #expect(try await sharing.fetchSharedSnapshot()?.updatedAt == clock.now)
    }

    @Test func aFailedUploadIsRetriedOnTheNextTrigger() async throws {
        let sharing = try await sharedFake()
        let publisher = makePublisher(sharing)
        await sharing.setFailure(.retryable)
        publisher.update(snapshot(sessions: 2))
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 0)
        #expect(defaults.data(forKey: SettingsKey.partnerPublishedSnapshot) == nil)

        await sharing.setFailure(nil)
        publisher.noteBecameActive()
        await publisher.waitUntilIdle()
        #expect(await sharing.publishCount == 1)
        #expect(try await sharing.fetchSharedSnapshot()?.kicks.sessionsLast7Days == 2)
        #expect(defaults.data(forKey: SettingsKey.partnerPublishedSnapshot) != nil)
    }
}
