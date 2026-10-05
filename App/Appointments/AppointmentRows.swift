import KickCore
import SwiftUI

struct AppointmentRow: View {
    let record: AppointmentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(record.title)
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                if record.isDone {
                    Label(L10n.appointmentsStatusDone, systemImage: "checkmark.circle.fill")
                        .font(.luna(.label))
                        .foregroundStyle(.luna(.tealStrong))
                }
            }
            Text(Formatting.dateTime(record.date))
                .font(.luna(.caption))
                .foregroundStyle(.luna(.textSecondary))
            if !record.note.isEmpty {
                Text(record.note)
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    let language: ContentLanguage
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title.text(language))
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.textPrimary))
                Text(L10n.milestoneWeeks(milestone.fromWeek, milestone.toWeek))
                    .font(.luna(.label))
                    .foregroundStyle(.luna(.pregStrong))
                Text(milestone.detail.text(language))
                    .font(.luna(.small))
                    .foregroundStyle(.luna(.textSecondary))
                if !milestone.reviewed {
                    PendingReviewBadge()
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Label(L10n.appointmentsMilestoneAdd, systemImage: "calendar.badge.plus")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.luna(.pregOnSoft))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.luna(.pregSoft)))
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("addMilestoneButton")
            // The icon-only label alone is the same for every milestone; include
            // the milestone's own title so VoiceOver announces which one this is.
            .accessibilityLabel("\(L10n.appointmentsMilestoneAdd), \(milestone.title.text(language))")
        }
    }
}
