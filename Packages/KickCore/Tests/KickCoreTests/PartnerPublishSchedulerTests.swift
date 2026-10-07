import Foundation
import Testing
@testable import KickCore

/// Phase 8 spec §3.3: a burst of edits becomes one upload.
struct PartnerPublishSchedulerTests {
    let start = date("2026-10-02T12:00:00Z")

    @Test func nothingPendingAtFirst() {
        let scheduler = PartnerPublishScheduler()
        #expect(!scheduler.hasPendingChange)
        #expect(scheduler.delay(at: start) == nil)
        #expect(!scheduler.isDue(at: start))
    }

    @Test func dueFiveSecondsAfterTheLastChange() {
        var scheduler = PartnerPublishScheduler()
        scheduler.noteChange(at: start)
        #expect(scheduler.delay(at: start) == 5)
        #expect(!scheduler.isDue(at: start.addingTimeInterval(4.9)))
        #expect(scheduler.isDue(at: start.addingTimeInterval(5)))
    }

    @Test func aBurstOfChangesWaitsForTheLastOne() {
        var scheduler = PartnerPublishScheduler()
        scheduler.noteChange(at: start)
        scheduler.noteChange(at: start.addingTimeInterval(3))
        scheduler.noteChange(at: start.addingTimeInterval(4))
        #expect(!scheduler.isDue(at: start.addingTimeInterval(8)))
        #expect(scheduler.delay(at: start.addingTimeInterval(8)) == 1)
        #expect(scheduler.isDue(at: start.addingTimeInterval(9)))
    }

    @Test func startingAnUploadTakesThePendingChange() {
        var scheduler = PartnerPublishScheduler()
        scheduler.noteChange(at: start)
        scheduler.startPublishing()
        #expect(!scheduler.hasPendingChange)
        #expect(scheduler.delay(at: start.addingTimeInterval(60)) == nil)
        #expect(scheduler.lastPublished == nil)
        scheduler.didPublish(at: start.addingTimeInterval(5))
        #expect(scheduler.lastPublished == start.addingTimeInterval(5))
    }

    @Test func aChangeDuringAnUploadStaysPending() {
        var scheduler = PartnerPublishScheduler(lastPublished: start)
        scheduler.noteChange(at: start.addingTimeInterval(10))
        scheduler.startPublishing()
        scheduler.noteChange(at: start.addingTimeInterval(16))
        #expect(scheduler.hasPendingChange)
        #expect(scheduler.lastPublished == start)
        #expect(scheduler.isDue(at: start.addingTimeInterval(21)))
    }

    @Test func becomingActiveCountsAtMostOnceEverySixHours() {
        var scheduler = PartnerPublishScheduler()
        scheduler.noteBecameActive(at: start)
        #expect(scheduler.hasPendingChange)
        scheduler.startPublishing()
        scheduler.didPublish(at: start)
        scheduler.noteBecameActive(at: start.addingTimeInterval(6 * 3_600 - 1))
        #expect(!scheduler.hasPendingChange)
        scheduler.noteBecameActive(at: start.addingTimeInterval(6 * 3_600))
        #expect(scheduler.hasPendingChange)
    }
}
