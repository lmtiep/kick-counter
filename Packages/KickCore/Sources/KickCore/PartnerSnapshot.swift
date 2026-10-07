import Foundation

/// What the partner sees (phase 8 spec §3.1). Built only by
/// `PartnerSnapshotBuilder`; never holds notes, symptoms, weight or cycle data.
public struct PartnerSnapshot: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    /// A newer app may write a higher version; this build still reads the fields it knows.
    public var version: Int
    public var updatedAt: Date
    /// What the partner sees, "Mẹ" / "Mom" in the mother's language.
    public var displayName: String
    /// Start of the due day in the mother's calendar.
    public var dueDate: Date
    /// Upcoming only, soonest first, at most `PartnerSnapshotBuilder.maxAppointments`.
    public var appointments: [PartnerAppointment]
    public var kicks: PartnerKickSummary

    public init(
        version: Int = PartnerSnapshot.currentVersion,
        updatedAt: Date,
        displayName: String,
        dueDate: Date,
        appointments: [PartnerAppointment],
        kicks: PartnerKickSummary
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.displayName = displayName
        self.dueDate = dueDate
        self.appointments = appointments
        self.kicks = kicks
    }

    /// JSON with ISO-8601 dates (whole seconds).
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Nil when `data` is not a snapshot this build can read ("unavailable").
    /// Unknown fields from a newer version are ignored.
    public static func decode(_ data: Data) -> PartnerSnapshot? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PartnerSnapshot.self, from: data)
    }

    /// Same content apart from `updatedAt`: nothing new to publish.
    public func hasSameContent(as other: PartnerSnapshot) -> Bool {
        var copy = other
        copy.updatedAt = updatedAt
        return copy == self
    }
}

public struct PartnerAppointment: Codable, Equatable, Sendable {
    public var title: String
    public var date: Date
    /// Appointments have no location yet, so the builder always writes nil.
    /// Kept so a later version can fill it without a new snapshot version.
    public var location: String?

    public init(title: String, date: Date, location: String? = nil) {
        self.title = title
        self.date = date
        self.location = location
    }
}

public struct PartnerKickSummary: Codable, Equatable, Sendable {
    /// The most recent completed session, at any date.
    public var lastSession: PartnerKickSession?
    /// Completed sessions started in the last 7 days.
    public var sessionsLast7Days: Int
    /// Mean duration of those sessions; nil when there are none.
    public var averageMinutesLast7Days: Double?

    public init(lastSession: PartnerKickSession?, sessionsLast7Days: Int, averageMinutesLast7Days: Double?) {
        self.lastSession = lastSession
        self.sessionsLast7Days = sessionsLast7Days
        self.averageMinutesLast7Days = averageMinutesLast7Days
    }

    public static let empty = PartnerKickSummary(lastSession: nil, sessionsLast7Days: 0, averageMinutesLast7Days: nil)
}

public struct PartnerKickSession: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var kicks: Int
    public var durationMinutes: Double

    public init(startedAt: Date, kicks: Int, durationMinutes: Double) {
        self.startedAt = startedAt
        self.kicks = kicks
        self.durationMinutes = durationMinutes
    }
}
