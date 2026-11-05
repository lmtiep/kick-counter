import Foundation
import KickCore

/// The wording of a snapshot, from the app's own strings (`L10n`, in the language
/// chosen in the app). Same numbers as Today; dates in the app's locale.
enum WidgetFormat {
    /// "18/11" (vi) / "11/18" (en), like the app's cycle dates.
    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(AppLocale.locale))
    }

    static func weekday(_ date: Date) -> String {
        WeekdayLabel.short(for: date, calendar: AppLocale.calendar)
    }

    static func dayNumber(_ date: Date) -> String {
        date.formatted(.dateTime.day().locale(AppLocale.locale))
    }
}

struct WidgetCycleTexts {
    let eyebrow: String
    /// "Kỳ kinh" (or "Ra máu dự kiến"): the short name for Lock Screen lines.
    let shortName: String
    let figure: String
    /// The date of the next period; nil during a period and when late.
    let date: String?
    let cycleDay: String
    /// False during a period, when the headline already is the day.
    let showsCycleDay: Bool
    let inline: String
    let spoken: String

    init(_ cycle: WidgetSnapshot.CycleContent) {
        let bleed = cycle.expectsWithdrawalBleed ? L10n.cycleWithdrawalBleed : L10n.cycleNextPeriodTitle
        switch cycle.headline {
        case .onPeriod(let day):
            eyebrow = L10n.calendarLegendPeriod
            figure = L10n.cycleRingDay(day)
            date = nil
        case .late(let days):
            eyebrow = bleed
            figure = L10n.cycleRingLate(days)
            date = nil
        case .dueToday:
            eyebrow = bleed
            figure = L10n.commonToday
            date = WidgetFormat.date(cycle.nextPeriodDate)
        case .upcoming(let days):
            eyebrow = bleed
            figure = L10n.days(days)
            date = WidgetFormat.date(cycle.nextPeriodDate)
        }
        cycleDay = L10n.cycleDay(cycle.cycleDay)
        let short = cycle.expectsWithdrawalBleed ? L10n.cycleWithdrawalBleed : L10n.calendarLegendPeriod
        shortName = short
        showsCycleDay = { if case .onPeriod = cycle.headline { false } else { true } }()
        inline = ([short, figure, date].compactMap { $0 }).joined(separator: " · ")
        spoken = ([eyebrow, figure, date, cycleDay].compactMap { $0 }).joined(separator: ", ")
    }
}

struct WidgetFertilityTexts {
    let status: String
    let cycleDay: String
    let window: String
    let inline: String
    let spoken: String

    init(_ content: WidgetSnapshot.FertilityContent) {
        switch content.status {
        case .period: status = L10n.cycleStatus(.period(isPredicted: false))
        case .late: status = L10n.cycleStatusLate
        case .ovulationDay: status = L10n.widgetOvulationDay
        case .high: status = L10n.cycleStatus(.fertile)
        case .low: status = L10n.widgetOutsideWindow
        }
        cycleDay = L10n.cycleDay(content.cycleDay)
        window = L10n.cycleFertileTitle + ": "
            + L10n.cycleFertileRange(WidgetFormat.date(content.fertileWindow.lowerBound), WidgetFormat.date(content.fertileWindow.upperBound))
        inline = status
        spoken = [status, cycleDay, window].joined(separator: ", ")
    }
}

struct WidgetPregnancyTexts {
    let week: String
    /// "70 days to go", "9 days past your due date", "Your due date is today".
    let remaining: String
    /// The short form for tight places: "còn 70 ngày", "quá hạn 9 ngày", "hôm nay".
    let remainingShort: String
    let kicks: String?
    let inline: String
    let spoken: String
    let progress: Double

    init(_ content: WidgetSnapshot.PregnancyContent) {
        week = L10n.weekTitle(content.weeks)
        if content.daysPastDue > 0 {
            remaining = L10n.pregnancyPastDueTitle(content.daysPastDue)
            remainingShort = L10n.widgetPastDue(L10n.days(content.daysPastDue))
        } else if content.daysRemaining == 0 {
            remaining = L10n.pregnancyDueToday
            remainingShort = L10n.commonToday
        } else {
            remaining = L10n.widgetToGo(L10n.days(content.daysRemaining))
            remainingShort = remaining
        }
        switch content.kicks {
        case .hidden: kicks = nil
        case .notCounted: kicks = L10n.pregnancyKicksTodayNone
        case .counted(let count): kicks = L10n.widgetKicksToday(count)
        }
        inline = week + " · " + remainingShort
        spoken = [week, remaining, kicks].compactMap { $0 }.joined(separator: ", ")
        progress = min(1, Double(content.weeks * 7 + content.days) / Double(PregnancyTimeline.pregnancyLengthDays))
    }
}

enum WidgetSpeech {
    /// One sentence for VoiceOver.
    static func label(for snapshot: WidgetSnapshot) -> String {
        switch snapshot.content {
        case .needsSetup: L10n.widgetName + ", " + L10n.widgetSetup
        case .cycle(let cycle): WidgetCycleTexts(cycle).spoken
        case .fertility(let content): WidgetFertilityTexts(content).spoken
        case .pregnancy(let content): WidgetPregnancyTexts(content).spoken
        }
    }
}
