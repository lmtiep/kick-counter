import KickCore
import SwiftUI

/// Colours and symbols for cycle days. Never colour alone: each status also has
/// a symbol, and VoiceOver reads it out.
enum CyclePalette {
    /// Logged period: the app's pink accent.
    static let period = Color.accentColor
    /// Soft green for the fertile window (system green adapts to dark mode).
    static let fertile = Color(.systemGreen)
    /// Purple for ovulation and the day before.
    static let peak = Color(.systemPurple)
    static let low = Color(.systemGray5)

    /// Stroke colour for a day on the cycle ring.
    static func ringColor(for status: CycleDayStatus) -> Color {
        switch status {
        case .period(let isPredicted): isPredicted ? period.opacity(0.35) : period
        case .fertile: fertile.opacity(0.6)
        case .peak: peak
        case .low: low
        }
    }

    static func symbol(for status: CycleDayStatus) -> String? {
        switch status {
        case .period(let isPredicted): isPredicted ? "drop" : "drop.fill"
        case .fertile: "leaf.fill"
        case .peak: "sparkles"
        case .low: nil
        }
    }
}
