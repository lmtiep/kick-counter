import Foundation
import Testing
@testable import KickCore

struct MaternalProfileTests {
    @Test func missingValuesLoadAsNil() {
        let profile = MaternalProfile.load(from: makeTestDefaults())
        #expect(profile == MaternalProfile())
        #expect(profile.bmi == nil)
        #expect(profile.category == nil)
    }

    @Test func savedValuesRoundTripRoundedToOneDecimal() throws {
        let defaults = makeTestDefaults()
        try MaternalProfile(preWeightKg: 52.04, heightCm: 160).save(to: defaults)
        let profile = MaternalProfile.load(from: defaults)
        #expect(profile == MaternalProfile(preWeightKg: 52.0, heightCm: 160))
        #expect(profile.bmi == 20.3)
        #expect(profile.category == .normal)
        #expect(defaults.double(forKey: SettingsKey.maternalPreWeightKg) == 52.0)
    }

    @Test func heightIsOptionalAndClearingWritesZero() throws {
        let defaults = makeTestDefaults()
        try MaternalProfile(preWeightKg: 52, heightCm: 160).save(to: defaults)
        try MaternalProfile(preWeightKg: 52).save(to: defaults)
        let profile = MaternalProfile.load(from: defaults)
        #expect(profile.heightCm == nil)
        #expect(profile.category == nil)
        #expect(defaults.object(forKey: SettingsKey.maternalHeightCm) as? Double == 0)
    }

    @Test func outOfRangeValuesAreRefusedWithoutWritingAnything() throws {
        let defaults = makeTestDefaults()
        try MaternalProfile(preWeightKg: 52, heightCm: 160).save(to: defaults)
        #expect(throws: MaternalProfileError.invalidWeight) {
            try MaternalProfile(preWeightKg: 29.9, heightCm: 170).save(to: defaults)
        }
        #expect(throws: MaternalProfileError.invalidHeight) {
            try MaternalProfile(preWeightKg: 60, heightCm: 220.1).save(to: defaults)
        }
        #expect(MaternalProfile.load(from: defaults) == MaternalProfile(preWeightKg: 52, heightCm: 160))
        try MaternalProfile(preWeightKg: 30, heightCm: 120).save(to: defaults)
        try MaternalProfile(preWeightKg: 200, heightCm: 220).save(to: defaults)
    }

    @Test func storedValuesOutsideTheRangesAreIgnored() {
        let defaults = makeTestDefaults()
        defaults.set(12.0, forKey: SettingsKey.maternalPreWeightKg)
        defaults.set(300.0, forKey: SettingsKey.maternalHeightCm)
        #expect(MaternalProfile.load(from: defaults) == MaternalProfile())
    }
}
