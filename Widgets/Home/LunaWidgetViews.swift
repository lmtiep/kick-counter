import KickCore
import SwiftUI
import WidgetKit

/// The sizes the widget draws. `LunaWidgetEntryView` maps `WidgetFamily` to it, so
/// the views below do not depend on the widget environment (and can be rendered
/// to PNG in a unit test).
enum WidgetLayout: Equatable {
    case small
    case medium
    case accessoryRectangular
    case accessoryInline
    case accessoryCircular

    init(_ family: WidgetFamily) {
        switch family {
        case .systemMedium: self = .medium
        case .accessoryRectangular: self = .accessoryRectangular
        case .accessoryInline: self = .accessoryInline
        case .accessoryCircular: self = .accessoryCircular
        default: self = .small
        }
    }

    var isAccessory: Bool {
        switch self {
        case .accessoryRectangular, .accessoryInline, .accessoryCircular: true
        case .small, .medium: false
        }
    }
}

/// What the widget shows for one snapshot, in one layout.
struct LunaWidgetContent: View {
    let snapshot: WidgetSnapshot
    let layout: WidgetLayout

    var body: some View {
        switch snapshot.content {
        case .needsSetup: SetupView(layout: layout)
        case .cycle(let cycle): CycleWidgetView(cycle: cycle, layout: layout)
        case .fertility(let fertility): FertilityWidgetView(content: fertility, layout: layout)
        case .pregnancy(let pregnancy): PregnancyWidgetView(content: pregnancy, layout: layout)
        }
    }
}

// MARK: - Pieces

private struct Eyebrow: View {
    let text: String
    var token: LunaToken = .textSecondary

    var body: some View {
        Text(text)
            .font(WidgetStyle.font(11, .semibold, relativeTo: .caption2))
            .tracking(0.3)
            .foregroundStyle(.luna(token))
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.leading)
    }
}

private struct Chip: View {
    let text: String
    let fill: LunaToken
    let foreground: LunaToken

    var body: some View {
        Text(text)
            .font(WidgetStyle.font(11, .semibold, relativeTo: .caption2))
            .foregroundStyle(.luna(foreground))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(.luna(fill)))
    }
}

