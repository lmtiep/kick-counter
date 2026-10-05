import ActivityKit
import AppIntents
import KickCore
import SwiftUI
import WidgetKit

struct KickLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: KickActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CountLabel(state: context.state).font(.title2.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedLabel(attributes: context.attributes, state: context.state)
                        .font(.title3.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale && context.state.completedAt == nil {
                        Text(L10n.laOverdue).font(.caption).foregroundStyle(.orange)
                    }
                    AddKickButton(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "heart.fill").foregroundStyle(Color.accentColor)
            } compactTrailing: {
                CountLabel(state: context.state)
            } minimal: {
                Text("\(context.state.count)").foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<KickActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                CountLabel(state: context.state).font(.largeTitle.bold())
                ElapsedLabel(attributes: context.attributes, state: context.state)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if context.isStale && context.state.completedAt == nil {
                    Text(L10n.laOverdue).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            AddKickButton(state: context.state)
        }
    }
}

private struct CountLabel: View {
    let state: KickActivityAttributes.ContentState

    var body: some View {
        Text("\(state.count)/\(SessionRules.targetCount)")
            .monospacedDigit()
            .foregroundStyle(Color.accentColor)
    }
}

private struct ElapsedLabel: View {
    let attributes: KickActivityAttributes
    let state: KickActivityAttributes.ContentState

    var body: some View {
        if let completedAt = state.completedAt {
            Text(L10n.laCompleted + " " + Duration.seconds(completedAt.timeIntervalSince(attributes.startedAt).rounded())
                .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)
                    // The app's language (App Group), as in the app, not the device's.
                    .locale(AppLocale.locale)))
        } else {
            Text(timerInterval: attributes.startedAt...Date.distantFuture, countsDown: false)
        }
    }
}

private struct AddKickButton: View {
    let state: KickActivityAttributes.ContentState

    var body: some View {
        if state.completedAt == nil {
            Button(intent: AddKickIntent()) {
                Text(L10n.laAdd)
                    .font(.title.bold())
                    .frame(minWidth: 64, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(.accentColor)
            .accessibilityLabel(L10n.counterA11yButton)
        }
    }
}
