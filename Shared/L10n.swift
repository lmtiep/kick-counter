import Foundation
import KickCore

/// Typed access to Localizable.xcstrings. Every user-facing string goes through here.
/// Strings come from the `.lproj` of the language chosen in the app (`AppLanguage`,
/// shared with the widget through the App Group), so a change applies at once.
enum L10n {
    private static func t(_ key: String) -> String {
        bundle().localizedString(forKey: key, value: nil, table: nil)
    }

    private static let lock = NSLock()
    /// Resolved `.lproj` bundles by language code, so a lookup does not hit the file system.
    nonisolated(unsafe) private static var bundles: [String: Bundle] = [:]

    private static func bundle() -> Bundle {
        let choice = AppLanguage.current
        let preferred = Locale.preferredLanguages
        let language = choice.resolved(preferredLanguages: preferred).rawValue
        lock.lock()
        defer { lock.unlock() }
        if let cached = bundles[language] { return cached }
        let bundle = choice.localizationBundle(in: .main, preferredLanguages: preferred)
        bundles[language] = bundle
        return bundle
    }

    static var pregnancyEmptyTitle: String { t("pregnancy.empty.title") }
    static var pregnancyEmptyBody: String { t("pregnancy.empty.body") }
    static var pregnancyEmptyAction: String { t("pregnancy.empty.action") }
    static var pregnancyInvalidTitle: String { t("pregnancy.invalid.title") }
    static var pregnancyInvalidBody: String { t("pregnancy.invalid.body") }
    static var pregnancyEditDate: String { t("pregnancy.editDate") }
    static func pregnancyTrimester(_ number: Int) -> String { String(format: t("pregnancy.trimester"), number) }
    static var pregnancyDueToday: String { t("pregnancy.dueToday") }
    static func pregnancyPastDueTitle(_ days: Int) -> String { String(format: t("pregnancy.pastDue.title"), days) }
    static var pregnancyPastDueBody: String { t("pregnancy.pastDue.body") }
    static func pregnancyBabySize(_ name: String) -> String { String(format: t("pregnancy.baby.size"), name) }
    static var pregnancyBabyCRL: String { t("pregnancy.baby.crl") }
    /// "About 53.5 mm" — calculated from Hadlock 1992's equation, not an exact measurement.
    static func pregnancyBabyCRLValue(_ length: String) -> String { String(format: t("pregnancy.baby.crlValue"), length) }
    static var pregnancyBabyWeight: String { t("pregnancy.baby.weight") }
    /// "About 331 g (typically 275–387 g)".
    static func pregnancyBabyWeightValue(_ typical: String, _ range: String) -> String {
        String(format: t("pregnancy.baby.weightValue"), typical, range)
    }
    /// VoiceOver: "About 331 grams, typically 275 to 387 grams".
    static func pregnancyBabyWeightValueA11y(_ typical: String, _ low: String, _ high: String) -> String {
        String(format: t("pregnancy.baby.weightValue.a11y"), typical, low, high)
    }
    /// Measurement error of an ultrasound weight estimate (roughly 10–15%). Not the same thing
    /// as the 10th–90th range on the card, which is the normal spread between babies (Hadlock 1991).
    static var pregnancyBabyEstimateNote: String { String(format: t("pregnancy.baby.estimateNote"), 10, 15) }
    static func pregnancyBabyStandardEnds(_ week: Int) -> String { String(format: t("pregnancy.baby.standardEnds"), week) }
    static var pregnancyTipsTitle: String { t("pregnancy.tips.title") }
    static var pregnancySeeWeek: String { t("pregnancy.seeWeek") }
    static var pregnancyAppointmentTitle: String { t("pregnancy.appointment.title") }
    static var pregnancyAppointmentNone: String { t("pregnancy.appointment.none") }
    static func pregnancyAppointmentSuggested(_ from: Int, _ to: Int) -> String {
        String(format: t("pregnancy.appointment.suggested"), from, to)
    }
    static var pregnancyKickCardBody: String { t("pregnancy.kickCard.body") }

    static func weekTitle(_ week: Int) -> String { String(format: t("week.title"), week) }
    static var weekBaby: String { t("week.baby") }
    static var weekMom: String { t("week.mom") }
    static var weekTips: String { t("week.tips") }
    static var weekWarnings: String { t("week.warnings") }
    static var weekUnderReview: String { t("week.underReview") }
    static var weekPendingReview: String { t("week.pendingReview") }