/// Lock Screen text: bold first line, lighter second. Vibrant rendering ignores colours.
private struct AccessoryLines: View {
    let title: String
    let detail: String?
    var third: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(WidgetStyle.font(14, .bold, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .widgetAccentable()
            if let detail {
                Text(detail)
                    .font(WidgetStyle.font(12, .medium, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let third {
                Text(third)
                    .font(WidgetStyle.font(12, .regular, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .opacity(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AccessoryRing: View {
    let progress: Double
    let value: String
    let caption: String?

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.28), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            VStack(spacing: 0) {
                Text(value)
                    .font(WidgetStyle.font(17, .bold, relativeTo: .headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let caption {
                    Text(caption)
                        .font(WidgetStyle.font(8, .semibold, relativeTo: .caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(6)
        }
        .padding(2)
    }
}

// MARK: - Needs setup

private struct SetupView: View {
    let layout: WidgetLayout

    var body: some View {
        switch layout {
        case .accessoryInline:
            Text(L10n.widgetSetup)
        case .accessoryCircular:
            Image(systemName: "heart.fill").font(.title2).widgetAccentable()
        case .accessoryRectangular:
            AccessoryLines(title: L10n.widgetName, detail: L10n.widgetSetup)
        case .small, .medium:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.luna(.cycleStrong))
                    .widgetAccentable()
                Spacer(minLength: 0)
                Text(L10n.widgetName)
                    .font(WidgetStyle.font(17, .bold, relativeTo: .headline))
                    .foregroundStyle(.luna(.textPrimary))
                Text(L10n.widgetSetup)
                    .font(WidgetStyle.font(14, .medium, relativeTo: .subheadline))
                    .foregroundStyle(.luna(.textSecondary))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Cycle tracking

private struct CycleWidgetView: View {
    let cycle: WidgetSnapshot.CycleContent
    let layout: WidgetLayout

    var body: some View {
        let texts = WidgetCycleTexts(cycle)
        switch layout {
        case .accessoryInline:
            Text(texts.inline)
        case .accessoryCircular:
            AccessoryRing(progress: cycle.markerFraction, value: circularValue, caption: nil)
        case .accessoryRectangular:
            AccessoryLines(title: texts.shortName + " · " + texts.figure, detail: texts.date, third: texts.showsCycleDay ? texts.cycleDay : nil)
        case .small:
            column(texts)
        case .medium:
            HStack(spacing: 14) {
                column(texts)
                CycleRingBadge(cycle: cycle)
                    .frame(width: 104, height: 104)
            }
        }
    }

    private var circularValue: String {
        switch cycle.headline {
        case .upcoming(let days): "\(days)"
        case .onPeriod(let day): "\(day)"
        case .late(let days): "+\(days)"
        case .dueToday: "0"
        }
    }

    private func column(_ texts: WidgetCycleTexts) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Eyebrow(text: texts.eyebrow)
            Spacer(minLength: 0)
            Text(texts.figure)
                .font(WidgetStyle.font(32, .bold, relativeTo: .largeTitle))
                .foregroundStyle(.luna(.cycleStrong))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            if let date = texts.date {
                Text(date)
                    .font(WidgetStyle.font(15, .semibold, relativeTo: .body))
                    .foregroundStyle(.luna(.textPrimary))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if texts.showsCycleDay {
                Chip(text: texts.cycleDay, fill: .cycleSoft, foreground: .cycleOnSoft)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The cycle ring of Today, small: coloured stretches, today's marker, the day in the middle.
private struct CycleRingBadge: View {
    let cycle: WidgetSnapshot.CycleContent
    private let thickness: CGFloat = 9
    private let gap: CGFloat = 1.5

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let inset = cycle.ring.count > 1 ? Double(gap / (.pi * (diameter - thickness))) / 2 : 0
            ZStack {
                ForEach(Array(cycle.ring.enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start + inset, to: segment.end - inset)
                        .stroke(
                            color(segment.kind),
                            style: StrokeStyle(lineWidth: segment.kind == .ovulation ? thickness + 4 : thickness, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(thickness / 2)
                }
                marker(diameter: diameter)
                Text(L10n.cycleRingDay(cycle.cycleDay))
                    .font(WidgetStyle.font(16, .bold, relativeTo: .headline))
                    .foregroundStyle(.luna(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, thickness + 8)
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityHidden(true)
    }

    private func marker(diameter: CGFloat) -> some View {
        let angle = 2 * Double.pi * cycle.markerFraction
        let radius = Double(diameter - thickness) / 2
        let offset = CycleRingGeometry.markerOffset(angle: angle, radius: radius)
        return Circle()
            .fill(.luna(.cardOpaque))
            .overlay(Circle().strokeBorder(.luna(.textPrimary), lineWidth: 2))
            .frame(width: 14, height: 14)
            .offset(x: offset.x, y: offset.y)
    }

    private func color(_ kind: CycleRingKind) -> Color {
        switch kind {
        case .period: .luna(.cycle)
        case .predictedPeriod: Color.luna(.cycle).opacity(0.45)
        case .fertile: .luna(.fertile)
        case .ovulation: .luna(.teal)
        case .base: .luna(.ringTrack)
        }
    }
}

// MARK: - Trying to conceive

private struct FertilityWidgetView: View {
    let content: WidgetSnapshot.FertilityContent
    let layout: WidgetLayout

    private var accent: LunaToken {
        switch content.status {
        case .high, .ovulationDay: .tealStrong
        case .period, .late: .cycleStrong
        case .low: .textPrimary
        }
    }

    var body: some View {
        let texts = WidgetFertilityTexts(content)
        switch layout {
        case .accessoryInline:
            Text(texts.inline)
        case .accessoryCircular:
            AccessoryRing(progress: Double(content.cycleDay) / 28, value: "\(content.cycleDay)", caption: nil)
        case .accessoryRectangular:
            AccessoryLines(title: texts.status, detail: texts.cycleDay, third: WidgetFormat.date(content.fertileWindow.lowerBound) + " – " + WidgetFormat.date(content.fertileWindow.upperBound))
        case .small:
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: texts.cycleDay)
                Spacer(minLength: 0)
                Text(texts.status)
                    .font(WidgetStyle.font(20, .bold, relativeTo: .title3))
                    .foregroundStyle(.luna(accent))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                Spacer(minLength: 4)
                Text(texts.window)
                    .font(WidgetStyle.font(11, .medium, relativeTo: .caption2))
                    .foregroundStyle(.luna(.textSecondary))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .medium:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(texts.status)
                        .font(WidgetStyle.font(20, .bold, relativeTo: .title3))
                        .foregroundStyle(.luna(accent))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .widgetAccentable()
                    Spacer(minLength: 6)
                    Chip(text: texts.cycleDay, fill: .cycleSoft, foreground: .cycleOnSoft)
                }
                Text(texts.window)
                    .font(WidgetStyle.font(12, .medium, relativeTo: .caption))
                    .foregroundStyle(.luna(.textSecondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    ForEach(Array(content.strip.enumerated()), id: \.offset) { _, day in
                        StripDayView(day: day)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct StripDayView: View {
    let day: WidgetSnapshot.StripDay

    private var style: DayCircleLook {
        switch day.status {
        case .period(isPredicted: false): DayCircleLook(fill: .cycleStrong, foreground: .onAccent)
        case .period(isPredicted: true): DayCircleLook(fill: nil, foreground: .cycleText, border: .cycle, dashed: true)
        case .fertile: DayCircleLook(fill: .fertileSoft, foreground: .tealStrong, border: .fertileSoftBorder)
        case .peak: DayCircleLook(fill: .ovulation, foreground: .tealStrong, border: .teal, bold: true)
        case .low: DayCircleLook(fill: nil, foreground: .textPrimary)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(WidgetFormat.weekday(day.date))
                .font(WidgetStyle.font(10, .semibold, relativeTo: .caption2))
                .foregroundStyle(.luna(.textSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(WidgetFormat.dayNumber(day.date))
                .font(WidgetStyle.font(13, day.isToday || style.bold ? .bold : .medium, relativeTo: .footnote))
                .foregroundStyle(.luna(style.foreground))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 30, height: 30)
                .background { if let fill = style.fill { Circle().fill(.luna(fill)) } }
                .overlay {
                    if let border = style.border {
                        Circle().strokeBorder(.luna(border), style: StrokeStyle(lineWidth: 1.5, dash: style.dashed ? [3, 2.5] : []))
                    }
                }
                .overlay {
                    if day.isToday { Circle().strokeBorder(.luna(.textPrimary), lineWidth: 2).padding(-2) }
                }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DayCircleLook {
    var fill: LunaToken?
    var foreground: LunaToken
    var border: LunaToken?
    var dashed = false
    var bold = false
}

// MARK: - Pregnancy

private struct PregnancyWidgetView: View {
    let content: WidgetSnapshot.PregnancyContent
    let layout: WidgetLayout

    var body: some View {
        let texts = WidgetPregnancyTexts(content)
        switch layout {
        case .accessoryInline:
            Text(texts.inline)
        case .accessoryCircular:
            AccessoryRing(progress: texts.progress, value: "\(content.weeks)", caption: nil)
        case .accessoryRectangular:
            AccessoryLines(title: texts.week, detail: texts.remainingShort, third: texts.kicks)
        case .small:
            column(texts)
        case .medium:
            HStack(spacing: 12) {
                column(texts, showsKicks: true)
                FruitView(week: content.fruitWeek)
                    .frame(width: 92, height: 92)
            }
        }
    }

    private func column(_ texts: WidgetPregnancyTexts, showsKicks: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)
            Text(texts.week)
                .font(WidgetStyle.font(32, .bold, relativeTo: .largeTitle))
                .foregroundStyle(.luna(.pregStrong))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            Text(texts.remaining)
                .font(WidgetStyle.font(14, .semibold, relativeTo: .subheadline))
                .foregroundStyle(.luna(.textPrimary))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            ProgressBar(progress: texts.progress)
            if showsKicks, let kicks = texts.kicks {
                Link(destination: WidgetLink.kicks.url) {
                    Text(kicks)
                        .font(WidgetStyle.font(12, .semibold, relativeTo: .caption))
                        .foregroundStyle(.luna(.pregOnSoft))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.luna(.pregSoft)))
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.luna(.track))
                Capsule().fill(.luna(.pregBar)).frame(width: max(6, proxy.size.width * progress))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

private final class WidgetBundleToken {}

/// The week's fruit (`Fruit-W##`, in the widget bundle); nothing when the art is missing.
private struct FruitView: View {
    let week: Int
    private let bundle = Bundle(for: WidgetBundleToken.self)

    var body: some View {
        if UIImage(named: WeekArtworkName.fruit(week: week), in: bundle, with: nil) != nil {
            Image(WeekArtworkName.fruit(week: week), bundle: bundle)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }
}
