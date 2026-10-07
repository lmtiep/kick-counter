import Foundation
import Observation

/// Invitations opened from Messages or Mail wait here until the app handles
/// them (the scene delegate receives them before any view exists).
@MainActor
@Observable
public final class PartnerInvitationInbox {
    public private(set) var pending: PartnerInvitation?

    public init() {}

    public func receive(_ invitation: PartnerInvitation) {
        pending = invitation
    }

    /// Hands the pending invitation over once.
    public func take() -> PartnerInvitation? {
        defer { pending = nil }
        return pending
    }
}

public enum PartnerAcceptResult: Equatable, Sendable {
    case accepted
    /// The mother opened her own link: nothing changes.
    case ignoredOwnInvitation
    case failed(PartnerSharingError)
}

/// Accepting an invitation (spec §5.2): accept it through iCloud, then switch
/// to partner mode with onboarding skipped. A failure changes nothing. When
/// onboarding had not been completed yet (a fresh install), that is remembered
/// so leaving partner mode shows it.
@MainActor
public enum PartnerAcceptance {
    public static func accept(
        _ invitation: PartnerInvitation,
        sharing: any PartnerSharing,
        defaults: UserDefaults
    ) async -> PartnerAcceptResult {
        do {
            try await sharing.accept(invitation)
        } catch PartnerSharingError.ownInvitation {
            return .ignoredOwnInvitation
        } catch let error as PartnerSharingError {
            return .failed(error)
        } catch {
            return .failed(.failed(code: -1))
        }
        if !defaults.bool(forKey: SettingsKey.hasCompletedOnboarding) {
            defaults.set(true, forKey: SettingsKey.partnerSkippedOnboarding)
            defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
        }
        AppMode.enterPartner(in: defaults)
        return .accepted
    }
}
