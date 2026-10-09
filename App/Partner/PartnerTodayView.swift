import KickCore
import SwiftUI

/// Partner mode, Today tab (phase 8 spec §5.2): the shared journey, read-only.
/// Refreshes on appear, on pull to refresh and on a silent iCloud push.
struct PartnerTodayView: View {
    let onLeave: () -> Void

    @Environment(PartnerJourneyModel.self) private var journey
    @Environment(\.contentLibrary) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detailWeek: WeekSelection?

    private let language = ContentLanguage.current
    private var now: Date { AppClock.now() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .accessibilityIdentifier("partnerToday")
        .lunaStatusBarBackdrop()
        .lunaBackground()
        .refreshable { await journey.refresh() }
        .task { await journey.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .partnerSnapshotChanged)) { _ in
            Task { await journey.refresh() }
        }
        .animation(LunaMotion.isEnabled && !reduceMotion ? LunaMotion.fade : nil, value: journey.state)
        .fullScreenCover(item: $detailWeek) { selection in
            WeekDetailView(currentWeek: selection.week)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch journey.state {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text(L10n.partnerLoading)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 80)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("partnerLoading")
        case .snapshot(let snapshot):
            journeyCards(snapshot)
        case .stopped:
            message(
                title: L10n.partnerStoppedTitle,
                body: L10n.partnerStoppedBody,
                action: L10n.partnerLeave,
                actionIdentifier: "partnerStoppedLeave",
                identifier: "partnerStopped",
                perform: onLeave
            )
        case .failed:
            message(
                title: L10n.partnerErrorTitle,
                body: L10n.partnerErrorBody,
                action: L10n.partnerRetry,
                actionIdentifier: "partnerRetry",
                identifier: "partnerError",
                perform: { Task { await journey.refresh() } }
            )
        case .iCloudUnavailable:
            message(
                title: L10n.partnerICloudTitle,
                body: L10n.partnerICloudBody,
                action: L10n.partnerRetry,
                actionIdentifier: "partnerRetry",
                identifier: "partnerICloudUnavailable",
                perform: { Task { await journey.refresh() } }
            )
        }
    }

    @ViewBuilder
    private func journeyCards(_ snapshot: PartnerSnapshot) -> some View {
        Text(L10n.partnerTodayTitle(snapshot.displayName))
            .font(.luna(.screenTitle))
            .tracking(-0.56)
            .foregroundStyle(.luna(.textPrimary))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("partnerTodayTitle")
        if let timeline = PregnancyTimeline(dueDate: snapshot.dueDate, now: now) {
            WeekProgressCard(progress: PregnancyProgress(timeline: timeline))
            babySize(week: WeeklyContentLibrary.clampedWeek(timeline.week.weeks))
        }
        appointmentsCard(snapshot.appointments.filter { $0.date >= now })
        kicksCard(snapshot.kicks)
        Text(L10n.partnerUpdated(Formatting.relative(snapshot.updatedAt, now: now)))
            .font(.luna(.small))
            .foregroundStyle(.luna(.textSecondary))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
            .accessibilityIdentifier("partnerUpdated")
    }

    /// The size card with the same visibility rules as pregnancy Today; opens the week detail.
    @ViewBuilder
    private func babySize(week: Int) -> some View {
        switch library?.display(forWeek: week, visibility: BuildFlags.contentVisibility) {
        case .content(let content, let pendingReview)?:
            Button { detailWeek = WeekSelection(week: week) } label: {
                BabySizeCard(week: content, language: language, pendingReview: pendingReview)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("partnerBabySize")
        case .underReview?:
            Button { detailWeek = WeekSelection(week: week) } label: { UnderReviewCard() }
                .buttonStyle(.plain)
                .accessibilityIdentifier("partnerBabySize")
        case nil:
            EmptyView()
        }
    }

    private func appointmentsCard(_ appointments: [PartnerAppointment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.partnerAppointmentsTitle)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
            if appointments.isEmpty {
                Text(L10n.partnerAppointmentsNone)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
            }
            ForEach(Array(appointments.enumerated()), id: \.offset) { index, appointment in
                if index > 0 { LunaDivider() }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.luna(.pregOnSoft))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.luna(.pregSoft)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appointment.title)
                            .font(.luna(.bodyStrong))
                            .foregroundStyle(.luna(.textPrimary))
                        Text(Formatting.dateTime(appointment.date))
                            .font(.luna(.caption))
                            .foregroundStyle(.luna(.textSecondary))
                        if let location = appointment.location {
                            Text(location)
                                .font(.luna(.caption))
                                .foregroundStyle(.luna(.textSecondary))
                        }
                    }
                }
            }
        }
        .lunaCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("partnerAppointments")
    }

    private func kicksCard(_ kicks: PartnerKickSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.partnerKicksTitle)
                .font(.luna(.cardTitle))
                .foregroundStyle(.luna(.textPrimary))
            if let last = kicks.lastSession {
                Text(L10n.partnerKicksLast(
                    last.kicks,
                    Formatting.minutes(last.durationMinutes),
                    Formatting.relative(last.startedAt, now: now)
                ))
                .font(.luna(.body))
                .foregroundStyle(.luna(.textPrimary))
                Text(weekLine(kicks))
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
            } else {
                Text(L10n.partnerKicksNone)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .lunaCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("partnerKicks")
    }

    private func weekLine(_ kicks: PartnerKickSummary) -> String {
        guard let average = kicks.averageMinutesLast7Days, kicks.sessionsLast7Days > 0 else {
            return L10n.partnerKicksWeekNone
        }
        let minutes = Formatting.minutes(average)
        return kicks.sessionsLast7Days == 1
            ? L10n.partnerKicksWeekOne(minutes)
            : L10n.partnerKicksWeek(kicks.sessionsLast7Days, minutes)
    }

    private func message(
        title: String,
        body: String,
        action: String,
        actionIdentifier: String,
        identifier: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                Text(body)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.articleText))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            Button(action, action: perform)
                .buttonStyle(.pill(.dark))
                .accessibilityIdentifier(actionIdentifier)
        }
        .lunaCard()
        .padding(.top, 40)
    }
}
