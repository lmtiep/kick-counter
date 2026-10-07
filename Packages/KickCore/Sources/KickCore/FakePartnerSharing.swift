import Foundation

/// In-memory `PartnerSharing` (spec §4.3), used by the KickCore tests and, through
/// `-uiTestingSharing` / `-uiTestingPartner`, by the UI tests. One instance plays
/// both sides: what the mother publishes is what an accepted partner fetches.
public actor FakePartnerSharing: PartnerSharing {
    /// `-uiTestingSharing <state>`: the mother's side.
    public enum MotherState: String, Sendable, CaseIterable {
        case notShared, invited, joined, icloudUnavailable
    }

    /// `-uiTestingPartner <state>`: the partner's side.
    public enum PartnerState: String, Sendable, CaseIterable {
        case snapshot, stopped, error, icloudUnavailable
    }

    private var isShared = false
    private var participantCount = 0
    private var isAccepted = false
    private var payload: Data?
    private var failure: PartnerSharingError?
    public private(set) var publishCount = 0
    public private(set) var isRegisteredForChanges = false

    public init() {}

    public init(mother state: MotherState) {
        switch state {
        case .notShared:
            break
        case .invited:
            isShared = true
        case .joined:
            isShared = true
            participantCount = 1
        case .icloudUnavailable:
            failure = .iCloudUnavailable
        }
    }

    /// `snapshot` is what the `.snapshot` state shows.
    public init(partner state: PartnerState, snapshot: PartnerSnapshot) {
        isAccepted = true
        switch state {
        case .snapshot:
            isShared = true
            participantCount = 1
            payload = try? snapshot.encoded()
        case .stopped:
            break
        case .error:
            failure = .retryable
        case .icloudUnavailable:
            failure = .iCloudUnavailable
        }
    }

    // MARK: - Test controls

    /// Every call throws `failure` until it is set back to nil.
    public func setFailure(_ failure: PartnerSharingError?) {
        self.failure = failure
    }

    /// Someone accepted the invitation on another device.
    public func partnerJoins() {
        guard isShared else { return }
        participantCount += 1
    }

    /// Replaces the stored snapshot with raw bytes (e.g. a corrupt payload).
    public func storeRawPayload(_ data: Data) {
        payload = data
    }

    // MARK: - PartnerSharing

    public func shareStatus() async throws -> PartnerShareStatus {
        try check()
        guard isShared else { return .notShared }
        return participantCount > 0 ? .joined(participantCount: participantCount) : .invited
    }

    public func prepareShare() async throws -> PartnerShareHandle {
        try check()
        isShared = true
        return PartnerShareHandle(payload: nil)
    }

    public func publish(_ snapshot: PartnerSnapshot) async throws {
        try check()
        guard isShared else { throw PartnerSharingError.notShared }
        do {
            payload = try snapshot.encoded()
        } catch {
            throw PartnerSharingError.failed(code: -1)
        }
        publishCount += 1
    }

    public func stopSharing() async throws {
        try check()
        isShared = false
        participantCount = 0
        payload = nil
    }

    public func accept(_ invitation: PartnerInvitation) async throws {
        try check()
        isAccepted = true
        if isShared { participantCount = max(participantCount, 1) }
    }

    public func fetchSharedSnapshot() async throws -> PartnerSnapshot? {
        try check()
        guard isAccepted, isShared, let payload else { return nil }
        guard let snapshot = PartnerSnapshot.decode(payload) else { throw PartnerSharingError.unreadableSnapshot }
        return snapshot
    }

    public func registerForChanges() async throws {
        try check()
        isRegisteredForChanges = true
    }

    private func check() throws {
        if let failure { throw failure }
    }
}

extension PartnerSnapshot {
    /// The fixed snapshot of `-uiTestingPartner snapshot` (spec §4.3): week 24
    /// (due 19 January 2027 against the UI tests' pinned 2 October 2026), two
    /// appointments and a session three hours ago, updated ten minutes ago.
    public static func uiTestSample(now: Date, language: ContentLanguage) -> PartnerSnapshot {
        let vi = language == .vi
        return PartnerSnapshot(
            updatedAt: now.addingTimeInterval(-10 * 60),
            displayName: vi ? "Mẹ" : "Mom",
            // Noon UTC like the UI tests' due dates, so every simulator time zone sees week 24.
            dueDate: Date(timeIntervalSince1970: 1_800_360_000),
            appointments: [
                PartnerAppointment(title: vi ? "Siêu âm hình thái" : "Anomaly scan", date: now.addingTimeInterval(5 * 86_400)),
                PartnerAppointment(title: vi ? "Xét nghiệm đường huyết" : "Glucose test", date: now.addingTimeInterval(19 * 86_400)),
            ],
            kicks: PartnerKickSummary(
                lastSession: PartnerKickSession(startedAt: now.addingTimeInterval(-3 * 3_600), kicks: 10, durationMinutes: 18),
                sessionsLast7Days: 4,
                averageMinutesLast7Days: 21
            )
        )
    }
}
