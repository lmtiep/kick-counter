import Foundation

/// Sample kick history for UI tests and screenshots (`-uiTesting -seedSessions`):
/// one evening session a day for the 27 days before today (none today yet),
/// slowly getting quicker, plus one cancelled session two days ago.
public enum SessionSeed {
    /// Minutes to 10 movements, by `(dayOffset + 7) mod 7` (the design's last week).
    static let minutes = [24, 19, 31, 16, 27, 21, 18]
    /// Start times after 20:00, same indexing.
    static let startMinutes = [5, 40, 10, 30, 15, 55, 20]
    public static let days = 27

    public static func sessions(today now: Date, calendar: Calendar = .current) -> [SessionState] {
        let today = calendar.startOfDay(for: now)
        var sessions: [SessionState] = []
        for offset in -days ... -1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let index = ((offset % 7) + 14) % 7
            let extra = offset <= -21 ? 6 : offset <= -14 ? 3 : 0
            let length = TimeInterval((minutes[index] + extra) * 60)
            guard let start = calendar.date(bySettingHour: 20, minute: startMinutes[index], second: 0, of: day) else { continue }
            let kicks = (1...SessionRules.targetCount).map {
                start.addingTimeInterval(length * Double($0) / Double(SessionRules.targetCount))
            }
            sessions.append(SessionState(
                startedAt: start, kicks: kicks, status: .completed, endedAt: start.addingTimeInterval(length)
            ))
        }
        if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today),
           let start = calendar.date(bySettingHour: 14, minute: 10, second: 0, of: twoDaysAgo) {
            sessions.append(SessionState(
                startedAt: start,
                kicks: (1...4).map { start.addingTimeInterval(Double($0) * 180) },
                status: .cancelled,
                endedAt: start.addingTimeInterval(15 * 60)
            ))
        }
        return sessions.sorted { $0.startedAt < $1.startedAt }
    }
}
