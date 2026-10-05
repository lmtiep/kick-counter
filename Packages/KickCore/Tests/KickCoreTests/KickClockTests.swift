import Foundation
import Testing
@testable import KickCore

struct KickClockTests {
    @Test func minutesAndSecondsUnderAnHour() {
        #expect(KickClock.text(elapsed: 0) == "00:00")
        #expect(KickClock.text(elapsed: 303.9) == "05:03")
        #expect(KickClock.text(elapsed: 3599) == "59:59")
    }

    @Test func hoursFromOneHour() {
        #expect(KickClock.text(elapsed: 3600) == "1:00:00")
        #expect(KickClock.text(elapsed: 7_265) == "2:01:05")
        #expect(KickClock.text(elapsed: -5) == "00:00")
    }
}
