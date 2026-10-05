import KickCore
import SwiftUI

/// The 7 days under the header in pregnancy mode (spec §4.4): day numbers only,
/// today raised. In dark mode the raised white disc (`card`) barely stands out
/// from the background, so today also gets a `preg` ring there.
struct PregnancyWeekStrip: View {
    let today: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WeekStrip.days(endingAt: today, calendar: AppLocale.calendar)) { day in
                VStack(spacing: 6) {
                    Text(day.isToday ? L10n.stripToday : WeekdayLabel.short(for: day.date, calendar: AppLocale.calendar))
                        .font(.luna(.tiny))
                        .tracking(0.4)
                        .foregroundStyle(.luna(.textSecondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    DayCircle(number: Formatting.dayNumber(day.date), style: .pregnancyStrip, isToday: day.isToday, raisedToday: true)
                        .overlay {
                            if day.isToday && colorScheme == .dark {
                                Circle().strokeBorder(.luna(.preg), lineWidth: 1.5)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Formatting.spokenDay(day.date) + (day.isToday ? ", " + L10n.calendarA11yToday : ""))
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        // Seven fixed 40 pt days: larger weekday names would overlap (as CycleWeekStrip).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// The fetus in its 270 pt glow (README §4), floating; tap → week detail.
struct FetusHero: View {
    let week: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("Fetus")
                .resizable()
                .scaledToFit()
                .frame(height: 230)
                .shadow(color: Color.luna(.pregStrong).opacity(0.18), radius: 9, y: 10)
                .lunaFloat()
                .frame(width: 270, height: 270)
                .background(
                    // radial-gradient(circle, inner 0 %, outer 60 %, background 71 %) on a 270 pt square.
                    RadialGradient(
                        stops: [
                            .init(color: .luna(.fetusGlowInner), location: 0),
                            .init(color: .luna(.fetusGlowOuter), location: 0.6),
                            .init(color: .luna(.background), location: 0.71),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 135 * 2.0.squareRoot()
                    )
                    .clipShape(Circle())
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.pregnancyHeroA11y(week))
        .accessibilityIdentifier("fetusHeroButton")
    }
}

/// "24 weeks, 3 days", "Trimester 2 · 109 days to go" and the 8 pt bar with the
/// trimester dividers (spec §4.4).
struct WeekProgressCard: View {
    let progress: PregnancyProgress

    var body: some View {
        VStack(spacing: 4) {
            Text(L10n.pregnancyWeekLabel(progress.week))
                .font(.luna(.display))
                .tracking(-0.64)
                .foregroundStyle(.luna(.pregStrong))
                .multilineTextAlignment(.center)
            Text(subline)
                .font(.luna(.body))
                .foregroundStyle(.luna(.textSecondary))
                .multilineTextAlignment(.center)
            if progress.daysPastDue > 0 {
                Text(L10n.pregnancyPastDueBody)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.warningText))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            PregnancyProgressBar(fraction: progress.fraction)
                .padding(.top, 14)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weekProgressCard")
    }

    private var subline: String {
        let trimester = L10n.pregnancyTrimester(progress.trimester.rawValue)
        if progress.daysPastDue > 0 { return trimester + " · " + L10n.pregnancyPastDueTitle(progress.daysPastDue) }
        if progress.daysRemaining == 0 { return trimester + " · " + L10n.pregnancyDueToday }
        return L10n.pregnancySubline(progress.trimester.rawValue, progress.daysRemaining)
    }
}

struct PregnancyProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.luna(.track))
                Capsule().fill(.luna(.preg)).frame(width: proxy.size.width * fraction)
                ForEach(PregnancyProgress.trimesterMarks, id: \.self) { mark in
                    Rectangle()
                        .fill(.luna(.background))
                        .frame(width: 3, height: 14)
                        .offset(x: proxy.size.width * mark - 1.5)
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// The baby this week: fruit, size and Hadlock figures (spec §4.4).
struct BabySizeCard: View {
    let week: WeekContent
    let language: ContentLanguage
    let pendingReview: Bool
    var showsDisclosure = true

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(week.size.emoji)
                .font(.system(size: 44))
                .frame(width: 84, height: 84)
                .background(.luna(.surface), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.pregnancyBabySize(week.size.name(language)))
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                BabyMeasurements(week: week)
                if pendingReview {
                    PendingReviewBadge()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.luna(.chevron))
                    .accessibilityHidden(true)
            }
        }
        .lunaCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Crown–rump length (Hadlock 1992, weeks 7–13) and estimated weight (Hadlock
/// 1991, 50th percentile with the 10th–90th range, weeks 10–42) with their notes.
struct BabyMeasurements: View {
    let week: WeekContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let crl = week.crlMm {
                LabeledValue(
                    title: L10n.pregnancyBabyCRL,
                    value: L10n.pregnancyBabyCRLValue(Formatting.crownRumpLength(mm: crl)),
                    spokenValue: L10n.pregnancyBabyCRLValue(Formatting.crownRumpLength(mm: crl, spoken: true))
                )
            }
            if let weight = week.weightG, let p10 = week.weightP10G, let p90 = week.weightP90G {
                LabeledValue(
                    title: L10n.pregnancyBabyWeight,
                    value: L10n.pregnancyBabyWeightValue(
                        Formatting.weight(grams: weight),
                        Formatting.weightRange(p10, p90, unitOf: weight)
                    ),
                    spokenValue: L10n.pregnancyBabyWeightValueA11y(
                        Formatting.weight(grams: weight, spoken: true),
                        Formatting.weightRangeStart(p10, unitOf: weight),
                        Formatting.weightInUnit(p90, unitOf: weight, spoken: true)
                    )
                )
                VStack(alignment: .leading, spacing: 4) {
                    if week.weightBeyondStandard {
                        Text(L10n.pregnancyBabyStandardEnds(WeekContent.weightStandardLastWeek))
                    }
                    Text(L10n.pregnancyBabyEstimateNote)
                }
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct LabeledValue: View {
    let title: String
    let value: String
    /// What VoiceOver reads for `value` (units spelled out), if different.
    var spokenValue: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
            Text(value)
                .font(.luna(.bodyStrong))
                .monospacedDigit()
                .foregroundStyle(.luna(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(spokenValue ?? value)
        }
    }
}

struct PendingReviewBadge: View {
    var body: some View {
        Label(L10n.weekPendingReview, systemImage: "stethoscope")
            .font(.luna(.small))
            .foregroundStyle(.luna(.articleText))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.luna(.surfaceAlt)))
            .accessibilityIdentifier("pendingReviewBadge")
    }
}

/// "This week": two tips and a link to the week (spec §4.4).
struct WeekTipsCard: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.pregnancyTipsTitle)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.luna(.preg))
                        .accessibilityHidden(true)
                    Text(tip)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.articleText))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(L10n.pregnancySeeWeek)
                .font(.luna(.captionStrong))
                .foregroundStyle(.luna(.pregStrong))
        }
        .lunaCard(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

struct UnderReviewCard: View {
    var body: some View {
        Label(L10n.weekUnderReview, systemImage: "hourglass")
            .font(.luna(.body))
            .foregroundStyle(.luna(.textPrimary))
            .lunaCard(padding: 16)
            .accessibilityElement(children: .combine)
    }
}

/// The next check-up, or the next suggested milestone (spec §4.4).
struct NextAppointmentCard: View {
    let appointment: AppointmentRecord?
    let milestone: Milestone?
    let language: ContentLanguage

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.luna(.pregOnSoft))
                .frame(width: 44, height: 44)
                .background(Circle().fill(.luna(.pregSoft)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.pregnancyAppointmentTitle)
                    .lunaLabelStyle(.pregStrong)
                if let appointment {
                    Text(appointment.title)
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(Formatting.dateTime(appointment.date))
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                } else if let milestone {
                    Text(milestone.title.text(language))
                        .font(.luna(.cardTitleSmall))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(L10n.pregnancyAppointmentSuggested(milestone.fromWeek, milestone.toWeek))
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                    if !milestone.reviewed {
                        PendingReviewBadge()
                    }
                } else {
                    Text(L10n.pregnancyAppointmentNone)
                        .font(.luna(.caption))
                        .foregroundStyle(.luna(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .foregroundStyle(.luna(.chevron))
                .accessibilityHidden(true)
        }
        .lunaCard(padding: 16)
        .accessibilityElement(children: .combine)
    }
}
