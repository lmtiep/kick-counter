import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import KickCore

@MainActor
struct AppointmentCoordinatorTests {
    let repository: FakeAppointmentRepository
    let center: FakeNotificationCenter
    let clock: TestClock
    let coordinator: AppointmentCoordinator

    init() {
        let repository = FakeAppointmentRepository()
        let center = FakeNotificationCenter()
        let clock = TestClock(date("2026-10-02T12:00:00Z"))
        self.repository = repository
        self.center = center
        self.clock = clock
        coordinator = AppointmentCoordinator(
            store: repository,
            notifications: NotificationScheduler(center: center),
            reminderText: NotificationText(title: "Check-up tomorrow", body: "Bring your records"),
            calendar: utcCalendar,
            now: { clock.now }
        )
    }

    private func days(_ count: Int) -> Date {
        clock.now.addingTimeInterval(Double(count) * 86_400)
    }

    private func reminderDay(_ request: UNNotificationRequest?) -> Int? {
        (request?.trigger as? UNCalendarNotificationTrigger)?.dateComponents.day
    }

    @Test func addSavesTrimmedAndSchedulesTheDayBeforeReminder() async throws {
        let record = try #require(await coordinator.add(date: date("2026-10-20T14:30:00Z"), title: "  Anomaly scan ", note: " Bring results "))
        #expect(record.title == "Anomaly scan")
        #expect(record.note == "Bring results")
        #expect(coordinator.upcoming == [record])
        #expect(coordinator.nextAppointment == record)
        let request = try #require(center.added.first)
        #expect(request.identifier == NotificationScheduler.appointmentReminderID(for: record.id))
        #expect(reminderDay(request) == 19)
        #expect(request.content.subtitle == "Anomaly scan")
    }

