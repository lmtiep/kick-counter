import Foundation
import Testing
@testable import KickCore

/// Phase 8 spec §3.1: the snapshot's JSON.
struct PartnerSnapshotTests {
    static let sample = PartnerSnapshot(
        updatedAt: date("2026-10-02T12:00:00Z"),
        displayName: "Mẹ",
        dueDate: date("2027-01-19T00:00:00Z"),
        appointments: [PartnerAppointment(title: "Siêu âm hình thái", date: date("2026-10-07T09:00:00Z"))],
        kicks: PartnerKickSummary(
            lastSession: PartnerKickSession(startedAt: date("2026-10-02T09:00:00Z"), kicks: 10, durationMinutes: 18),
            sessionsLast7Days: 4,
            averageMinutesLast7Days: 21.5
        )
    )

    @Test func roundTripsThroughJSON() throws {
        let data = try Self.sample.encoded()
        #expect(PartnerSnapshot.decode(data) == Self.sample)
    }

    @Test func writesISO8601Dates() throws {
        let json = String(decoding: try Self.sample.encoded(), as: UTF8.self)
        #expect(json.contains("\"updatedAt\":\"2026-10-02T12:00:00Z\""))
        #expect(json.contains("\"version\":1"))
    }

    @Test func aNewerVersionStillDecodesTheFieldsItKnows() throws {
        let json = """
        {"version": 2, "updatedAt": "2026-10-02T12:00:00Z", "displayName": "Mom",
         "dueDate": "2027-01-19T00:00:00Z", "appointments": [], "babyName": "Su",
         "kicks": {"sessionsLast7Days": 0, "streak": 3}}
        """
        let snapshot = try #require(PartnerSnapshot.decode(Data(json.utf8)))
        #expect(snapshot.version == 2)
        #expect(snapshot.displayName == "Mom")
        #expect(snapshot.kicks == .empty)
    }

    @Test func anUnreadablePayloadIsNil() {
        #expect(PartnerSnapshot.decode(Data("not json".utf8)) == nil)
        #expect(PartnerSnapshot.decode(Data(#"{"version": 1}"#.utf8)) == nil)
    }

    @Test func sameContentIgnoresUpdatedAt() {
        var later = Self.sample
        later.updatedAt = date("2026-10-02T13:00:00Z")
        #expect(later.hasSameContent(as: Self.sample))
        later.kicks.sessionsLast7Days = 5
        #expect(!later.hasSameContent(as: Self.sample))
    }
}
