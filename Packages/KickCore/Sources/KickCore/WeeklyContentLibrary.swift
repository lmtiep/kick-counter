import Foundation

/// Whether unreviewed content may be shown: everything in Debug/TestFlight
/// (`CONTENT_PREVIEW`), only doctor-reviewed content in App Store builds.
public enum ContentVisibility: Sendable, Equatable {
    case reviewedOnly
    case all
}

public enum WeekDisplay: Equatable, Sendable {
    /// `pendingReview` asks the UI to show the "pending doctor review" label.
    case content(WeekContent, pendingReview: Bool)
    /// Release build, week not reviewed yet: show "being updated" instead.
    case underReview(week: Int)

    /// True when this week actually renders content (and so has a warnings
    /// section to show); false for `.underReview`, where the UI should hide
    /// anything that claims to open "the warnings for this week".
    public var showsWarnings: Bool {
        switch self {
        case .content: true
        case .underReview: false
        }
    }
}

public struct WeeklyContentLibrary: Sendable {
    public static let weekRange = 4...42

    public let document: PregnancyContent
    private let weeksByNumber: [Int: WeekContent]

    public init(document: PregnancyContent) {
        self.document = document
        weeksByNumber = Dictionary(document.weeks.map { ($0.week, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public init(data: Data) throws {
        self.init(document: try JSONDecoder().decode(PregnancyContent.self, from: data))
    }

    public var sources: [String] { document.sources }

    public var milestones: [Milestone] {
        document.milestones.sorted { ($0.fromWeek, $0.toWeek, $0.id) < ($1.fromWeek, $1.toWeek, $1.id) }
    }

    public static func clampedWeek(_ week: Int) -> Int {
        min(max(week, weekRange.lowerBound), weekRange.upperBound)
    }

    /// Content for `week`, clamped to 4…42 (so weeks 43–44 show week 42).
    public func content(forWeek week: Int) -> WeekContent? {
        weeksByNumber[Self.clampedWeek(week)]
    }

    public func display(forWeek week: Int, visibility: ContentVisibility) -> WeekDisplay? {
        guard let entry = content(forWeek: week) else { return nil }
        if entry.reviewed { return .content(entry, pendingReview: false) }
        switch visibility {
        case .all: return .content(entry, pendingReview: true)
        case .reviewedOnly: return .underReview(week: entry.week)
        }
    }

    /// Milestones not yet over at `week` (including ones under way), soonest first.
    public func upcomingMilestones(atWeek week: Int, visibility: ContentVisibility = .all) -> [Milestone] {
        milestones.filter { $0.toWeek >= week && (visibility == .all || $0.reviewed) }
    }

    /// Upcoming milestones at `week`, minus any whose id is already in `addedMilestoneIDs`
    /// (e.g. because an appointment was created from it). Used by both the home "next
    /// check-up" card and the Appointments screen's milestone suggestions so they agree.
    public func suggestedMilestones(atWeek week: Int, visibility: ContentVisibility = .all, excluding addedMilestoneIDs: Set<String>) -> [Milestone] {
        upcomingMilestones(atWeek: week, visibility: visibility).filter { !addedMilestoneIDs.contains($0.id) }
    }
}