    static var counterTitle: String { t("counter.title") }
    static var counterTapHint: String { t("counter.tapHint") }
    static var counterUndo: String { t("counter.undo") }
    static var counterCancel: String { t("counter.cancel") }
    static var counterCancelConfirmTitle: String { t("counter.cancel.confirm.title") }
    static var counterCancelConfirmMessage: String { t("counter.cancel.confirm.message") }
    static var counterKeepCounting: String { t("counter.keepCounting") }
    static var counterA11yButton: String { t("counter.a11y.button") }
    static func counterA11yValue(_ count: Int, _ target: Int) -> String { String(format: t("counter.a11y.value"), count, target) }

    static var overdueTitle: String { t("overdue.title") }
    static var overdueBody: String { t("overdue.body") }

    static var completionTitle: String { t("completion.title") }
    static func completionDuration(_ text: String) -> String { String(format: t("completion.duration"), text) }
    static var completionExceeded: String { t("completion.exceeded") }
    static var completionDone: String { t("completion.done") }

    static var historyTitle: String { t("history.title") }
    static var historyChartMinutes: String { t("history.chart.minutes") }
    static var historyEmptyTitle: String { t("history.empty.title") }
    static var historyEmptyBody: String { t("history.empty.body") }
    static var historyStatusCancelled: String { t("history.status.cancelled") }
    static func historyRowCount(_ count: Int) -> String { String(format: t("history.row.count"), count) }
    static var historyDeleteConfirmTitle: String { t("history.delete.confirm.title") }

    static var commonDelete: String { t("common.delete") }
    static var commonCancel: String { t("common.cancel") }
    static var commonOK: String { t("common.ok") }
    static var commonSave: String { t("common.save") }

    static var settingsReminderSection: String { t("settings.reminder.section") }
    static var settingsReminderTime: String { t("settings.reminder.time") }
    static var settingsDueDate: String { t("settings.dueDate") }
    static var settingsPermissionsSection: String { t("settings.permissions.section") }
    static var settingsNotificationsDenied: String { t("settings.notifications.denied") }
    static var settingsLiveActivitiesOff: String { t("settings.liveActivities.off") }
    static var settingsOpenSettings: String { t("settings.openSettings") }
    static var settingsMedicalInfo: String { t("settings.medicalInfo") }
    static var settingsVersion: String { t("settings.version") }
    static var settingsPregnancySet: String { t("settings.pregnancy.set") }
    static var settingsPregnancyNotSet: String { t("settings.pregnancy.notSet") }
    static func settingsPregnancyFromLMP(_ date: String) -> String { String(format: t("settings.pregnancy.fromLMP"), date) }
    static var settingsPregnancyClear: String { t("settings.pregnancy.clear") }
    static var settingsPregnancyClearConfirm: String { t("settings.pregnancy.clear.confirm") }

    static var pregnancyDateTitle: String { t("pregnancyDate.title") }
    static var pregnancyDateSourceLabel: String { t("pregnancyDate.source") }
    static var pregnancyDateSourceDueDate: String { t("pregnancyDate.source.dueDate") }
    static var pregnancyDateSourceLMP: String { t("pregnancyDate.source.lmp") }
    static var pregnancyDateLMPLabel: String { t("pregnancyDate.lmp") }
    static var pregnancyDateHintDueDate: String { t("pregnancyDate.hint.dueDate") }
    static var pregnancyDateHintLMP: String { t("pregnancyDate.hint.lmp") }
    static func pregnancyDateEstimatedDue(_ date: String) -> String { String(format: t("pregnancyDate.estimatedDue"), date) }

    static var reminderTitle: String { t("reminder.title") }
    static var reminderBody: String { t("reminder.body") }

    static var appointmentsReminderTitle: String { t("appointments.reminder.title") }
    static var appointmentsReminderBody: String { t("appointments.reminder.body") }
    static var appointmentsTitle: String { t("appointments.title") }
    static var appointmentsUpcoming: String { t("appointments.upcoming") }
    static var appointmentsPast: String { t("appointments.past") }
    static var appointmentsEmpty: String { t("appointments.empty") }
    static var appointmentsAdd: String { t("appointments.add") }
    static var appointmentsEdit: String { t("appointments.edit") }
    static var appointmentsFieldTitle: String { t("appointments.field.title") }
    static var appointmentsFieldDate: String { t("appointments.field.date") }
    static var appointmentsFieldNote: String { t("appointments.field.note") }
    static var appointmentsMarkDone: String { t("appointments.markDone") }
    static var appointmentsStatusDone: String { t("appointments.status.done") }
    static var appointmentsMilestones: String { t("appointments.milestones") }
    static var appointmentsMilestoneAdd: String { t("appointments.milestone.add") }
    static var appointmentsNotificationsOff: String { t("appointments.notificationsOff") }
    static var appointmentsDeleteConfirmTitle: String { t("appointments.delete.confirm.title") }
    static func milestoneWeeks(_ from: Int, _ to: Int) -> String { String(format: t("milestone.weeks"), from, to) }

