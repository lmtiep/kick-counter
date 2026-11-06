import Foundation

/// Seam over ActivityKit. The real implementation lives in the app target
/// (ActivityKit and the activity attributes are iOS-only).
@MainActor
public protocol LiveActivityManaging: AnyObject {
    /// False when the user has turned Live Activities off in Settings.
    var isAvailable: Bool { get }
    func hasActivity(for sessionID: UUID) -> Bool
    /// Starts an activity for the session, ending activities of any other session.
    func start(sessionID: UUID, startedAt: Date, count: Int) async
    /// No-op when that session has no activity.
    func update(sessionID: UUID, count: Int, completedAt: Date?) async
    /// No-op when that session has no activity. `dismissAfter <= 0` removes it immediately.
    func end(sessionID: UUID, dismissAfter: TimeInterval) async
    /// Ends every stray Live Activity. Unless `force`, implementations leave a
    /// completed ("Done!") activity alone — it already carries its own dismissal
    /// policy (see `KickCoordinator.completedActivityLinger`) and ending it here
    /// would dismiss a still-relevant "Done!" card the mother hasn't seen yet.
    /// `force` (the pregnancy ended, 1.1 item 4) removes that card too, at once.
    func endAll(force: Bool) async
}

extension LiveActivityManaging {
    /// `endAll(force: false)`: the "Done!" card stays until its own dismissal.
    public func endAll() async {
        await endAll(force: false)
    }
}
