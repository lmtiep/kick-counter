import Foundation
import Testing
@testable import KickCore

/// Phase 8 spec §5.2: accepting an invitation switches to partner mode.
@MainActor
struct PartnerAcceptanceTests {
    @Test func acceptingSwitchesToPartnerModeAndSkipsOnboarding() async {
        let defaults = makeTestDefaults()
        AppMode.save(.tryingToConceive, to: defaults)
        let result = await PartnerAcceptance.accept(PartnerInvitation(payload: nil), sharing: FakePartnerSharing(), defaults: defaults)
        #expect(result == .accepted)
        #expect(AppMode.load(from: defaults) == .partner)
        #expect(defaults.bool(forKey: SettingsKey.hasCompletedOnboarding))
        #expect(defaults.bool(forKey: SettingsKey.partnerSkippedOnboarding))
        #expect(AppMode.leavePartner(in: defaults) == .tryingToConceive)
    }

    @Test func anOnboardedUserIsNotMarkedAsSkippingOnboarding() async {
        let defaults = makeTestDefaults()
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        _ = await PartnerAcceptance.accept(PartnerInvitation(payload: nil), sharing: FakePartnerSharing(), defaults: defaults)
        #expect(AppMode.load(from: defaults) == .partner)
        #expect(!defaults.bool(forKey: SettingsKey.partnerSkippedOnboarding))
    }

    @Test func aFailureChangesNothing() async {
        let defaults = makeTestDefaults()
        let sharing = FakePartnerSharing()
        await sharing.setFailure(.iCloudUnavailable)
        let result = await PartnerAcceptance.accept(PartnerInvitation(payload: nil), sharing: sharing, defaults: defaults)
        #expect(result == .failed(.iCloudUnavailable))
        #expect(AppMode.load(from: defaults) == .pregnant)
        #expect(defaults.string(forKey: SettingsKey.appMode) == nil)
        #expect(!defaults.bool(forKey: SettingsKey.hasCompletedOnboarding))
    }

    @Test func theMothersOwnLinkIsIgnored() async {
        let defaults = makeTestDefaults()
        let sharing = FakePartnerSharing()
        await sharing.setFailure(.ownInvitation)
        let result = await PartnerAcceptance.accept(PartnerInvitation(payload: nil), sharing: sharing, defaults: defaults)
        #expect(result == .ignoredOwnInvitation)
        #expect(defaults.string(forKey: SettingsKey.appMode) == nil)
    }

    @Test func theInboxHandsAnInvitationOverOnce() {
        let inbox = PartnerInvitationInbox()
        #expect(inbox.take() == nil)
        let invitation = PartnerInvitation(payload: nil)
        inbox.receive(invitation)
        #expect(inbox.pending?.id == invitation.id)
        #expect(inbox.take()?.id == invitation.id)
        #expect(inbox.pending == nil)
        #expect(inbox.take() == nil)
    }
}