    static var medicalTitle: String { t("medical.title") }
    static var medicalBody: String { t("medical.body") }
    static var medicalSourcesTitle: String { t("medical.sources.title") }
    static var medicalSourcesNote: String { t("medical.sources.note") }

    static var onboarding3Title: String { t("onboarding.3.title") }
    static var onboarding3Body: String { t("onboarding.3.body") }
    static var onboardingLater: String { t("onboarding.later") }
    static var onboardingModeTitle: String { t("onboarding.mode.title") }
    static var modeTryingToConceive: String { t("mode.tryingToConceive") }
    static var modePregnant: String { t("mode.pregnant") }
    static func cycleSettingsCycleLength(_ days: Int) -> String { String(format: t("cycleSettings.cycleLength"), days) }
    static func cycleSettingsPeriodLength(_ days: Int) -> String { String(format: t("cycleSettings.periodLength"), days) }
    static var cycleSettingsHint: String { t("cycleSettings.hint") }
    static var settingsModeSection: String { t("settings.mode.section") }
    static var settingsCycleSection: String { t("settings.cycle.section") }
    static var settingsCycleReminders: String { t("settings.cycle.reminders") }
    static var settingsCycleRemindersHint: String { t("settings.cycle.remindersHint") }
    static var medicalTTCTitle: String { t("medical.ttc.title") }
    static var medicalTTCBody: String { t("medical.ttc.body") }

    static var errorSave: String { t("error.save") }
    static var errorLoad: String { t("error.load") }
    static var errorStoreTitle: String { t("error.store.title") }
    static var errorStoreBody: String { t("error.store.body") }

    static var laOverdue: String { t("la.overdue") }
    static var laCompleted: String { t("la.completed") }
    static var laAdd: String { t("la.add") }

    static var cycleEmptyTitle: String { t("cycle.empty.title") }
    static var cycleEmptyBody: String { t("cycle.empty.body") }
    static var cycleEmptyAction: String { t("cycle.empty.action") }
    static func cycleDay(_ day: Int) -> String { String(format: t("cycle.day"), day) }
    static func cycleStatus(_ status: CycleDayStatus) -> String {
        switch status {
        case .period: t("cycle.status.period")
        case .fertile: t("cycle.status.fertile")
        case .peak: t("cycle.status.peak")
        case .low: t("cycle.status.low")
        }
    }
    static var cycleNextPeriodTitle: String { t("cycle.nextPeriod.title") }
    /// "04/10 (còn 2 ngày)" / "10/04 · days to go: 2".
    static func cycleNextPeriodIn(_ date: String, _ days: Int) -> String { String(format: t("cycle.nextPeriod.in"), date, days) }
    static func cycleNextPeriodToday(_ date: String) -> String { String(format: t("cycle.nextPeriod.today"), date) }
    static func cycleNextPeriodTomorrow(_ date: String) -> String { String(format: t("cycle.nextPeriod.tomorrow"), date) }
    static func cycleNextPeriodLate(_ days: Int) -> String { String(format: t("cycle.nextPeriod.late"), days) }
    static var cycleFertileTitle: String { t("cycle.fertile.title") }
    static func cycleFertileRange(_ start: String, _ end: String) -> String { String(format: t("cycle.fertile.range"), start, end) }
    static func cycleOvulation(_ date: String) -> String { String(format: t("cycle.ovulation"), date) }
    static func cycleOvulationConfirmed(_ date: String) -> String { String(format: t("cycle.ovulation.confirmed"), date) }
    static var cycleOvulationLH: String { t("cycle.ovulation.lh") }
    static var cycleLowConfidenceIrregular: String { t("cycle.lowConfidence.irregular") }
    static var cycleLowConfidenceFewCycles: String { t("cycle.lowConfidence.fewCycles") }
    static func cycleLateTitle(_ days: Int) -> String { String(format: t("cycle.late.title"), days) }
    static var cycleLateBody: String { t("cycle.late.body") }
    static var cycleIrregularTitle: String { t("cycle.irregular.title") }
    static var cycleIrregularBody: String { t("cycle.irregular.body") }
    static func cycleLongPeriodTitle(_ days: Int) -> String { String(format: t("cycle.longPeriod.title"), days) }
    static var cycleLongPeriodBody: String { t("cycle.longPeriod.body") }
    static var cycleStartPeriod: String { t("cycle.startPeriod") }
    static var cycleEndPeriod: String { t("cycle.endPeriod") }
    static var cycleImPregnant: String { t("cycle.imPregnant") }
    static var cycleStatusLate: String { t("cycle.status.late") }
    static var imPregnantTitle: String { t("imPregnant.title") }
    static var imPregnantKeepsData: String { t("imPregnant.keepsData") }
    static var cycleDisclaimer: String { t("cycle.disclaimer") }
    static var cycleNotificationsOff: String { t("cycle.notificationsOff") }
    static var cycleReminderFertileTitle: String { t("cycle.reminder.fertile.title") }
    static var cycleReminderFertileBody: String { t("cycle.reminder.fertile.body") }
    static var cycleReminderPeriodTitle: String { t("cycle.reminder.period.title") }
    static var cycleReminderPeriodBody: String { t("cycle.reminder.period.body") }
    static var cycleReminderLateTitle: String { t("cycle.reminder.late.title") }
    static var cycleReminderLateBody: String { t("cycle.reminder.late.body") }
    static func cycleFailure(_ failure: CycleFailure) -> String {
        switch failure {
        case .loadFailed: errorLoad
        case .saveFailed: errorSave
        case .futureDate: t("cycle.error.future")
        case .endBeforeStart: t("cycle.error.endBeforeStart")
        case .overlapsExistingPeriod: t("cycle.error.overlap")
        case .invalidTemperature: t("cycle.error.temperature")
        }
    }

