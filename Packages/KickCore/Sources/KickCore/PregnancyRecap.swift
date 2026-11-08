import Foundation

/// The numbers and pages behind the birth celebration (birth celebration spec §3).
/// Built from the frozen `PregnancyMemoryContent`, so it works the same at the
/// moment of the ending and when a kept memory is replayed.
public struct PregnancyRecap: Equatable, Sendable, Identifiable {
    public enum Page: Equatable, Sendable {
        case celebration, journey, kicks, contractions, appointments, weight, thanks, summary
    }

    public var id: Date { birthDate }
    public var birthDate: Date
    /// Completed weeks at the birth; nil without a pregnancy date.
    public var weeks: Int?
    /// Whole days from the first day to the birth; nil without a start.
    public var days: Int?
    /// `weeks` clamped to 4...42 (the range the per-week art covers).
    public var artworkWeek: Int?
    /// The handoff's milestones below `artworkWeek`, then `artworkWeek` (`milestones(to:)`).
    public var journeyWeeks: [Int]
    public var totalKicks: Int
    public var kickSessions: Int
    public var contractions: Int
    public var appointments: Int
    /// Last minus first weight; nil with fewer than two entries.
    public var weightChangeKg: Double?
    /// The journey was saved as a memory (the last page says where).
    public var keptAsMemory: Bool
    public var baby: BirthDetails?
    public var pages: [Page]

    public static let firstArtworkWeek = 4
    public static let lastArtworkWeek = 42
    /// The weeks the handoff has art for (`week-08` … `week-40`).
    public static let milestoneWeeks = [8, 16, 24, 32]
    public static let newbornArtWeek = 40

    public static func make(content: PregnancyMemoryContent, keptAsMemory: Bool = false, calendar: Calendar) -> PregnancyRecap {
        let artworkWeek = content.furthestWeek.map { min(max($0, firstArtworkWeek), lastArtworkWeek) }
        let days = content.start.flatMap {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: content.end)).day
        }
        let weights = content.weights
        let weightChange = weights.count >= 2 ? (weights.last?.kg ?? 0) - (weights.first?.kg ?? 0) : nil
        var recap = PregnancyRecap(
            birthDate: content.end,
            weeks: content.furthestWeek,
            days: days,
            artworkWeek: artworkWeek,
            journeyWeeks: artworkWeek.map(milestones(to:)) ?? [],
            totalKicks: content.kickDays.reduce(0) { $0 + $1.totalKicks },
            kickSessions: content.kickDays.reduce(0) { $0 + $1.sessionCount },
            contractions: content.contractionEpisodes.reduce(0) { $0 + $1.count },
            appointments: content.appointments.count,
            weightChangeKg: weightChange,
            keptAsMemory: keptAsMemory,
            baby: content.baby,
            pages: []
        )
        recap.pages = recap.makePages()
        return recap
    }

    /// The recap shown right after an ending: only a birth has one.
    public static func forEnding(content: PregnancyMemoryContent, keptAsMemory: Bool, calendar: Calendar) -> PregnancyRecap? {
        guard content.branch == .birth else { return nil }
        return make(content: content, keptAsMemory: keptAsMemory, calendar: calendar)
    }

    private func makePages() -> [Page] {
        var pages: [Page] = [.celebration]
        if weeks != nil { pages.append(.journey) }
        if totalKicks > 0 { pages.append(.kicks) }
        if contractions > 0 { pages.append(.contractions) }
        if appointments > 0 { pages.append(.appointments) }
        if weightChangeKg != nil { pages.append(.weight) }
        pages.append(contentsOf: [.thanks, .summary])
        return pages
    }

    /// Weeks 8, 16, 24 and 32 that come before `last`, then `last`.
    public static func milestones(to last: Int) -> [Int] {
        milestoneWeeks.filter { $0 < last } + [last]
    }

    /// The handoff image for a strip week: the newborn for the final one, else the
    /// nearest milestone (a tie takes the earlier).
    public static func milestoneArt(_ week: Int, isFinal: Bool) -> Int {
        guard !isFinal else { return newbornArtWeek }
        return (milestoneWeeks + [newbornArtWeek]).min { abs($0 - week) < abs($1 - week) } ?? newbornArtWeek
    }
}
