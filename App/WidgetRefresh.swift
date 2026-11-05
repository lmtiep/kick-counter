import KickCore
import SwiftData
import UIKit
import WidgetKit

/// Keeps the Home Screen / Lock Screen widget in step with the app (1.1). The widget
/// reads the App Group itself, so all the app does is ask for a reload when
/// something it shows may have changed: any save to the store (periods, day logs,
/// kick sessions, appointments, restore, delete-all), any change to the shared
/// settings (mode, goal, due date, cycle lengths, language, onboarding), and when
/// the app comes forward or goes to the background. Bursts collapse into one reload.
@MainActor
enum WidgetRefresh {
    private static var pending: Task<Void, Never>?
    private static var observers: [Task<Void, Never>] = []

    /// Reloads every widget timeline now.
    static func reload() {
        pending?.cancel()
        pending = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Reloads shortly, once, however many changes arrive in between.
    static func reloadSoon() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            pending = nil
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Call once at launch.
    static func startObserving() {
        guard observers.isEmpty else { return }
        let names: [Notification.Name] = [
            ModelContext.didSave,
            UserDefaults.didChangeNotification,
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
        ]
        observers = names.map { name in
            Task { @MainActor in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    reloadSoon()
                }
            }
        }
    }
}
