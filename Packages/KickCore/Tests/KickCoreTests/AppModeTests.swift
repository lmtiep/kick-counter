import Foundation
import Testing
@testable import KickCore

struct AppModeTests {
    @Test func missingModeMeansPregnant() {
        #expect(AppMode.load(from: makeTestDefaults()) == .pregnant)
    }

    @Test func existingUserWithDueDateStaysPregnant() {
        let defaults = makeTestDefaults()
        defaults.set(date("2027-01-19T12:00:00Z").timeIntervalSince1970, forKey: SettingsKey.dueDate)
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        #expect(AppMode.load(from: defaults) == .pregnant)
    }

    @Test func savedModeRoundTrips() {
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        #expect(defaults.string(forKey: SettingsKey.appMode) == "tryingToConceive")
        #expect(AppMode.load(from: defaults) == .tryingToConceive)
        AppMode.save(.pregnant, to: defaults)
        #expect(AppMode.load(from: defaults) == .pregnant)
    }

    @Test func unknownStoredValueFallsBackToPregnant() {
        let defaults = makeTestDefaults()
        defaults.set("planning", forKey: SettingsKey.appMode)
        #expect(AppMode.load(from: defaults) == .pregnant)
    }

    @Test func partnerModeRoundTrips() {
        let defaults = makeTestDefaults()
        AppMode.save(.partner, to: defaults)
        #expect(defaults.string(forKey: SettingsKey.appMode) == "partner")
        #expect(AppMode.load(from: defaults) == .partner)
    }

    @Test func leavingPartnerModeRestoresThePreviousMode() {
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        AppMode.enterPartner(in: defaults)
        #expect(AppMode.load(from: defaults) == .partner)
        #expect(defaults.string(forKey: SettingsKey.previousAppMode) == "tryingToConceive")
        #expect(AppMode.leavePartner(in: defaults) == .tryingToConceive)
        #expect(AppMode.load(from: defaults) == .tryingToConceive)
        #expect(defaults.string(forKey: SettingsKey.previousAppMode) == nil)
    }

    @Test func enteringPartnerModeTwiceKeepsTheFirstPreviousMode() {
        let defaults = makeTestDefaults()
        AppMode.save(.pregnant, to: defaults)
        AppMode.enterPartner(in: defaults)
        AppMode.enterPartner(in: defaults)
        #expect(AppMode.leavePartner(in: defaults) == .pregnant)
    }

    @Test func leavingWithoutARememberedModeMeansPregnant() {
        let defaults = makeTestDefaults()
        AppMode.save(.partner, to: defaults)
        #expect(AppMode.leavePartner(in: defaults) == .pregnant)
        #expect(AppMode.load(from: defaults) == .pregnant)
    }
}

struct CycleSettingsTests {
    @Test func defaultsAre28DayCycle5DayPeriodRemindersOn() {
        let settings = CycleSettings.load(from: makeTestDefaults())
        #expect(settings == CycleSettings(typicalCycleLength: 28, typicalPeriodLength: 5, remindersEnabled: true))
    }

    @Test func savedSettingsRoundTrip() {
        let defaults = makeTestDefaults()
        CycleSettings(typicalCycleLength: 32, typicalPeriodLength: 4, remindersEnabled: false).save(to: defaults)
        #expect(CycleSettings.load(from: defaults) == CycleSettings(typicalCycleLength: 32, typicalPeriodLength: 4, remindersEnabled: false))
        #expect(defaults.integer(forKey: SettingsKey.typicalCycleLength) == 32)
        #expect(defaults.bool(forKey: SettingsKey.cycleRemindersEnabled) == false)
    }

    @Test func lengthsAreClampedToTheAllowedRanges() {
        #expect(CycleSettings(typicalCycleLength: 14, typicalPeriodLength: 1).typicalCycleLength == 21)
        #expect(CycleSettings(typicalCycleLength: 14, typicalPeriodLength: 1).typicalPeriodLength == 2)
        #expect(CycleSettings(typicalCycleLength: 60, typicalPeriodLength: 12).typicalCycleLength == 45)
        #expect(CycleSettings(typicalCycleLength: 60, typicalPeriodLength: 12).typicalPeriodLength == 10)
    }

    @Test func outOfRangeStoredValuesAreClamped() {
        let defaults = makeTestDefaults()
        defaults.set(90, forKey: SettingsKey.typicalCycleLength)
        defaults.set(0, forKey: SettingsKey.typicalPeriodLength)
        let settings = CycleSettings.load(from: defaults)
        #expect(settings.typicalCycleLength == 45)
        #expect(settings.typicalPeriodLength == 2)
    }
}
