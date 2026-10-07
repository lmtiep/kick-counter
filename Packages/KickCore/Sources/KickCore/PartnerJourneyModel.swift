import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "partner-journey")

/// What partner Today shows (phase 8 spec §5.2).
public enum PartnerJourneyState: Equatable, Sendable {
    /// Nothing to show yet: the first fetch, or the mother has not published.
    case loading
    case snapshot(PartnerSnapshot)
    /// The mother stopped sharing (or the share is gone).
    case stopped
    /// Network or iCloud trouble, or a snapshot this build cannot read; "Try again".
    case failed
    case iCloudUnavailable
}

/// The partner's side (spec §5.2, §5.3): reads the shared snapshot, keeps the
/// one cached copy in App Group defaults, and leaves partner mode.
@MainActor
@Observable
public final class PartnerJourneyModel {
    public private(set) var state: PartnerJourneyState

    private let sharing: any PartnerSharing
    private let defaults: UserDefaults
    private var registered = false
    /// Bumped on leaving, so a fetch still in flight cannot bring the journey back.
    private var generation = 0

    /// Starts from the cached snapshot, if any, so Today shows at once.
    public init(sharing: any PartnerSharing, defaults: UserDefaults) {
        self.sharing = sharing
        self.defaults = defaults
        let cached = defaults.data(forKey: SettingsKey.partnerCachedSnapshot).flatMap(PartnerSnapshot.decode)
        state = cached.map(PartnerJourneyState.snapshot) ?? .loading
    }

    public var snapshot: PartnerSnapshot? {
        if case .snapshot(let snapshot) = state { return snapshot }
        return nil
    }

    /// The trimester of the shared journey on `now`, for the Knowledge tab.
    public func trimester(now: Date, calendar: Calendar = .current) -> Int? {
        snapshot.flatMap { PregnancyTimeline(dueDate: $0.dueDate, now: now, calendar: calendar) }?.trimester.rawValue
    }

    /// Fetches the snapshot. A share that is gone clears the cache. A share
    /// with nothing published yet keeps loading. Network or iCloud trouble
    /// keeps showing the cached snapshot when there is one.
    public func refresh() async {
        let started = generation
        await registerOnce()
        let result: Result<PartnerSnapshot?, Error>
        do {
            result = .success(try await sharing.fetchSharedSnapshot())
        } catch {
            result = .failure(error)
        }
        // Left partner mode while fetching: forget the answer.
        guard started == generation else { return }
        apply(result)
    }

    /// "Leave partner mode": forgets the shared journey and restores the previous
    /// mode, with onboarding again if accepting the invitation skipped it.
    @discardableResult
    public func leave() -> AppMode {
        generation += 1
        clearCache()
        if defaults.bool(forKey: SettingsKey.partnerSkippedOnboarding) {
            defaults.set(false, forKey: SettingsKey.hasCompletedOnboarding)
            defaults.removeObject(forKey: SettingsKey.partnerSkippedOnboarding)
        }
        registered = false
        state = .loading
        return AppMode.leavePartner(in: defaults)
    }

    private func apply(_ result: Result<PartnerSnapshot?, Error>) {
        switch result {
        case .success(let snapshot?):
            defaults.set(try? snapshot.encoded(), forKey: SettingsKey.partnerCachedSnapshot)
            state = .snapshot(snapshot)
        case .success(nil):
            clearCache()
            state = .stopped
        case .failure(let error):
            apply(error as? PartnerSharingError ?? .failed(code: -1))
        }
    }

    private func apply(_ error: PartnerSharingError) {
        switch error {
        case .notReadyYet:
            // The mother has not published yet: keep what is shown (the cache) or keep loading.
            if snapshot == nil { state = .loading }
        case .iCloudUnavailable:
            state = .iCloudUnavailable
        case .retryable, .iCloudFull, .needsVerification:
            if snapshot != nil {
                logger.info("Keeping the cached snapshot: \(String(describing: error))")
            } else {
                logger.error("Reading the shared snapshot failed: \(String(describing: error))")
                state = .failed
            }
        case .notShared, .unreadableSnapshot, .ownInvitation, .failed:
            logger.error("Reading the shared snapshot failed: \(String(describing: error))")
            state = .failed
        }
    }

    private func clearCache() {
        defaults.removeObject(forKey: SettingsKey.partnerCachedSnapshot)
    }

    /// Silent pushes for the shared database; tried again on the next refresh if it failed.
    private func registerOnce() async {
        guard !registered else { return }
        do {
            try await sharing.registerForChanges()
            registered = true
        } catch {
            logger.error("Subscribing to shared changes failed: \(String(describing: error))")
        }
    }
}
