import KickCore
import SwiftUI

/// The big round button (phase 20 spec §4.2): "Bắt đầu cơn gò" at rest
/// (`pregStrong`), "Hết cơn gò" with a live m:ss while a contraction runs
/// (`pregOnSoft`). One VoiceOver button whose value is the running time.
struct ContractionToggleButton: View {
    let runningSince: Date?
    /// Changes on every tap that did something: the ripple.
    let pulse: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let diameter: CGFloat = 236
    private var animates: Bool { !reduceMotion && LunaMotion.isEnabled }
    private var isRunning: Bool { runningSince != nil }
    private var coreFill: LunaToken { isRunning ? .pregOnSoft : .pregStrong }

    var body: some View {
        // Every second, so the running time and its VoiceOver value stay current.
        TimelineView(.periodic(from: runningSince ?? .now, by: 1)) { context in
            button(now: context.date)
        }
    }

    private func button(now: Date) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(.luna(.pregSoft))
                Circle()
                    .fill(.luna(coreFill))
                    .shadow(
                        color: colorScheme == .dark ? Color.luna(coreFill).opacity(0.4) : Color.luna(.pregOnSoft).opacity(0.4),
                        radius: 14, y: 12
                    )
                    .overlay { RippleRing(trigger: pulse) }
                    .overlay {
                        core(now: now)
                            .padding(24)
                            // A fixed circle: past AX2 the text only shrinks;
                            // VoiceOver reads the label and value instead.
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    }
                    .padding(22)
            }
            .frame(width: diameter, height: diameter)
            .animation(animates ? .easeOut(duration: 0.25) : nil, value: isRunning)
        }
        .buttonStyle(ContractionPressStyle(animates: animates))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? L10n.contractionStop : L10n.contractionStart)
        .accessibilityValue(value(now: now))
        .accessibilityAddTraits(.isButton)
        // VoiceOver re-reads the running time as it changes.
        .accessibilityAddTraits(isRunning ? .updatesFrequently : [])
        .accessibilityIdentifier("contractionToggle")
    }

    @ViewBuilder
    private func core(now: Date) -> some View {
        if let runningSince {
            VStack(spacing: 4) {
                Text(L10n.contractionRunning)
                    .lunaLabelStyle(.onAccent)
                Text(ContractionClock.text(now.timeIntervalSince(runningSince)))
                    .font(.luna(size: 48, weight: .bold, relativeTo: .largeTitle))
                    .monospacedDigit()
                Text(L10n.contractionStop)
                    .font(.luna(.button))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.luna(.onAccent).opacity(0.18)))
            }
            .foregroundStyle(.luna(.onAccent))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 30, weight: .regular))
                    .accessibilityHidden(true)
                Text(L10n.contractionStart)
                    .font(.luna(size: 22, weight: .bold, relativeTo: .title2))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.luna(.onAccent))
            .minimumScaleFactor(0.5)
        }
    }

    private func value(now: Date) -> String {
        guard let runningSince else { return L10n.contractionResting }
        return L10n.contractionA11yRunning(ContractionClock.text(now.timeIntervalSince(runningSince)))
    }
}

/// 95 % while pressed, as the kick dial; not with Reduce Motion or in UI tests.
private struct ContractionPressStyle: ButtonStyle {
    let animates: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(animates && configuration.isPressed ? 0.95 : 1)
            .animation(animates ? .easeOut(duration: 0.12) : nil, value: configuration.isPressed)
    }
}

/// The 5-1-1 card and the urgent preterm card (spec §4.3), each with the
/// emergency call button of the kick alert. Nothing for `.none`.
struct ContractionAlertCard: View {
    let alert: ContractionAlert

    var body: some View {
        switch alert {
        case .none:
            EmptyView()
        case .fiveOneOne:
            card(
                text: L10n.contractionAlertFiveOneOne,
                symbol: "clock.badge.exclamationmark",
                textColor: .textPrimary,
                fill: .pregSoft,
                border: .pregSoftBorder,
                identifier: "contractionFiveOneOneCard"
            )
        case .pretermRegular:
            card(
                text: L10n.contractionAlertPreterm,
                symbol: "exclamationmark.triangle.fill",
                textColor: .warningText,
                fill: .warningBackground,
                border: .warningBorder,
                identifier: "contractionPretermCard"
            )
        }
    }

    private func card(
        text: String,
        symbol: String,
        textColor: LunaToken,
        fill: LunaToken,
        border: LunaToken,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.luna(alert == .pretermRegular ? .warningButton : .pregStrong))
                    .accessibilityHidden(true)
                Text(text)
                    .font(.luna(.bodyStrong))
                    .lineSpacing(3)
                    .foregroundStyle(.luna(textColor))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
            EmergencyCallButton(identifier: "contractionCallButton")
        }
        .lunaCard(fill, border: border, padding: 16)
    }
}

/// "Trong 1 giờ qua": the count, "Dài TB" and "Cách nhau TB" as m:ss; one
/// column per figure, one row each at accessibility sizes.
struct ContractionStatsCard: View {
    let summary: ContractionSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.contractionStatsTitle)
                .lunaLabelStyle(.pregText)
                .accessibilityAddTraits(.isHeader)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { figures }
            } else {
                HStack(alignment: .top, spacing: 8) { figures }
            }
        }
        .lunaCard(padding: 16)
    }

    @ViewBuilder
    private var figures: some View {
        figure(summary.count.formatted(.number.locale(Formatting.locale)), L10n.contractionStatsCount, "contractionStatsCount")
        figure(summary.averageDuration.map(ContractionClock.text) ?? L10n.contractionValueNone,
               L10n.contractionStatsDuration, "contractionStatsDuration")
        figure(summary.averageInterval.map(ContractionClock.text) ?? L10n.contractionValueNone,
               L10n.contractionStatsInterval, "contractionStatsInterval")
    }

    private func figure(_ value: String, _ label: String, _ identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.luna(.statFigure))
                .monospacedDigit()
                .foregroundStyle(.luna(.textPrimary))
            Text(label)
                .font(.luna(.small))
                .foregroundStyle(.luna(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label + ": " + value)
        .accessibilityIdentifier(identifier)
    }
}

