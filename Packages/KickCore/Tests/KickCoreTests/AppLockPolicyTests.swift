import Foundation
import Testing
@testable import KickCore

struct AppLockPolicyTests {
    let t0 = date("2026-11-09T09:00:00Z")

    @Test func launchLocksWhenOnAndTheDeviceCanAuthenticate() {
        #expect(AppLockPolicy(enabled: true, canAuthenticate: true).isLocked)
        #expect(!AppLockPolicy(enabled: false, canAuthenticate: true).isLocked)
        #expect(!AppLockPolicy(enabled: true, canAuthenticate: false).isLocked)
    }

    @Test func returningWithinAMinuteStaysOpen() {
        var policy = AppLockPolicy(enabled: true, canAuthenticate: true)
        policy.unlocked()
        policy.handle(.enteredBackground(t0), enabled: true, canAuthenticate: true)
        policy.handle(.becameActive(t0.addingTimeInterval(59)), enabled: true, canAuthenticate: true)
        #expect(!policy.isLocked)
    }

    @Test func returningAfterAMinuteLocks() {
        var policy = AppLockPolicy(enabled: true, canAuthenticate: true)
        policy.unlocked()
        policy.handle(.enteredBackground(t0), enabled: true, canAuthenticate: true)
        policy.handle(.becameActive(t0.addingTimeInterval(60)), enabled: true, canAuthenticate: true)
        #expect(policy.isLocked)
    }

    /// The Face ID prompt makes the scene inactive, then active again: no background, no lock.
    @Test func becomingActiveWithoutBackgroundNeverLocks() {
        var policy = AppLockPolicy(enabled: true, canAuthenticate: true)
        policy.unlocked()
        policy.handle(.becameActive(t0.addingTimeInterval(3600)), enabled: true, canAuthenticate: true)
        #expect(!policy.isLocked)
    }

    @Test func aBackgroundIsUsedOnce() {
        var policy = AppLockPolicy(enabled: true, canAuthenticate: true)
        policy.unlocked()
        policy.handle(.enteredBackground(t0), enabled: true, canAuthenticate: true)
        policy.handle(.becameActive(t0.addingTimeInterval(120)), enabled: true, canAuthenticate: true)
        policy.unlocked()
        policy.handle(.becameActive(t0.addingTimeInterval(500)), enabled: true, canAuthenticate: true)
        #expect(!policy.isLocked)
    }

    @Test func turnedOffOrUnusableNeverLocks() {
        var policy = AppLockPolicy(enabled: true, canAuthenticate: true)
        policy.unlocked()
        policy.handle(.enteredBackground(t0), enabled: false, canAuthenticate: true)
        policy.handle(.becameActive(t0.addingTimeInterval(120)), enabled: false, canAuthenticate: true)
        #expect(!policy.isLocked)
        policy.handle(.enteredBackground(t0), enabled: true, canAuthenticate: false)
        policy.handle(.becameActive(t0.addingTimeInterval(120)), enabled: true, canAuthenticate: false)
        #expect(!policy.isLocked)
    }

    @Test func aLockThatCanNoLongerAuthenticateOpens() {
        var policy = AppLockPolicy(enabled: true, canAuthenticate: true)
        policy.handle(.becameActive(t0), enabled: true, canAuthenticate: false)
        #expect(!policy.isLocked)
    }
}
