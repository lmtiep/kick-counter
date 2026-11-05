import Foundation
import Testing
@testable import KickCore

struct ReviewPromptPolicyTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    /// Used on days 0, 1 and 2; `now` is day 2.
    private func eligible(_ changes: (inout ReviewPromptState) -> Void = { _ in }) -> ReviewPromptState {
        var state = ReviewPromptState(firstUseAt: day(0), useDays: [20260101, 20260102, 20260103])
        changes(&state)
        return state
    }

    private func ask(
        _ moment: ReviewMoment = .kickSessionCompleted,
        context: ReviewPromptContext = ReviewPromptContext(),
        state: ReviewPromptState,
        version: String = "1.1",
        now: Date? = nil
    ) -> Bool {
        ReviewPromptPolicy.shouldAsk(
            moment: moment, context: context, state: state, appVersion: version, now: now ?? day(2), calendar: calendar
        )
    }

    // MARK: Days of use

    @Test func needsThreeDistinctDaysOfUse() {
        #expect(ask(state: eligible()))
        #expect(!ask(state: eligible { $0.useDays = [20260101, 20260102] }))
        #expect(!ask(state: ReviewPromptState()))
    }

    @Test func recordingUseCountsDistinctDaysOnly() {
        var state = ReviewPromptState()
        state = ReviewPromptPolicy.recordingUse(state, now: day(0, hour: 8), calendar: calendar)
        state = ReviewPromptPolicy.recordingUse(state, now: day(0, hour: 20), calendar: calendar)
        #expect(state.useDays == [20260101])
        #expect(state.firstUseAt == day(0, hour: 8))
        state = ReviewPromptPolicy.recordingUse(state, now: day(1), calendar: calendar)
        state = ReviewPromptPolicy.recordingUse(state, now: day(2), calendar: calendar)
        #expect(state.useDays.count == 3)
        #expect(state.firstUseAt == day(0, hour: 8))
        #expect(ask(state: state))
    }

    @Test func recordingUseKeepsAtMostTenDays() {
        var state = ReviewPromptState()
        for offset in 0..<30 { state = ReviewPromptPolicy.recordingUse(state, now: day(offset), calendar: calendar) }
        #expect(state.useDays.count == ReviewPromptPolicy.keptUseDays)
    }

    // MARK: Moments

    @Test func aCompletedKickSessionQualifies() {
        #expect(ask(.kickSessionCompleted, state: eligible()))
    }

    @Test func onlyTheThirdPeriodStartOrLaterQualifies() {
        #expect(!ask(.periodStarted(totalPeriods: 1), state: eligible()))
        #expect(!ask(.periodStarted(totalPeriods: 2), state: eligible()))
        #expect(ask(.periodStarted(totalPeriods: 3), state: eligible()))
        #expect(ask(.periodStarted(totalPeriods: 9), state: eligible()))
    }

    @Test func aWeightEntryNeedsSevenDaysOfUse() {
        let state = eligible()
        #expect(!ask(.weightSaved, state: state, now: day(5)))
        #expect(!ask(.weightSaved, state: state, now: day(6)))
        #expect(ask(.weightSaved, state: state, now: day(7)))
        #expect(ask(.weightSaved, state: state, now: day(30)))
    }

    @Test func weightWithoutAFirstUseDateNeverQualifies() {
        #expect(!ask(.weightSaved, state: eligible { $0.firstUseAt = nil }, now: day(20)))
    }

    // MARK: Blockers

    @Test func neverDuringOnboarding() {
        #expect(!ask(context: ReviewPromptContext(isOnboarding: true), state: eligible()))
    }

    @Test func neverAfterContractionUse() {
        #expect(!ask(context: ReviewPromptContext(recentContractionUse: true), state: eligible()))
    }

    @Test func neverWhileAnAlertCardShows() {
        #expect(!ask(context: ReviewPromptContext(alertShowing: true), state: eligible()))
    }

    @Test func contractionUseIsRecentForTwentyFourHours() {
        let now = day(2)
        func record(endedAgo: TimeInterval?) -> ContractionRecord {
            ContractionRecord(startedAt: now.addingTimeInterval(-(endedAgo ?? 100) - 60), endedAt: endedAgo.map { now.addingTimeInterval(-$0) })
        }
        #expect(!ReviewPromptPolicy.hadRecentContractionUse([], now: now))
        #expect(ReviewPromptPolicy.hadRecentContractionUse([record(endedAgo: nil)], now: now))
        #expect(ReviewPromptPolicy.hadRecentContractionUse([record(endedAgo: 24 * 3600 - 1)], now: now))
        #expect(!ReviewPromptPolicy.hadRecentContractionUse([record(endedAgo: 24 * 3600)], now: now))
        #expect(!ReviewPromptPolicy.hadRecentContractionUse([record(endedAgo: 3 * 24 * 3600)], now: now))
    }

    // MARK: Frequency

    @Test func atMostOnceEvery120Days() {
        let asked = eligible { $0.askedAt = [day(0)]; $0.askedVersions = ["1.0"] }
        #expect(!ask(state: asked, now: day(119)))
        #expect(ask(state: asked, now: day(120)))
        #expect(ask(state: asked, now: day(121)))
    }

    @Test func atMostThreeInAnyYearAndTheCapReleasesWhenTheOldestRequestIsOlderThan365Days() {
        let three = eligible { $0.askedAt = [day(0), day(100), day(240)]; $0.askedVersions = ["1.0", "1.1", "1.2"] }
        #expect(!ask(state: three, version: "1.3", now: day(364)))
        #expect(ask(state: three, version: "1.3", now: day(365)))
    }

    @Test func neverTwiceForTheSameVersion() {
        let asked = eligible { $0.askedAt = [day(0)]; $0.askedVersions = ["1.1"] }
        #expect(!ask(state: asked, version: "1.1", now: day(400)))
        #expect(ask(state: asked, version: "1.2", now: day(400)))
    }

    // MARK: Recording

    @Test func recordingAnAskStoresTheDateAndVersionOnce() {
        var state = eligible()
        state = ReviewPromptPolicy.recordingAsk(state, appVersion: "1.1", now: day(2))
        state = ReviewPromptPolicy.recordingAsk(state, appVersion: "1.1", now: day(200))
        #expect(state.askedAt == [day(2), day(200)])
        #expect(state.askedVersions == ["1.1"])
    }

    @Test func shouldAskDoesNotChangeAnything() {
        let state = eligible()
        _ = ask(state: state)
        #expect(state.askedAt.isEmpty)
    }

    // MARK: Store

    @Test func theStoreRoundTripsTheState() {
        let defaults = makeTestDefaults()
        #expect(ReviewPromptStore.load(from: defaults) == ReviewPromptState())
        let state = ReviewPromptState(
            firstUseAt: day(0), useDays: [20260101, 20260103], askedAt: [day(5), day(200)], askedVersions: ["1.0", "1.1"]
        )
        ReviewPromptStore.save(state, to: defaults)
        #expect(ReviewPromptStore.load(from: defaults) == state)
    }

    @Test func deleteAllForgetsTheState() {
        let defaults = makeTestDefaults()
        ReviewPromptStore.save(ReviewPromptState(firstUseAt: day(0), useDays: [20260101], askedAt: [day(1)], askedVersions: ["1.0"]), to: defaults)
        AppDataReset.clearDefaults(defaults)
        #expect(ReviewPromptStore.load(from: defaults) == ReviewPromptState())
    }
}
