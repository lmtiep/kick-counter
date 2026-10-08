import Testing
@testable import KickCore

struct AppFeaturesTests {
    /// Guard: version 1.0 keeps health data off iCloud (App Review 5.1.3(ii)).
    /// Turning the switch on must be a deliberate change that updates this test.
    @Test func cloudSyncIsOffForVersion1() {
        #expect(AppFeatures.cloudSync == false)
    }
}
