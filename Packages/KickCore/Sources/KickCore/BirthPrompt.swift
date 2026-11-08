import Foundation

/// "Has your baby arrived?" (birth celebration spec §1): the Today card shows
/// only when a birth is near, never during the rest of the pregnancy.
public enum BirthPromptRules {
    /// The Today card shows from this completed week.
    public static let todayCardFromWeek = 37

    public static func showsTodayCard(week: Int) -> Bool { week >= todayCardFromWeek }
}
