import ActivityKit
import AppIntents
import KickCore
import SwiftUI
import WidgetKit

/// The contraction timer on the Lock Screen and in the Dynamic Island (phase 20
/// spec §4.4): "Đang gò" with the running time, or "Đang nghỉ" with a count-up
/// since the last contraction ended ("Nghỉ 3:12"), the count and the last
/// interval, and a Start/Stop button (`ToggleContractionIntent`) that works
/// without opening the app. While resting, "Kết thúc"
/// (`EndContractionTrackingIntent`) ends the tracking session from there too. Laid out like `KickLiveActivityWidget`, in
/// the pregnancy Luna tokens. When the timer screen's alert is on, a short
/// urgent line shows it to a mother who only looks at the Lock Screen.
///
/// The running time stops at `ContractionRules.maxDuration` (the app closes a
/// longer one there), the resting count-up at `ContractionRules.episodeGap`,
/// and a stale activity (2 hours without a new contraction) shows the resting
/// state with the count instead of the count-up.
struct ContractionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ContractionActivityAttributes.self) { context in
            ContractionLockScreenView(state: context.shownState)
                .padding(16)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusLabel(state: context.shownState, scheme: .dark)
                        .font(.subheadline.weight(.semibold))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(L10n.contractionHistoryCount(context.shownState.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.luna(.textPrimary, .dark))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            MainFigure(state: context.shownState, scheme: .dark)
                                .font(.title.bold())
                            DetailLine(state: context.shownState, showsCount: false)
                                .font(.caption)
                                .foregroundStyle(Color.luna(.textSecondary, .dark))
                            AlertLine(alert: context.shownState.alert, scheme: .dark)
                                .font(.caption.weight(.semibold))
                        }
                        Spacer(minLength: 8)
                        Buttons(state: context.shownState, scheme: .dark, compact: true)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                CompactIcon(state: context.shownState)
            } compactTrailing: {
                if let since = context.shownState.runningSince {
                    Text(timerInterval: ContractionClockRange.running(since), countsDown: false)
                        .monospacedDigit()
                        .frame(maxWidth: 52)
                        .foregroundStyle(Color.luna(.pregStrong, .dark))
                } else {
                    Text(context.shownState.count, format: .number)
                        .foregroundStyle(Color.luna(.pregStrong, .dark))
                }
            } minimal: {
                CompactIcon(state: context.shownState)
            }
        }
    }
}

private struct ContractionLockScreenView: View {
    let state: ContractionActivityAttributes.ContentState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                StatusLabel(state: state, scheme: scheme)
                    .font(.subheadline.weight(.semibold))
                MainFigure(state: state, scheme: scheme)
                    .font(.largeTitle.bold())
                // The count moves here when the main figure is a clock.
                DetailLine(state: state, showsCount: state.runningSince != nil || state.restingSince != nil)
                    .font(.subheadline)
                    .foregroundStyle(Color.luna(.textSecondary, scheme))
                AlertLine(alert: state.alert, scheme: scheme)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 8)
            Buttons(state: state, scheme: scheme, compact: false)
        }
    }
}

/// "Đang gò" / "Đang nghỉ" with the stopwatch.
private struct StatusLabel: View {
    let state: ContractionActivityAttributes.ContentState
    let scheme: ColorScheme

    var body: some View {
        Label(
            state.runningSince == nil ? L10n.contractionResting : L10n.contractionRunning,
            systemImage: state.runningSince == nil ? "stopwatch" : "stopwatch.fill"
        )
        .foregroundStyle(Color.luna(.pregText, scheme))
    }
}

/// The running time, the count-up since the last contraction ended while
/// resting ("Nghỉ 3:12"), or the episode's count (a stale or older state).
private struct MainFigure: View {
    let state: ContractionActivityAttributes.ContentState
    let scheme: ColorScheme

    var body: some View {
        Group {
            if let since = state.runningSince {
                Text(timerInterval: ContractionClockRange.running(since), countsDown: false)
                    .monospacedDigit()
            } else if let since = state.restingSince {
                RestingClock(since: since)
            } else {
                Text(L10n.contractionHistoryCount(state.count))
            }
        }
        .foregroundStyle(Color.luna(.pregStrong, scheme))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// "Nghỉ 3:12": the localized "Nghỉ %@" around a live count-up, so the words
/// stay in the catalogue's order.
private struct RestingClock: View {
    let since: Date

    var body: some View {
        let parts = L10n.laContractionRestingFor.components(separatedBy: "%@")
        let prefix = parts.first ?? ""
        let suffix = parts.count > 1 ? parts[1] : ""
        Text(prefix) + Text(timerInterval: ContractionClockRange.resting(since), countsDown: false).monospacedDigit() + Text(suffix)
    }
}

/// "3 cơn · Cách nhau 5:00 · Dài 1:00": what is known, in that order.
private struct DetailLine: View {
    let state: ContractionActivityAttributes.ContentState
    let showsCount: Bool

    var body: some View {
        let parts = [
            showsCount ? L10n.contractionHistoryCount(state.count) : nil,
            state.lastInterval.map { L10n.laContractionLastInterval(ContractionClock.text($0)) },
            state.runningSince == nil ? state.lastDuration.map { L10n.laContractionLastDuration(ContractionClock.text($0)) } : nil,
        ].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .monospacedDigit()
                .lineLimit(2)
        }
    }
}

/// Start/Stop, with "Kết thúc" under it while resting (never while a
/// contraction runs: then only "Hết cơn"). `compact` in the expanded Dynamic
/// Island, whose height fits the two only when both are shorter.
private struct Buttons: View {
    let state: ContractionActivityAttributes.ContentState
    let scheme: ColorScheme
    let compact: Bool