    static var lastPeriodTitle: String { t("lastPeriod.title") }
    static var lastPeriodDate: String { t("lastPeriod.date") }
    static var lastPeriodHint: String { t("lastPeriod.hint") }

    static var dayLogPeriodSection: String { t("dayLog.period") }
    static var dayLogPeriodStart: String { t("dayLog.period.start") }
    static var dayLogPeriodEnd: String { t("dayLog.period.end") }
    static var dayLogPeriodDelete: String { t("dayLog.period.delete") }
    static var dayLogPeriodDeleteConfirm: String { t("dayLog.period.delete.confirm") }
    static func dayLogPeriodSince(_ date: String) -> String { String(format: t("dayLog.period.since"), date) }
    static func dayLogPeriodRange(_ start: String, _ end: String) -> String { String(format: t("dayLog.period.range"), start, end) }
    static var dayLogLH: String { t("dayLog.lh") }
    static var dayLogLHNone: String { t("dayLog.lh.none") }
    static var dayLogLHNegative: String { t("dayLog.lh.negative") }
    static var dayLogLHPositive: String { t("dayLog.lh.positive") }
    static var dayLogBBT: String { t("dayLog.bbt") }
    static var dayLogBBTPlaceholder: String { t("dayLog.bbt.placeholder") }
    static var dayLogBBTHint: String { t("dayLog.bbt.hint") }
    static var dayLogMucus: String { t("dayLog.mucus") }
    static var dayLogMucusNone: String { t("dayLog.mucus.none") }
    static func mucus(_ value: CervicalMucus) -> String {
        switch value {
        case .dry: t("dayLog.mucus.dry")
        case .sticky: t("dayLog.mucus.sticky")
        case .creamy: t("dayLog.mucus.creamy")
        case .eggWhite: t("dayLog.mucus.eggWhite")
        }
    }
    static var dayLogNote: String { t("dayLog.note") }

    static var tabCalendar: String { t("tab.calendar") }

    static var calendarTitle: String { t("calendar.title") }
    static var calendarPrevious: String { t("calendar.previous") }
    static var calendarNext: String { t("calendar.next") }
    static var calendarEmptyHint: String { t("calendar.emptyHint") }
    static var calendarLegendPeriod: String { t("calendar.legend.period") }
    static var calendarLegendPredicted: String { t("calendar.legend.predicted") }
    static var calendarLegendFertile: String { t("calendar.legend.fertile") }
    static var calendarLegendPeak: String { t("calendar.legend.peak") }
    static var calendarLegendLogged: String { t("calendar.legend.logged") }
    static var calendarA11yToday: String { t("calendar.a11y.today") }
    static var calendarA11yPeriod: String { t("calendar.a11y.period") }
    static var calendarA11yPredicted: String { t("calendar.a11y.predicted") }
    static var calendarA11yFertile: String { t("calendar.a11y.fertile") }
    static var calendarA11yPeak: String { t("calendar.a11y.peak") }
    static var calendarA11yLHPositive: String { t("calendar.a11y.lhPositive") }
    static var calendarA11yLHNegative: String { t("calendar.a11y.lhNegative") }
    static func calendarA11yTemperature(_ value: String) -> String { String(format: t("calendar.a11y.temperature"), value) }
    static var calendarA11yNote: String { t("calendar.a11y.note") }

