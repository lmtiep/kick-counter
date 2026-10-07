import Foundation
import OSLog

private let logger = Logger(subsystem: "com.lmtiep.kickcounter", category: "partner-publish")

/// Uploads the mother's snapshot while she shares (phase 8 spec §5.1). The app
/// hands it every rebuilt snapshot. A snapshot whose content differs from the
/// last upload, `requestPublish()`, or becoming active (at most every six
/// hours) schedules one upload 5 s after the last trigger; `publishNow()`
/// uploads at once (the share was just created). The last upload is
/// remembered across launches. Failures are logged; the next trigger retries.
@MainActor
public final class PartnerPublisher {
    private let sharing: any PartnerSharing
    private let isActive: @MainActor () -> Bool
    private let defaults: UserDefaults
    private let now: @MainActor () -> Date
    private let sleep: @Sendable (TimeInterval) async -> Void
    private var scheduler: PartnerPublishScheduler
    /// The snapshot as it stands now.
    private var latest: PartnerSnapshot?
    /// The last snapshot uploaded (from this launch or an earlier one).
    private var published: PartnerSnapshot?
    /// The next upload happens even if the content is already published.
    private var forced = false
    private var worker: Task<Void, Never>?
    /// The last upload started: each upload waits for the one before it, so
    /// `publishNow()` and the worker never upload at the same time and
    /// `published` always records the newest upload.
    private var upload: Task<Bool, Never>?

    /// `now` must be the real clock: the scheduler waits on it. `sleep` is a seam for tests.
    public init(
        sharing: any PartnerSharing,
        isActive: @escaping @MainActor () -> Bool,
        defaults: UserDefaults,
        now: @escaping @MainActor () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
            try? await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.sharing = sharing
        self.isActive = isActive
        self.defaults = defaults
        self.now = now
        self.sleep = sleep
        published = defaults.data(forKey: SettingsKey.partnerPublishedSnapshot).flatMap(PartnerSnapshot.decode)
        scheduler = PartnerPublishScheduler(lastPublished: published?.updatedAt)
    }

    /// The snapshot as it stands now; nil when there is nothing to share (no due date).
    public func update(_ snapshot: PartnerSnapshot?) {
        latest = snapshot
        guard let snapshot, !isPublished(snapshot) else { return }
        scheduler.noteChange(at: now())
        startWorker()
    }

    /// Publish soon even if nothing changed.
    public func requestPublish() {
        forced = true
        scheduler.noteChange(at: now())
        startWorker()
    }

    /// Uploads the current snapshot right away, even if it was uploaded before:
    /// the share was just created or opened, and a partner who accepts at once
    /// must find a record. Returns true when it was uploaded; a failed upload
    /// is retried once 5 s later.
    @discardableResult
    public func publishNow() async -> Bool {
        guard isActive(), latest != nil else { return false }
        forced = true
        if await publishLatest() { return true }
        // The pending change keeps `forced`: the retry uploads even unchanged content.
        scheduler.noteChange(at: now())
        startWorker()
        return false
    }

    /// The app became active: refresh the partner's copy if the last upload is
    /// six hours old, and upload any change that was dropped (a failed upload,
    /// or one due while not sharing) whatever the time since the last upload.
    public func noteBecameActive() {
        let before = scheduler.lastChange
        scheduler.noteBecameActive(at: now())
        if scheduler.lastChange != before {
            forced = true
        } else if let latest, !isPublished(latest) {
            scheduler.noteChange(at: now())
        }
        startWorker()
    }

    /// The app became active, with the snapshot rebuilt at the current time:
    /// the 7-day kick window and the upcoming check-ups move with the clock
    /// even when nothing was edited, so the six-hourly refresh never uploads
    /// a summary built when something last changed.
    public func noteBecameActive(rebuilt snapshot: PartnerSnapshot?) {
        update(snapshot)
        noteBecameActive()
    }

    /// Sharing stopped and the zone is gone: the next share starts from nothing.
    public func forgetPublished() {
        published = nil
        let pending = scheduler.lastChange
        scheduler = PartnerPublishScheduler()
        if let pending { scheduler.noteChange(at: pending) }
        defaults.removeObject(forKey: SettingsKey.partnerPublishedSnapshot)
    }

    /// Waits for the scheduled upload, if any (tests).
    public func waitUntilIdle() async {
        await worker?.value
        _ = await upload?.value
    }

    private func isPublished(_ snapshot: PartnerSnapshot) -> Bool {
        published.map { snapshot.hasSameContent(as: $0) } ?? false
    }

    private func startWorker() {
        guard worker == nil, scheduler.hasPendingChange else { return }
        worker = Task { [weak self] in
            await self?.run()
        }
    }

    private func run() async {
        while let delay = scheduler.delay(at: now()) {
            if delay > 0 {
                await sleep(delay)
            } else {
                await publishLatest()
            }
        }
        worker = nil
    }

    /// True when a snapshot was uploaded. Runs after any upload in flight.
    @discardableResult
    private func publishLatest() async -> Bool {
        let previous = upload
        let task = Task { [weak self] () -> Bool in
            _ = await previous?.value
            guard let self else { return false }
            return await self.uploadLatest()
        }
        upload = task
        return await task.value
    }

    private func uploadLatest() async -> Bool {
        scheduler.startPublishing()
        let force = forced
        forced = false
        guard isActive(), var snapshot = latest, force || !isPublished(snapshot) else { return false }
        let time = now()
        snapshot.updatedAt = time
        do {
            try await sharing.publish(snapshot)
            scheduler.didPublish(at: time)
            published = snapshot
            defaults.set(try? snapshot.encoded(), forKey: SettingsKey.partnerPublishedSnapshot)
            return true
        } catch {
            forced = forced || force
            logger.error("Publishing the partner snapshot failed: \(String(describing: error))")
            return false
        }
    }
}