    private var resting: Bool { state.runningSince == nil }

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            ToggleButton(state: state, scheme: scheme, height: compact && resting ? 30 : 44)
            if resting {
                EndButton(scheme: scheme, height: compact ? 26 : 32)
            }
        }
        .fixedSize()
    }
}

private struct ToggleButton: View {
    let state: ContractionActivityAttributes.ContentState
    let scheme: ColorScheme
    let height: CGFloat

    private var isRunning: Bool { state.runningSince != nil }

    var body: some View {
        // The action it shows: a tap on an out-of-date state does nothing.
        Button(intent: ToggleContractionIntent(action: isRunning ? .stop : .start)) {
            Label(
                isRunning ? L10n.laContractionStop : L10n.laContractionStart,
                systemImage: isRunning ? "stop.fill" : "play.fill"
            )
            .font(.headline)
            .foregroundStyle(Color.luna(.onAccent, scheme))
            .lineLimit(1)
            .frame(minWidth: 64, minHeight: height)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Color.luna(isRunning ? .pregOnSoft : .pregStrong, scheme))
        .accessibilityLabel(isRunning ? L10n.contractionStop : L10n.contractionStart)
    }
}

/// "Kết thúc": ends the tracking session (`EndContractionTrackingIntent`),
/// keeping every contraction. No confirmation is possible on the Lock Screen;
/// see the intent for why that is accepted.
private struct EndButton: View {
    let scheme: ColorScheme
    let height: CGFloat

    var body: some View {
        Button(intent: EndContractionTrackingIntent()) {
            Label(L10n.laContractionEnd, systemImage: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.luna(.pregText, scheme))
                .lineLimit(1)
                .frame(minWidth: 64, minHeight: height)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Color.luna(.pregText, scheme))
        .accessibilityLabel(L10n.laContractionEndA11y)
    }
}

/// The 5-1-1 or preterm alert, shortened from the timer screen's card.
private struct AlertLine: View {
    let alert: ContractionAlert
    let scheme: ColorScheme

    var body: some View {
        if let text {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.luna(.warningText, scheme))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var text: String? {
        switch alert {
        case .none: nil
        case .fiveOneOne: L10n.laContractionAlertFiveOneOne
        case .pretermRegular: L10n.laContractionAlertPreterm
        }
    }
}

/// The stopwatch, or the warning sign while the alert is on.
private struct CompactIcon: View {
    let state: ContractionActivityAttributes.ContentState

    var body: some View {
        if state.alert != .none {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.luna(.warningText, .dark))
        } else {
            Image(systemName: state.runningSince == nil ? "stopwatch" : "stopwatch.fill")
                .foregroundStyle(Color.luna(.pregStrong, .dark))
        }
    }
}

private enum ContractionClockRange {
    /// From the start to start + `maxDuration`: the timer stops at 5:00, where
    /// the app closes a forgotten contraction.
    static func running(_ since: Date) -> ClosedRange<Date> {
        since...since.addingTimeInterval(ContractionRules.maxDuration)
    }

    /// From the last end to 2 hours later (`ContractionRules.episodeGap`): by
    /// then the activity is stale and shows the count instead.
    static func resting(_ since: Date) -> ClosedRange<Date> {
        since...since.addingTimeInterval(ContractionRules.episodeGap)
    }
}

private extension ActivityViewContext where Attributes == ContractionActivityAttributes {
    /// A stale activity (2 hours after the last start) shows the resting state:
    /// nothing runs any more and its last hour holds no contraction.
    var shownState: ContractionActivityAttributes.ContentState {
        guard isStale else { return state }
        var resting = state
        resting.runningSince = nil
        resting.restingSince = nil
        resting.alert = .none
        return resting
    }
}

private extension Color {
    /// A Luna token's value for `scheme`: the extension has no asset catalogue
    /// of the tokens, so it reads `LunaPalette` directly.
    static func luna(_ token: LunaToken, _ scheme: ColorScheme) -> Color {
        let pair = LunaPalette.pair(token)
        let hex = scheme == .dark ? pair.dark : pair.light
        return Color(.sRGB, red: hex.red, green: hex.green, blue: hex.blue, opacity: hex.alpha)
    }
}