    // MARK: - Phase 4: navigation and language

    static var tabToday: String { t("tab.today") }
    static var tabKicks: String { t("tab.kicks") }
    static var tabProfile: String { t("tab.profile") }
    static var profileTitle: String { t("profile.title") }
    static var languageTitle: String { t("language.title") }
    static var languageSystem: String { t("language.system") }
    static var languageVietnamese: String { t("language.vi") }
    static var languageEnglish: String { t("language.en") }
    /// "22 min" / "22 phút".
    static func minutes(_ value: Int) -> String { String(format: t("common.minutes"), value) }
    /// "28 days" / "28 ngày" ("1 day").
    static func days(_ value: Int) -> String {
        value == 1 ? t("common.oneDay") : String(format: t("common.days"), value)
    }

    // MARK: - Phase 4: onboarding

    static var onboardingSkip: String { t("onboarding.skip") }
    static var onboardingContinue: String { t("onboarding.continue") }
    static var onboardingStart: String { t("onboarding.start") }
    /// VoiceOver for the progress dots: "Step 2 of 3".
    static func onboardingStep(_ step: Int, _ count: Int) -> String { String(format: t("onboarding.step"), step, count) }
    static var onboardingWelcomeTitle: String { t("onboarding.welcome.title") }
    static var onboardingWelcomeBody: String { t("onboarding.welcome.body") }
    static var onboardingGoalCycle: String { t("onboarding.goal.cycle") }
    static var onboardingGoalCycleDetail: String { t("onboarding.goal.cycle.detail") }
    static var onboardingGoalPregnant: String { t("onboarding.goal.pregnant") }
    static var onboardingGoalPregnantDetail: String { t("onboarding.goal.pregnant.detail") }
    static var onboardingOtherDay: String { t("onboarding.otherDay") }
    static func onboardingOtherDayValue(_ date: String) -> String { String(format: t("onboarding.otherDay.value"), date) }
    static var onboardingCycleShorter: String { t("onboarding.cycle.shorter") }
    static var onboardingCycleLonger: String { t("onboarding.cycle.longer") }
    static var onboardingDueTitle: String { t("onboarding.due.title") }
    static var onboardingDueEarlier: String { t("onboarding.due.earlier") }
    static var onboardingDueLater: String { t("onboarding.due.later") }
    static var onboardingDueFromLMP: String { t("onboarding.due.fromLMP") }
    static var cycleLengthTitle: String { t("cycleSettings.cycleLength.title") }
    /// "24 weeks, 3 days" / "24 tuần, 3 ngày".
    static func pregnancyWeekLabel(_ week: GestationalWeek) -> String {
        week.days == 1
            ? String(format: t("pregnancy.weekLabel.oneDay"), week.weeks)
            : String(format: t("pregnancy.weekLabel"), week.weeks, week.days)
    }

    // MARK: - Phase 4: cycle Today

    /// Today in the 7-day strip: "TODAY" / "NAY".
    static var stripToday: String { t("strip.today") }
    static var commonToday: String { t("common.today") }
    static var cycleComingUp: String { t("cycle.comingUp") }
    static var cycleOvulationTitle: String { t("cycle.ovulation.title") }
    static var cycleOvulationConfirmedNote: String { t("cycle.ovulation.confirmedNote") }
    static var cycleStatsPattern: String { t("cycle.stats.pattern") }
    static var cycleStatsRegular: String { t("cycle.stats.regular") }
    static var cycleStatsIrregular: String { t("cycle.stats.irregular") }
    static var cycleLogTitle: String { t("cycle.log.title") }
    static var cycleLogPrompt: String { t("cycle.log.prompt") }
    static func cycleLogLH(_ result: String) -> String { String(format: t("cycle.log.lh"), result) }
    static func cycleRingDay(_ day: Int) -> String { String(format: t("cycle.ring.day"), day) }
    static func cycleRingLate(_ days: Int) -> String {
        days == 1 ? t("cycle.ring.lateOne") : String(format: t("cycle.ring.late"), days)
    }
    static var cycleRingStart: String { t("cycle.ring.start") }
    static var cycleRingEnd: String { t("cycle.ring.end") }
    static var cycleRingUndo: String { t("cycle.ring.undo") }
    static var cycleRingUndoA11y: String { t("cycle.ring.undo.a11y") }
    static var cycleToastPeriodStarted: String { t("cycle.toast.started") }
    static var cycleToastPeriodEnded: String { t("cycle.toast.ended") }
    static var cycleToastPeriodUndone: String { t("cycle.toast.undone") }
    /// "Day 12 · High chance of conceiving".
    static func cyclePhase(_ day: Int, _ status: String) -> String { String(format: t("cycle.phase"), day, status) }
    static var cycleMaybePregnantTitle: String { t("cycle.maybePregnant.title") }
    static var cycleMaybePregnantBody: String { t("cycle.maybePregnant.body") }