    @Test func addKeepsTheMilestoneID() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Glucose test", milestoneID: "gdm-screening"))
        #expect(repository.appointments[record.id]?.milestoneID == "gdm-screening")
    }

    @Test func pastAppointmentIsSavedWithoutReminder() async throws {
        let record = try #require(await coordinator.add(date: days(-3), title: "First visit"))
        #expect(coordinator.past == [record])
        #expect(coordinator.upcoming.isEmpty)
        #expect(center.added.isEmpty)
    }

    @Test func deniedNotificationsStillSaveAndRaiseTheHint() async throws {
        center.status = .denied
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        #expect(coordinator.upcoming == [record])
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied)
    }

    @Test func failedAddReportsSaveFailureAndSchedulesNothing() async {
        repository.failNextWrite = true
        let record = await coordinator.add(date: days(10), title: "Scan")
        #expect(record == nil)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.upcoming.isEmpty)
        #expect(center.added.isEmpty)
        coordinator.clearFailure()
        #expect(coordinator.failure == nil)
    }

    @Test func updateReschedulesForTheNewDate() async throws {
        var record = try #require(await coordinator.add(date: date("2026-10-20T10:00:00Z"), title: "Scan"))
        record.date = date("2026-10-25T10:00:00Z")
        #expect(await coordinator.update(record))
        #expect(center.added.count == 1)
        #expect(reminderDay(center.added.first) == 24)
    }

    @Test func movingIntoThePastCancelsTheReminder() async throws {
        var record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        record.date = days(-1)
        #expect(await coordinator.update(record))
        #expect(center.added.isEmpty)
        #expect(coordinator.past.map(\.id) == [record.id])
    }

    @Test func failedUpdateReportsSaveFailure() async throws {
        var record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        repository.failNextWrite = true
        record.title = "Changed"
        #expect(await coordinator.update(record) == false)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.upcoming.first?.title == "Scan")
    }

    @Test func deleteCancelsTheReminder() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        await coordinator.delete(id: record.id)
        #expect(coordinator.upcoming.isEmpty)
        #expect(center.added.isEmpty)
        #expect(center.removed.contains(NotificationScheduler.appointmentReminderID(for: record.id)))
    }

    @Test func failedDeleteKeepsAppointmentAndReminder() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        repository.failNextWrite = true
        await coordinator.delete(id: record.id)
        #expect(coordinator.failure == .saveFailed)
        #expect(coordinator.upcoming == [record])
        #expect(center.added.count == 1)
    }

    @Test func markDoneCancelsTheReminderAndMovesToPast() async throws {
        let record = try #require(await coordinator.add(date: days(10), title: "Scan"))
        await coordinator.markDone(id: record.id)
        #expect(coordinator.upcoming.isEmpty)
        #expect(coordinator.past.first?.isDone == true)
        #expect(center.added.isEmpty)
    }

    @Test func failedLoadReportsLoadFailure() async {
        repository.failNextRead = true
        await coordinator.load()
        #expect(coordinator.failure == .loadFailed)
    }

    @Test func loadPublishesListsAndReconcilesReminders() async throws {
        let upcoming = AppointmentRecord(date: days(10), title: "Scan")
        let done = AppointmentRecord(date: days(5), title: "Blood test", isDone: true)
        let old = AppointmentRecord(date: days(-7), title: "First visit")
        repository.seed(upcoming, done, old)
        // A reminder for an appointment deleted on another device.
        let orphan = UUID()
        try await NotificationScheduler(center: center).scheduleAppointmentReminder(
            id: orphan, date: days(10), title: "Gone", now: clock.now,
            text: NotificationText(title: "T", body: "B"), calendar: utcCalendar
        )

        await coordinator.load()

        #expect(coordinator.upcoming == [upcoming])
        #expect(coordinator.past == [done, old])
        #expect(center.added.map(\.identifier) == [NotificationScheduler.appointmentReminderID(for: upcoming.id)])
        #expect(center.removed.contains(NotificationScheduler.appointmentReminderID(for: orphan)))
    }

    @Test func loadNeverPromptsForPermission() async {
        center.status = .notDetermined
        repository.seed(AppointmentRecord(date: days(10), title: "Scan"))
        await coordinator.load()
        #expect(center.requestCount == 0)
        #expect(center.added.isEmpty)
        #expect(coordinator.notificationsDenied == false)
        #expect(coordinator.upcoming.count == 1)
    }

    @Test func deletingWhileThePermissionPromptIsOpenLeavesNoReminder() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let adding: AppointmentRecord? = coordinator.add(date: days(10), title: "Scan") // suspends on the prompt
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)
        let id = try #require(coordinator.upcoming.first?.id)

        await coordinator.delete(id: id)
        center.releaseRequestAuthorization()
        _ = await adding

        #expect(center.added.isEmpty)
    }

    @Test func editingWhileThePermissionPromptIsOpenKeepsTheNewestDate() async throws {
        center.status = .notDetermined
        center.holdRequestAuthorization = true

        async let adding: AppointmentRecord? = coordinator.add(date: date("2026-10-20T10:00:00Z"), title: "Scan")
        defer { center.releaseRequestAuthorization() }
        try await waitUntil(center.requestAuthorizationPending)
        var record = try #require(coordinator.upcoming.first)

        record.date = date("2026-10-25T10:00:00Z")
        #expect(await coordinator.update(record))
        center.releaseRequestAuthorization()
        _ = await adding

        #expect(center.added.count == 1)
        #expect(reminderDay(center.added.first) == 24)
    }

    @Test func deletingWhileTheReminderRequestIsInFlightLeavesNoReminder() async throws {
        center.holdAdd = true

        async let adding: AppointmentRecord? = coordinator.add(date: days(10), title: "Scan") // suspends in center.add
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)
        let id = try #require(coordinator.upcoming.first?.id)

        await coordinator.delete(id: id)
        center.releaseAdd()
        _ = await adding

        #expect(center.added.isEmpty)
    }

    @Test func markingDoneWhileTheReminderRequestIsInFlightLeavesNoReminder() async throws {
        center.holdAdd = true

        async let adding: AppointmentRecord? = coordinator.add(date: days(10), title: "Scan")
        defer { center.releaseAdd() }
        try await waitUntil(center.addPending)
        let id = try #require(coordinator.upcoming.first?.id)

        await coordinator.markDone(id: id)
        center.releaseAdd()
        _ = await adding

        #expect(center.added.isEmpty)
        #expect(coordinator.past.first?.isDone == true)
    }

    /// Only the soonest appointments get a reminder at once, so the pill
    /// reminders always fit under iOS's 64 pending requests.
    @Test func onlyTheSoonestAppointmentsAreScheduled() async throws {
        let cap = NotificationScheduler.maxAppointmentReminders
        for offset in (2...(cap + 6)).reversed() {
            _ = await coordinator.add(date: days(offset), title: "Visit \(offset)")
        }
        let pending = center.added.filter { $0.identifier.hasPrefix(NotificationScheduler.appointmentReminderPrefix) }
        #expect(pending.count == cap)
        await coordinator.load()
        let afterLoad = center.added.filter { $0.identifier.hasPrefix(NotificationScheduler.appointmentReminderPrefix) }
        #expect(afterLoad.count == cap)
        let soonest = Set(coordinator.upcoming.prefix(cap).map { NotificationScheduler.appointmentReminderID(for: $0.id) })
        #expect(Set(afterLoad.map(\.identifier)) == soonest)
    }
}
