import KickCore
import LocalAuthentication
import SwiftUI
import UIKit

/// Face ID / Touch ID / passcode lock (1.2 spec §3). `AppLockPolicy` decides when;
/// this runs LocalAuthentication and keeps the setting. Never in UI tests.
@MainActor
@Observable
final class AppLock {
    enum Kind { case faceID, touchID, passcode }

    private(set) var policy: AppLockPolicy
    /// Observed copy of the setting (UserDefaults itself is not observed).
    private(set) var isEnabled: Bool
    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        let enabled = !AppEnvironment.isUITesting && defaults.bool(forKey: SettingsKey.appLockEnabled)
        let canAuthenticate = Self.canAuthenticate
        // The passcode was removed since she turned it on: open, and the setting goes off.
        if enabled, !canAuthenticate { defaults.set(false, forKey: SettingsKey.appLockEnabled) }
        isEnabled = enabled && canAuthenticate
        policy = AppLockPolicy(enabled: enabled, canAuthenticate: canAuthenticate)
    }

    var isLocked: Bool { policy.isLocked }

    static var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var kind: Kind {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .passcode
        }
    }

    func sceneChanged(to phase: ScenePhase, now: Date = AppClock.now()) {
        let canAuthenticate = Self.canAuthenticate
        if isEnabled, !canAuthenticate {
            defaults.set(false, forKey: SettingsKey.appLockEnabled)
            isEnabled = false
        }
        switch phase {
        case .background: policy.handle(.enteredBackground(now), enabled: isEnabled, canAuthenticate: canAuthenticate)
        case .active: policy.handle(.becameActive(now), enabled: isEnabled, canAuthenticate: canAuthenticate)
        default: break
        }
    }

    /// Asks for Face ID / Touch ID, falling back to the device passcode.
    func unlock() async {
        guard policy.isLocked else { return }
        if await Self.authenticate() { policy.unlocked() }
    }

    /// Turning it on asks first: a failed or cancelled check leaves it off.
    func setEnabled(_ on: Bool) async {
        if on {
            guard await Self.authenticate() else { return }
        }
        defaults.set(on, forKey: SettingsKey.appLockEnabled)
        isEnabled = on
        policy.handle(.becameActive(AppClock.now()), enabled: on, canAuthenticate: Self.canAuthenticate)
    }

    private static func authenticate() async -> Bool {
        do {
            return try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L10n.appLockReason)
        } catch {
            return false
        }
    }
}

/// Over everything once locked, sheets included: the lock lives in its own window
/// above the app's. While the scene is not active a plain cover hides her diary
/// from the app switcher.
struct AppLockOverlay: ViewModifier {
    let lock: AppLock
    @Environment(\.scenePhase) private var scenePhase

    private var mode: AppLockWindow.Mode {
        if lock.isLocked { return .locked }
        if lock.isEnabled, scenePhase != .active { return .cover }
        return .hidden
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in lock.sceneChanged(to: phase) }
            .onChange(of: mode, initial: true) { _, mode in AppLockWindow.shared.show(mode, lock: lock) }
    }
}

@MainActor
final class AppLockWindow {
    enum Mode: Equatable { case hidden, cover, locked }

    static let shared = AppLockWindow()
    private var window: UIWindow?

    func show(_ mode: Mode, lock: AppLock) {
        guard mode != .hidden else {
            window?.isHidden = true
            window = nil
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
        let window = self.window ?? UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        let root: AnyView = mode == .locked
            ? AnyView(AppLockView(lock: lock).environment(\.locale, AppLocale.locale))
            : AnyView(PrivacyCover())
        window.rootViewController = UIHostingController(rootView: root)
        window.isHidden = false
        if mode == .locked { window.makeKeyAndVisible() }
        self.window = window
    }
}

private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color.luna(.backgroundBottom).ignoresSafeArea()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 44))
                .foregroundStyle(.luna(.cycleStrong))
        }
        .accessibilityHidden(true)
    }
}

struct AppLockView: View {
    let lock: AppLock

    var body: some View {
        ZStack {
            Color.luna(.backgroundBottom).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.luna(.cycleStrong))
                    .accessibilityHidden(true)
                Text(L10n.appLockTitle)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .multilineTextAlignment(.center)
                Button(L10n.appLockUnlock) { Task { await lock.unlock() } }
                    .buttonStyle(.pill(.dark, fullWidth: false, height: 48))
                    .accessibilityIdentifier("appLockUnlock")
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .task { await lock.unlock() }
    }
}
