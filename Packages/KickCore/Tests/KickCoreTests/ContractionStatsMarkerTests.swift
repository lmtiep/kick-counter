import Foundation
import Testing
@testable import KickCore

/// Edit spec 2026-11-06: where a "Vỡ ối" marker shows (an episode, the current
/// list or the history).
struct ContractionStatsMarkerTests {
    let now = date("2026-11-06T12:00:00Z")

    private func done(_ secondsAgo: TimeInterval, lasting duration: TimeInterval = 60) -> ContractionRecord {
        let start = now.addingTimeInterval(-secondsAgo)
        return ContractionRecord(startedAt: start, endedAt: start.addingTimeInterval(duration))
    }

    private func marker(_ secondsAgo: TimeInterval) -> LabourMarkerRecord {
        LabourMarkerRecord(at: now.addingTimeInterval(-secondsAgo))
    }

    private func stats(
        _ records: [ContractionRecord], markers: [LabourMarkerRecord], endedAt: Date? = nil
    ) -> ContractionStats {
        ContractionStats(contractions: records, now: now, week: nil, episodeEndedAt: endedAt, markers: markers)
    }

    @Test func markerInsideAnEpisodeJoinsIt() throws {
        let water = marker(500)
        let result = stats([done(900), done(300)], markers: [water])
        let episode = try #require(result.currentEpisode)
        #expect(episode.markers == [water])
        #expect(result.currentMarkers == [water])
    }

    @Test func markerBeforeTheFirstContractionJoinsWithinTheGap() throws {
        let water = marker(900 + 3600)
        let result = stats([done(900), done(300)], markers: [water])
        #expect(try #require(result.currentEpisode).markers == [water])
    }

    @Test func markerAfterTheLastContractionJoinsWithinTheGap() throws {
        let water = marker(60)
        let result = stats([done(3000), done(2400)], markers: [water])
        #expect(try #require(result.currentEpisode).markers == [water])
    }

    @Test func looseRecentMarkerIsCurrent() {
        let water = marker(600)
        let result = stats([], markers: [water])
        #expect(result.currentEpisode == nil)
        #expect(result.currentMarkers == [water])
    }

    @Test func looseOldMarkerGoesToHistoryByDay() {
        let water = LabourMarkerRecord(at: date("2026-11-04T08:00:00Z"))
        let result = stats([], markers: [water])
        #expect(result.currentMarkers.isEmpty)
        let days = result.pastEpisodesByDay(calendar: utcCalendar)
        #expect(days.map(\.day) == [CalendarDay(year: 2026, month: 11, day: 4)])
        #expect(days.first?.markers == [water])
        #expect(days.first?.episodes.isEmpty == true)
    }

    @Test func markerGoesToTheNearestEpisode() throws {
        // Episode A started 10 h ago (single), episode B 3 h ago; marker 5 h ago is 5 h from A and 2 h from B.
        let a = done(10 * 3600)
        let b = done(3 * 3600)
        let water = marker(5 * 3600)
        let result = stats([a, b], markers: [water])
        #expect(result.episodes.count == 2)
        #expect(result.episodes[0].markers.isEmpty)
        #expect(result.episodes[1].markers == [water])
    }

    @Test func markerMadeAfterEndingTheEpisodeDoesNotJoinTheEndedOne() {
        let endedAt = now.addingTimeInterval(-1200)
        let water = marker(600)
        let result = stats([done(1800), done(1500)], markers: [water], endedAt: endedAt)
        #expect(result.episodes.allSatisfy { $0.markers.isEmpty })
        #expect(result.currentEpisode == nil)
        #expect(result.currentMarkers == [water])
    }

    @Test func markerBeforeTheEpisodeEndMarkStaysWithItsEpisodeInHistory() {
        let endedAt = now.addingTimeInterval(-600)
        let water = marker(1500)
        let result = stats([done(1800), done(1500)], markers: [water], endedAt: endedAt)
        #expect(result.currentMarkers.isEmpty)
        #expect(result.pastEpisodes.first?.markers == [water])
    }

    @Test func unknownMarkerKindsAreIgnored() {
        let odd = LabourMarkerRecord(kind: "somethingNew", at: now.addingTimeInterval(-60))
        let result = stats([done(300)], markers: [odd])
        #expect(result.currentMarkers.isEmpty)
        #expect(result.currentEpisode?.markers.isEmpty == true)
    }

    @Test func noMarkersLeavesTheStatsAsTheyWere() {
        let records = [done(900), done(600)]
        #expect(stats(records, markers: []) == ContractionStats(contractions: records, now: now, week: nil))
    }
}
