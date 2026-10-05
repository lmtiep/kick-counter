import Foundation

/// The progress bar on the pregnancy Today screen (spec §4.4): days since the
/// last period out of 280, with the trimester dividers drawn at 32.5 % and 67.5 %.
public struct PregnancyProgress: Equatable, Sendable {
    public static let trimesterMarks: [Double] = [0.325, 0.675]

    /// 0…1, capped at 1 from the due date on.
    public let fraction: Double
    public let week: GestationalWeek
    public let trimester: Trimester
    public let daysRemaining: Int
    public let daysPastDue: Int

    public init(timeline: PregnancyTimeline) {
        fraction = timeline.progress
        week = timeline.week
        trimester = timeline.trimester
        daysRemaining = timeline.daysRemaining
        daysPastDue = timeline.daysPastDue
    }
}