/// The current episode, newest first: start time, length, interval, a delete
/// button per row (with a confirmation) and a tap to edit. "Vỡ ối" markers sit
/// in the list by their time.
struct ContractionEpisodeCard: View {
    let episode: ContractionEpisode?
    var markers: [LabourMarkerRecord] = []
    let onDelete: (ContractionEntry) -> Void
    var onEdit: (ContractionEntry) -> Void = { _ in }
    var onEditMarker: (LabourMarkerRecord) -> Void = { _ in }
    var onDeleteMarker: (LabourMarkerRecord) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Item: Identifiable {
        case entry(ContractionEntry)
        case marker(LabourMarkerRecord)

        var id: UUID {
            switch self {
            case .entry(let entry): entry.id
            case .marker(let marker): marker.id
            }
        }

        var time: Date {
            switch self {
            case .entry(let entry): entry.startedAt
            case .marker(let marker): marker.at
            }
        }
    }

    private var items: [Item] {
        let all = (episode?.entries.map(Item.entry) ?? []) + markers.map(Item.marker)
        return all.sorted { $0.time > $1.time }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.contractionListTitle)
                .font(.luna(.cardTitleSmall))
                .foregroundStyle(.luna(.textPrimary))
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 10)
            if !items.isEmpty {
                if !dynamicTypeSize.isAccessibilitySize, episode != nil {
                    columnTitles
                        .padding(.bottom, 6)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { LunaDivider() }
                    switch item {
                    case .entry(let entry): row(entry)
                    case .marker(let marker): markerRow(marker)
                    }
                }
            } else {
                Text(L10n.contractionListEmpty)
                    .font(.luna(.caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("contractionListEmpty")
            }
        }
        .lunaCard(padding: 16)
    }

    private var columnTitles: some View {
        HStack(spacing: 8) {
            Text(L10n.contractionListStart).frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.contractionListDuration).frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.contractionListInterval).frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 44, height: 1)
        }
        .font(.luna(.small))
        .foregroundStyle(.luna(.textSecondary))
        .accessibilityHidden(true)
    }

    private func row(_ entry: ContractionEntry) -> some View {
        let start = Formatting.time(entry.startedAt)
        let label = entry.isRunning
            ? L10n.contractionRowA11yRunning(start)
            : L10n.contractionRowA11y(
                start: start,
                duration: ContractionClock.text(entry.duration),
                interval: entry.interval.map(ContractionClock.text)
            )
        return HStack(spacing: 8) {
            Group {
                if entry.isRunning {
                    rowText(entry)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(label)
                } else {
                    // A completed row opens the edit sheet; a running one is stopped first.
                    Button { onEdit(entry) } label: {
                        rowText(entry)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(label)
                    .accessibilityHint(L10n.contractionEditHint)
                    .accessibilityAddTraits(.isButton)
                }
            }
            .accessibilityIdentifier("contractionRow")
            deleteButton(identifier: "contractionDelete", label: L10n.contractionDeleteA11y) { onDelete(entry) }
        }
        .padding(.vertical, 2)
    }

    private func rowText(_ entry: ContractionEntry) -> some View {
        let start = Formatting.time(entry.startedAt)
        let duration = entry.isRunning ? L10n.contractionRunning : ContractionClock.text(entry.duration)
        let interval = entry.interval.map(ContractionClock.text) ?? L10n.contractionValueNone
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    Text(start)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                    Text(entry.isRunning ? duration : L10n.contractionListDuration + " " + duration)
                        .foregroundStyle(.luna(entry.isRunning ? .pregText : .articleText))
                    Text(L10n.contractionListInterval + " " + interval)
                        .foregroundStyle(.luna(.articleText))
                }
                .font(.luna(.body))
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 8) {
                    Text(start)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(duration)
                        .font(.luna(entry.isRunning ? .bodyStrong : .body))
                        .foregroundStyle(.luna(entry.isRunning ? .pregText : .articleText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(interval)
                        .font(.luna(.body))
                        .foregroundStyle(.luna(.articleText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
        }
    }

    /// "Vỡ ối  14:05": a tap edits its time, the trash deletes it (with a confirmation).
    private func markerRow(_ marker: LabourMarkerRecord) -> some View {
        let time = Formatting.time(marker.at)
        return HStack(spacing: 8) {
            Button { onEditMarker(marker) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.luna(.pregText))
                        .accessibilityHidden(true)
                    Text(L10n.contractionWaterBrokeButton)
                        .font(.luna(.bodyStrong))
                        .foregroundStyle(.luna(.pregText))
                    Spacer(minLength: 8)
                    Text(time)
                        .font(.luna(.bodyStrong))
                        .monospacedDigit()
                        .foregroundStyle(.luna(.textPrimary))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.contractionWaterBrokeAt(time))
            .accessibilityHint(L10n.contractionEditHint)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("contractionMarkerRow")
            deleteButton(identifier: "contractionMarkerDelete", label: L10n.contractionDeleteA11y) { onDeleteMarker(marker) }
        }
        .padding(.vertical, 2)
    }

    private func deleteButton(identifier: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.luna(.textSecondary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