    // MARK: - Phase 4: calendar

    static var calendarLog: String { t("calendar.log") }

    // MARK: - Phase 4: pregnancy Today

    /// "Trimester 2 · 109 days to go".
    static func pregnancySubline(_ trimester: Int, _ daysLeft: Int) -> String {
        String(format: t("pregnancy.subline"), trimester, daysLeft)
    }
    static func pregnancyHeroA11y(_ week: Int) -> String { String(format: t("pregnancy.hero.a11y"), week) }
    static var pregnancyShortcutKicks: String { t("pregnancy.shortcut.kicks") }
    static var pregnancyShortcutWeek: String { t("pregnancy.shortcut.week") }
    static var pregnancyKicksTodayTitle: String { t("pregnancy.kicksToday.title") }
    static var pregnancyKicksTodayNone: String { t("pregnancy.kicksToday.none") }
    /// "10 movements in 18 min".
    static func pregnancyKicksTodayDone(_ count: Int, _ duration: String) -> String {
        String(format: t("pregnancy.kicksToday.done"), count, duration)
    }
    /// "At 20:05 · 7-day average 22 min".
    static func pregnancyKicksTodayDoneDetail(_ time: String, _ average: String) -> String {
        String(format: t("pregnancy.kicksToday.doneDetail"), time, average)
    }
    static func pregnancyKicksTodayReminder(_ time: String) -> String { String(format: t("pregnancy.kicksToday.reminder"), time) }
    static func pregnancyKicksTodayAverage(_ average: String) -> String { String(format: t("pregnancy.kicksToday.average"), average) }
    static var pregnancyKicksTodayCount: String { t("pregnancy.kicksToday.count") }
    static var pregnancyKicksTodayView: String { t("pregnancy.kicksToday.view") }

    // MARK: - Phase 4: week detail

    static func weekChip(_ week: Int) -> String { String(format: t("week.chip"), week) }
    static func weekHeadline(_ week: Int) -> String { String(format: t("week.headline"), week) }
    static var weekReviewer: String { t("week.reviewer") }
    static var weekReviewed: String { t("week.reviewed") }
    static func weekSizeLine(_ fruit: String) -> String { String(format: t("week.sizeLine"), fruit) }
    static func weekTypicalRange(_ range: String) -> String { String(format: t("week.typicalRange"), range) }
    static var commonClose: String { t("common.close") }
    /// "About 600 g": the Hadlock 50th percentile is an estimate, not a measurement.
    static func weekAbout(_ value: String) -> String { String(format: t("week.about"), value) }

    // MARK: - Phase 4: kicks

    /// "Week 24 · count to 10 movements".
    static func counterSubtitle(_ week: Int, _ target: Int) -> String { String(format: t("counter.subtitle"), week, target) }
    static func counterSubtitleNoWeek(_ target: Int) -> String { String(format: t("counter.subtitle.noWeek"), target) }
    static var counterSettings: String { t("counter.settings") }
    static func counterReminderPill(_ time: String) -> String { String(format: t("counter.reminderPill"), time) }
    static var counterReminderOff: String { t("counter.reminderOff") }
    static var counterIdleTitle: String { t("counter.idle.title") }
    static var counterIdleBody: String { t("counter.idle.body") }
    static func counterOfTarget(_ target: Int) -> String { String(format: t("counter.ofTarget"), target) }
    static var counterDoneLabel: String { t("counter.doneLabel") }
    static func counterDoneDetail(_ duration: String) -> String { String(format: t("counter.doneDetail"), duration) }
    /// Vietnamese emergency number; the button is only shown in Vietnamese.
    static var counterCall115: String { t("counter.call115") }
    static var kicksLastSevenDays: String { t("kicks.last7") }
    static var kicksCardiffTitle: String { t("kicks.cardiff.title") }
    static var kicksCardiffBody: String { t("kicks.cardiff.body") }
    static var kickSettingsTitle: String { t("kickSettings.title") }
    static var kickSettingsReminderDetail: String { t("kickSettings.reminder.detail") }
    static var kickSettingsHaptics: String { t("kickSettings.haptics") }
    static var kickSettingsHapticsDetail: String { t("kickSettings.haptics.detail") }
    static var kickSettingsGoal: String { t("kickSettings.goal") }
    /// Today's bar in the charts: "Today" / "Nay".
    static var historyToday: String { t("history.today") }
    /// Under a minute on the done dial, instead of "0 min".
    static var underOneMinute: String { t("common.underOneMinute") }

