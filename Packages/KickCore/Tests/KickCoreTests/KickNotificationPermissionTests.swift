import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

/// Phase 9: the pregnancy branch's "Turn on reminders" on the result step.
@MainActor
struct KickNotificationPermissionTests {
    private func makeCoordinator(_ center: FakeNotificationCenter) -> KickCoordinator {
        KickCoordinator(
            store: FakeSessionRepository(),
            notifications: NotificationScheduler(center: center),
            liveActivities: FakeLiveActivities(),
            overdueText: NotificationText(title: "Overdue", body: "Call your doctor")
        )
    }

    @Test func asksOnceWhenNeverAsked() async {
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        #expect(await makeCoordinator(center).requestNotificationPermission())
        #expect(center.requestCount == 1)
    }

    @Test func neverAsksAgainAfterARefusal() async {
        let center = FakeNotificationCenter()
        center.status = .denied
        #expect(await makeCoordinator(center).requestNotificationPermission() == false)
        #expect(center.requestCount == 0)
    }
}
