import KickCore
import StoreKit
import SwiftUI

/// Asks for an App Store rating at a good moment, through Apple's own prompt and nothing
/// of ours around it. When it may ask is `ReviewPromptPolicy`; this only gathers what the
/// policy needs and records the request once it was really made. Never in UI tests.
@MainActor
enum ReviewPrompter {
    /// Marks today as a day of use. Call when the app opens or comes to the foreground.
    static func recordUse() {
        guard !AppEnvironment.isUITesting else { return }
        let defaults = AppGroup.defaults
        let state = ReviewPromptPolicy.recordingUse(
            ReviewPromptStore.load(from: defaults), now: AppClock.now(), calendar: AppLocale.calendar
        )
        ReviewPromptStore.save(state, to: defaults)
    }

    /// Requests the rating prompt if `moment` allows it. `requestReview` is the view's
    /// `@Environment(\.requestReview)`.
    static func moment(
        _ moment: ReviewMoment,
        kicks: KickCoordinator,
        contractions: ContractionCoordinator,
        requestReview: RequestReviewAction
    ) {
        guard !AppEnvironment.isUITesting else { return }
        let defaults = AppGroup.defaults
        let now = AppClock.now()
        let calendar = AppLocale.calendar
        let context = ReviewPromptContext(
            isOnboarding: !defaults.bool(forKey: SettingsKey.hasCompletedOnboarding),
            recentContractionUse: ReviewPromptPolicy.hadRecentContractionUse(contractions.contractions, now: now),
            alertShowing: kicks.isOverdue(at: now) || contractions.stats(week: nil, at: now).alert != .none
        )
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let state = ReviewPromptStore.load(from: defaults)
        guard ReviewPromptPolicy.shouldAsk(
            moment: moment, context: context, state: state, appVersion: version, now: now, calendar: calendar
        ) else { return }
        // Recorded only here, where the request is actually made.
        ReviewPromptStore.save(ReviewPromptPolicy.recordingAsk(state, appVersion: version, now: now), to: defaults)
        requestReview()
    }
}