    // MARK: - Phase 4: history

    static var historyHeading: String { t("history.heading") }
    static var historyRangeWeek: String { t("history.range.week") }
    static var historyRangeMonth: String { t("history.range.month") }
    static var historyAverage: String { t("history.average") }
    static var historySessions: String { t("history.sessions") }
    static var historyThisWeek: String { t("history.week.this") }
    static var historyLastWeek: String { t("history.week.last") }
    static func historyWeeksAgo(_ weeks: Int) -> String { String(format: t("history.week.ago"), weeks) }
    /// The chart's x axis, for VoiceOver.
    static var historyChartPeriod: String { t("history.chart.period") }
    /// A bar's value: "19′".
    static func historyBarMinutes(_ minutes: Int) -> String { String(format: t("history.bar.minutes"), minutes) }
    static var historyNoSession: String { t("history.noSession") }
    static var historyGuideTitle: String { t("history.guide.title") }
    static var historyGuideBody: String { t("history.guide.body") }

    // MARK: - Phase 4: profile

    static var appName: String { t("app.name") }
    static var profileModePregnant: String { t("profile.mode.pregnant") }
    static var profileModeCycle: String { t("profile.mode.cycle") }
    static var profileEndPregnancy: String { t("profile.endPregnancy") }
    static var profileSwitchToPregnant: String { t("profile.switchToPregnant") }
    static var profileKickReminder: String { t("profile.kickReminder") }
    static var profileReminderOff: String { t("profile.reminderOff") }
    static var profileReplayOnboarding: String { t("profile.replayOnboarding") }
    static var profileFontLicense: String { t("profile.fontLicense") }
    static var endPregnancyTitle: String { t("endPregnancy.title") }
    static var endPregnancyBody: String { t("endPregnancy.body") }
    static var endPregnancyConfirm: String { t("endPregnancy.confirm") }
    static var commonNotNow: String { t("common.notNow") }

    // MARK: - Phase 4: sheets

    /// Day log title for today: "Today, Oct 4".
    static func dayLogTitleToday(_ date: String) -> String { String(format: t("dayLog.title.today"), date) }
    static var imPregnantSwitchBody: String { t("imPregnant.switchBody") }
    static var imPregnantByDue: String { t("imPregnant.byDue") }
    static var imPregnantByLMP: String { t("imPregnant.byLMP") }
    static var imPregnantEarlier: String { t("imPregnant.earlier") }
    static var imPregnantLater: String { t("imPregnant.later") }
    /// "Today: 4 weeks, 4 days · due June 7, 2027".
    static func imPregnantResult(_ weeks: String, _ due: String) -> String {
        String(format: t("imPregnant.result"), weeks, due)
    }
    static var imPregnantConfirm: String { t("imPregnant.confirm") }

    // MARK: - Phase 5: symptoms

    static var symptomFlowTitle: String { t("symptom.flow.title") }
    static var symptomMoodTitle: String { t("symptom.mood.title") }
    static var symptomTitle: String { t("symptom.title") }
    static var dayLogSignals: String { t("dayLog.signals") }
    /// "Flow: Light" in a day's summary.
    static func symptomSummaryFlow(_ flow: String) -> String { String(format: t("symptom.summary.flow"), flow) }
    static func flow(_ value: MenstrualFlow) -> String {
        switch value {
        case .noFlow: t("symptom.flow.none")
        case .light: t("symptom.flow.light")
        case .medium: t("symptom.flow.medium")
        case .heavy: t("symptom.flow.heavy")
        }
    }
    static func mood(_ value: Mood) -> String {
        switch value {
        case .happy: t("symptom.mood.happy")
        case .calm: t("symptom.mood.calm")
        case .sensitive: t("symptom.mood.sensitive")
        case .anxious: t("symptom.mood.anxious")
        case .tired: t("symptom.mood.tired")
        }
    }
    static func symptom(_ value: Symptom) -> String {
        switch value {
        case .cramps: t("symptom.kind.cramps")
        case .headache: t("symptom.kind.headache")
        case .tenderBreasts: t("symptom.kind.tenderBreasts")
        case .acne: t("symptom.kind.acne")
        case .bloating: t("symptom.kind.bloating")
        case .cravings: t("symptom.kind.cravings")
        case .nausea: t("symptom.kind.nausea")
        case .heartburn: t("symptom.kind.heartburn")
        case .swollenFeet: t("symptom.kind.swollenFeet")
        case .backPain: t("symptom.kind.backPain")
        case .legCramps: t("symptom.kind.legCramps")
        case .insomnia: t("symptom.kind.insomnia")
        case .contractions: t("symptom.kind.contractions")
        }
    }

