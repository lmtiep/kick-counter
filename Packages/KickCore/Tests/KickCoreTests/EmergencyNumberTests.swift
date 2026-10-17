import Testing
@testable import KickCore

struct EmergencyNumberTests {
    @Test func offers115OnlyInVietnam() {
        #expect(EmergencyNumber.offersVietnamCall(regionIdentifier: "VN"))
        #expect(EmergencyNumber.offersVietnamCall(regionIdentifier: "US") == false)
        #expect(EmergencyNumber.offersVietnamCall(regionIdentifier: "GB") == false)
        #expect(EmergencyNumber.offersVietnamCall(regionIdentifier: nil) == false)
        #expect(EmergencyNumber.vietnam == "115")
    }
}
