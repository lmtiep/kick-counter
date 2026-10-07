import Foundation
import Testing
@testable import KickCore

/// Phase 8 spec §6: the sharing flow, played with `FakePartnerSharing`.
struct PartnerSharingTests {
    let now = date("2026-10-02T12:00:00Z")

    @Test func statusGoesFromNotSharedToInvitedToJoined() async throws {
        let sharing = FakePartnerSharing()
        #expect(try await sharing.shareStatus() == .notShared)
        let handle = try await sharing.prepareShare()
        #expect(handle.payload == nil)
        #expect(try await sharing.shareStatus() == .invited)
        await sharing.partnerJoins()
        #expect(try await sharing.shareStatus() == .joined(participantCount: 1))
    }

    @Test func whatTheMotherPublishesIsWhatThePartnerFetches() async throws {
        let sharing = FakePartnerSharing()
        _ = try await sharing.prepareShare()
        try await sharing.accept(PartnerInvitation(payload: nil))
        #expect(try await sharing.shareStatus() == .joined(participantCount: 1))
        let snapshot = PartnerSnapshotTests.sample
        try await sharing.publish(snapshot)
        #expect(try await sharing.fetchSharedSnapshot() == snapshot)
        #expect(await sharing.publishCount == 1)
    }

    @Test func nothingToFetchBeforeAccepting() async throws {
        let sharing = FakePartnerSharing()
        _ = try await sharing.prepareShare()
        try await sharing.publish(PartnerSnapshotTests.sample)
        #expect(try await sharing.fetchSharedSnapshot() == nil)
    }

    @Test func stoppingSharingLeavesNothingToFetch() async throws {
        let sharing = FakePartnerSharing()
        _ = try await sharing.prepareShare()
        try await sharing.accept(PartnerInvitation(payload: nil))
        try await sharing.publish(PartnerSnapshotTests.sample)
        try await sharing.stopSharing()
        #expect(try await sharing.shareStatus() == .notShared)
        #expect(try await sharing.fetchSharedSnapshot() == nil)
    }

    @Test func publishingWithoutAShareThrowsNotShared() async {
        let sharing = FakePartnerSharing()
        await #expect(throws: PartnerSharingError.notShared) {
            try await sharing.publish(PartnerSnapshotTests.sample)
        }
    }

    @Test func aCorruptPayloadIsAnUnreadableSnapshot() async throws {
        let sharing = FakePartnerSharing()
        _ = try await sharing.prepareShare()
        try await sharing.accept(PartnerInvitation(payload: nil))
        await sharing.storeRawPayload(Data("{\"version\":".utf8))
        await #expect(throws: PartnerSharingError.unreadableSnapshot) {
            try await sharing.fetchSharedSnapshot()
        }
    }

    @Test func anInjectedFailureIsThrownUntilCleared() async throws {
        let sharing = FakePartnerSharing()
        await sharing.setFailure(.retryable)
        await #expect(throws: PartnerSharingError.retryable) { try await sharing.shareStatus() }
        await #expect(throws: PartnerSharingError.retryable) { try await sharing.registerForChanges() }
        await sharing.setFailure(nil)
        try await sharing.registerForChanges()
        #expect(await sharing.isRegisteredForChanges)
    }

    @Test func motherLaunchStates() async throws {
        #expect(try await FakePartnerSharing(mother: .notShared).shareStatus() == .notShared)
        #expect(try await FakePartnerSharing(mother: .invited).shareStatus() == .invited)
        #expect(try await FakePartnerSharing(mother: .joined).shareStatus() == .joined(participantCount: 1))
        await #expect(throws: PartnerSharingError.iCloudUnavailable) {
            try await FakePartnerSharing(mother: .icloudUnavailable).shareStatus()
        }
    }

    @Test func partnerLaunchStates() async throws {
        let sample = PartnerSnapshot.uiTestSample(now: now, language: .vi)
        #expect(try await FakePartnerSharing(partner: .snapshot, snapshot: sample).fetchSharedSnapshot() == sample)
        #expect(try await FakePartnerSharing(partner: .stopped, snapshot: sample).fetchSharedSnapshot() == nil)
        await #expect(throws: PartnerSharingError.retryable) {
            try await FakePartnerSharing(partner: .error, snapshot: sample).fetchSharedSnapshot()
        }
        await #expect(throws: PartnerSharingError.iCloudUnavailable) {
            try await FakePartnerSharing(partner: .icloudUnavailable, snapshot: sample).fetchSharedSnapshot()
        }
    }

    @Test func theUITestSampleIsWeek24WithTwoAppointmentsAndARecentSession() throws {
        let sample = PartnerSnapshot.uiTestSample(now: now, language: .en)
        let timeline = try #require(PregnancyTimeline(dueDate: sample.dueDate, now: now, calendar: utcCalendar))
        #expect(timeline.week == GestationalWeek(weeks: 24, days: 3))
        #expect(sample.displayName == "Mom")
        #expect(sample.appointments.map(\.title) == ["Anomaly scan", "Glucose test"])
        #expect(sample.kicks.lastSession?.kicks == 10)
        #expect(sample.updatedAt == now.addingTimeInterval(-600))
    }
}