    // MARK: - Phase 5: pregnancy symptoms

    static var pregnancyShortcutSymptoms: String { t("pregnancy.shortcut.symptoms") }
    static var symptomsListTitle: String { t("symptoms.list.title") }
    static var symptomsListEmpty: String { t("symptoms.list.empty") }
    static var symptomsTodayEmpty: String { t("symptoms.today.empty") }
    static var symptomsLogToday: String { t("symptoms.logToday") }
    static var symptomsEdit: String { t("symptoms.edit") }
    static var symptomsDeleteConfirm: String { t("symptoms.delete.confirm") }
    /// VoiceOver, on a day with contractions or swollen feet.
    static var symptomsRowWarning: String { t("symptoms.row.warning") }
    static var symptomSafetyTitle: String { t("symptom.safety.title") }
    static var symptomSafetyContractions: String { t("symptom.safety.contractions") }
    static var symptomSafetySwelling: String { t("symptom.safety.swelling") }
    static var symptomSafetyNote: String { t("symptom.safety.note") }
    static var symptomSafetyAction: String { t("symptom.safety.action") }

    // MARK: - Phase 5: weight

    static var commonDone: String { t("common.done") }
    static var pregnancyShortcutWeight: String { t("pregnancy.shortcut.weight") }
    static var weightTitle: String { t("weight.title") }
    static var weightGained: String { t("weight.gained") }
    static var weightSince: String { t("weight.since") }
    /// "BMI 20.3 · Normal".
    static func weightBMI(_ bmi: String, _ category: String) -> String { String(format: t("weight.bmi"), bmi, category) }
    static func weightCategory(_ category: BMICategory) -> String {
        switch category {
        case .under: t("weight.category.under")
        case .normal: t("weight.category.normal")
        case .over: t("weight.category.over")
        case .obese: t("weight.category.obese")
        }
    }
    static func weightStatus(_ status: WeightStatus) -> String {
        switch status {
        case .below: t("weight.status.below")
        case .inRange: t("weight.status.inRange")
        case .above: t("weight.status.above")
        }
    }
    static var weightStatusTalk: String { t("weight.status.talk") }
    static var weightNoHeight: String { t("weight.noHeight") }
    static var weightChartWeek: String { t("weight.chart.week") }
    static var weightChartGain: String { t("weight.chart.gain") }
    static var weightChartRange: String { t("weight.chart.range") }
    static var weightChartYou: String { t("weight.chart.you") }
    /// VoiceOver for a chart dot: "Week 24: gained 6.0 kilograms".
    static func weightChartGainPoint(_ week: Int, _ kg: String) -> String { String(format: t("weight.chart.point.gain"), week, kg) }
    static func weightChartLossPoint(_ week: Int, _ kg: String) -> String { String(format: t("weight.chart.point.loss"), week, kg) }
    static var weightAdd: String { t("weight.add") }
    static var weightAddDate: String { t("weight.add.date") }
    static var weightAddKg: String { t("weight.add.kg") }
    static var weightLess: String { t("weight.less") }
    static var weightMore: String { t("weight.more") }
    static var weightInvalidKg: String { t("weight.invalid.kg") }
    static var weightInvalidHeight: String { t("weight.invalid.height") }
    static var weightSaved: String { t("weight.saved") }
    static var weightHistory: String { t("weight.history") }
    static var weightHistoryEmpty: String { t("weight.history.empty") }
    static var weightHistoryOutside: String { t("weight.history.outside") }
    static var weightDeleteConfirm: String { t("weight.delete.confirm") }
    static var weightSetupTitle: String { t("weight.setup.title") }
    static var weightSetupBody: String { t("weight.setup.body") }
    static var weightSetupPreWeight: String { t("weight.setup.preWeight") }
    static var weightSetupHeight: String { t("weight.setup.height") }
    static var weightCardTitle: String { t("weight.card.title") }
    static var maternalTitle: String { t("maternal.title") }
    static var profileMaternal: String { t("profile.maternal") }
    static var profileMaternalNotSet: String { t("profile.maternal.notSet") }
    static func weightFailure(_ failure: WeightFailure) -> String {
        switch failure {
        case .loadFailed: t("weight.failure.load")
        case .saveFailed: t("weight.failure.save")
        case .futureDate: t("weight.failure.future")
        case .outOfRange: t("weight.invalid.kg")
        case .invalidHeight: t("weight.invalid.height")
        }
    }
}
