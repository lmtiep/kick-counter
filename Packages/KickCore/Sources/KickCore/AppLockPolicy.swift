import Foundation

/// When the app locks behind Face ID / Touch ID / the device passcode (1.2 spec §3):
/// at launch, and on return after at least a minute in the background. Becoming
/// active without a background (the Face ID prompt itself) never locks, and a
/// device that can no longer authenticate is never locked out.
public struct AppLockPolicy: Equatable, Sendable {
    public static let backgroundGrace: TimeInterval = 60

    public enum Event: Sendable {
        case enteredBackground(Date)
        case becameActive(Date)
    }

    public private(set) var isLocked: Bool
    private var backgroundedAt: Date?

    public init(enabled: Bool, canAuthenticate: Bool) {
        isLocked = enabled && canAuthenticate
    }

    public mutating func handle(_ event: Event, enabled: Bool, canAuthenticate: Bool) {
        guard enabled, canAuthenticate else {
            isLocked = false
            backgroundedAt = nil
            return
        }
        switch event {
        case .enteredBackground(let date):
            backgroundedAt = date
        case .becameActive(let date):
            if let since = backgroundedAt, date.timeIntervalSince(since) >= Self.backgroundGrace {
                isLocked = true
            }
            backgroundedAt = nil
        }
    }

    public mutating func unlocked() {
        isLocked = false
    }

    /// What the lock window shows. Decided after the policy has handled the scene
    /// change, never before, so a return after a minute goes from cover to lock
    /// without a frame of her diary in between.
    public enum WindowMode: Equatable, Sendable { case hidden, cover, locked }

    public static func windowMode(isLocked: Bool, enabled: Bool, sceneIsActive: Bool) -> WindowMode {
        if isLocked { return .locked }
        return enabled && !sceneIsActive ? .cover : .hidden
    }
}
