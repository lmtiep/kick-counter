import Foundation

/// The timer on the kick dial (spec §4.6): "mm:ss", or "h:mm:ss" from one hour.
public enum KickClock {
    public static func text(elapsed: TimeInterval) -> String {
        let total = max(0, Int(elapsed))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
