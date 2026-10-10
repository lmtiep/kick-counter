import ActivityKit
import AppIntents
import KickCore
import SwiftUI
import WidgetKit

/// The contraction timer on the Lock Screen and in the Dynamic Island (phase 20
/// spec §4.4): "Đang gò" with the running time or "Đang nghỉ", the count and
/// the last interval, and a Start/Stop button (`ToggleContractionIntent`) that
/// works without opening the app. Laid out like `KickLiveActivityWidget`, in
/// the pregnancy Luna tokens.
struct ContractionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ContractionActivityAttributes.self) { context in
            ContractionLockScreenView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StatusLabel(state: context.state, scheme: .dark)
                        .font(.subheadline.weight(.semibold))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(L10n.contractionHistoryCount(context.state.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.luna(.textPrimary, .dark))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            MainFigure(state: context.state, scheme: .dark)
                                .font(.title.bold())
                            DetailLine(state: context.state, showsCount: false)
                                .font(.caption)
                                .foregroundStyle(Color.luna(.textSecondary, .dark))
                        }
                        Spacer(minLength: 8)
                        ToggleButton(state: context.state, scheme: .dark)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.runningSince == nil ? "stopwatch" : "stopwatch.fill")
                    .foregroundStyle(Color.luna(.pregStrong, .dark))
            } compactTrailing: {
                if let since = context.state.runningSince {
                    Text(timerInterval: since...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                        .frame(maxWidth: 52)
                        .foregroundStyle(Color.luna(.pregStrong, .dark))
                } else {
                    Text(context.state.count, format: .number)
                        .foregroundStyle(Color.luna(.pregStrong, .dark))
                }
            } minimal: {
                Image(systemName: context.state.runningSince == nil ? "stopwatch" : "stopwatch.fill")
                    .foregroundStyle(Color.luna(.pregStrong, .dark))
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
                DetailLine(state: state, showsCount: state.runningSince != nil)
                    .font(.subheadline)
                    .foregroundStyle(Color.luna(.textSecondary, scheme))
            }
            Spacer(minLength: 8)
            ToggleButton(state: state, scheme: scheme)
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

/// The running time, or the episode's count while resting.
private struct MainFigure: View {
    let state: ContractionActivityAttributes.ContentState
    let scheme: ColorScheme

    var body: some View {
        Group {
            if let since = state.runningSince {
                Text(timerInterval: since...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
            } else {
                Text(L10n.contractionHistoryCount(state.count))
            }
        }
        .foregroundStyle(Color.luna(.pregStrong, scheme))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
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

private struct ToggleButton: View {
    let state: ContractionActivityAttributes.ContentState
    let scheme: ColorScheme

    private var isRunning: Bool { state.runningSince != nil }

    var body: some View {
        Button(intent: ToggleContractionIntent()) {
            Label(
                isRunning ? L10n.laContractionStop : L10n.laContractionStart,
                systemImage: isRunning ? "stop.fill" : "play.fill"
            )
            .font(.headline)
            .foregroundStyle(Color.luna(.onAccent, scheme))
            .lineLimit(1)
            .frame(minWidth: 64, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Color.luna(isRunning ? .pregOnSoft : .pregStrong, scheme))
        .accessibilityLabel(isRunning ? L10n.contractionStop : L10n.contractionStart)
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
