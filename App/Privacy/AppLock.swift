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

    private var sceneIsActive = true
    private var wasInBackground = false

    /// The policy first, then the window, in one step: a return after a minute goes
    /// from the cover straight to the lock (review fix: no frame of her diary between).
    func sceneChanged(to phase: ScenePhase, now: Date = AppClock.now()) {
        let canAuthenticate = Self.canAuthenticate
        if isEnabled, !canAuthenticate {
            defaults.set(false, forKey: SettingsKey.appLockEnabled)
            isEnabled = false
        }
        let returning = phase == .active && wasInBackground
        switch phase {
        case .background:
            wasInBackground = true
            policy.handle(.enteredBackground(now), enabled: isEnabled, canAuthenticate: canAuthenticate)
        case .active:
            wasInBackground = false
            policy.handle(.becameActive(now), enabled: isEnabled, canAuthenticate: canAuthenticate)
        default: break
        }
        sceneIsActive = phase == .active
        updateWindow()
        // Back from the background still locked: ask again. Not after the Face ID
        // prompt itself (inactive → active), which would loop on a cancel.
        if returning, policy.isLocked { Task { await unlock() } }
    }

    func updateWindow() {
        AppLockWindow.shared.show(
            AppLockPolicy.windowMode(isLocked: policy.isLocked, enabled: isEnabled, sceneIsActive: sceneIsActive),
            lock: self
        )
    }

    /// Asks for Face ID / Touch ID, falling back to the device passcode.
    func unlock() async {
        guard policy.isLocked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }
        if await Self.authenticate() {
            policy.unlocked()
            updateWindow()
        }
    }

    private var authenticating = false

    /// Turning it on asks first: a failed or cancelled check leaves it off.
    func setEnabled(_ on: Bool) async {
        if on {
            guard await Self.authenticate() else { return }
        }
        defaults.set(on, forKey: SettingsKey.appLockEnabled)
        isEnabled = on
        policy.handle(.becameActive(AppClock.now()), enabled: on, canAuthenticate: Self.canAuthenticate)
        updateWindow()
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

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in lock.sceneChanged(to: phase) }
            .onAppear { lock.updateWindow() }
    }
}

@MainActor
final class AppLockWindow {
    typealias Mode = AppLockPolicy.WindowMode

    static let shared = AppLockWindow()
    private var window: UIWindow?
    private var shown: Mode = .hidden

    func show(_ mode: Mode, lock: AppLock) {
        guard mode != shown else { return }
        shown = mode
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
