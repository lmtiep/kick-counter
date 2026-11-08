import KickCore
import SwiftUI

/// One page of the birth celebration (handoff "Các trang"). A new page is a new
/// view, so its entrance animations run again each time it shows.
struct CelebrationPage: View {
    let page: PregnancyRecap.Page
    let recap: PregnancyRecap
    let animates: Bool
    let availableHeight: CGFloat
    let showsNext: Bool
    let onNext: () -> Void
    let onDone: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        switch page {
        case .celebration: celebration
        case .journey: journey
        case .kicks:
            statPage(art: "stat-kicks", value: Double(recap.totalKicks), label: L10n.birthKicksLabel(recap.totalKicks))
        case .contractions:
            statPage(
                art: "stat-contractions", value: Double(recap.contractions),
                label: L10n.birthContractionsLabel(recap.contractions)
            )
        case .appointments:
            statPage(
                art: "stat-visits", value: Double(recap.appointments), label: L10n.birthAppointmentsLabel(recap.appointments)
            )
        case .weight: weight
        case .thanks: thanks
        case .summary: summary
        }
    }

    private func color(_ token: CelebrationPalette.Token) -> Color { CelebrationPalette.color(token, scheme) }

    /// The hero art takes what is left, 190…300 pt (180…260 for thanks), and is
    /// smallest at accessibility sizes so the page scrolls instead.
    private func heroSide(min low: CGFloat, max high: CGFloat) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? low : Swift.min(high, Swift.max(low, availableHeight * 0.36))
    }

    // MARK: - 1. Celebration

    private var celebration: some View {
        VStack(spacing: 18) {
            Hero(image: "cel-hero", side: heroSide(min: 190, max: 300), discInset: 0.06, sparkles: Sparkle.hero, animates: animates)
            VStack(spacing: 10) {
                Text(L10n.birthCelebrationTitle)
                    .font(.luna(size: 30, weight: .semibold, relativeTo: .title))
                    .tracking(-0.6)
                    .foregroundStyle(color(.ink))
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.birthHelloWish)
                    .font(.luna(size: 16, weight: .regular, relativeTo: .body))
                    .lineSpacing(8)
                    .foregroundStyle(color(.ink2))
                    .frame(maxWidth: 330)
                if recap.baby == nil {
                    Text(L10n.birthBornOn(Formatting.longDate(recap.birthDate)))
                        .font(.luna(size: 14, weight: .medium, relativeTo: .footnote))
                        .foregroundStyle(color(.ink2))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .appear(animates, delay: 0.38)
            if let baby = recap.baby {
                BabyCard(baby: baby, birthDate: recap.birthDate)
                    .appear(animates, delay: 0.52)
            }
            nextButton(delay: 0.65)
        }
    }

    // MARK: - 2. Journey

    private var journey: some View {
        let weeks = recap.weeks ?? 0
        return VStack(spacing: 18) {
            eyebrow(L10n.birthEyebrow)
            WeekStrip(weeks: recap.journeyWeeks, animates: animates)
            VStack(spacing: 4) {
                BigNumber(value: Double(weeks), format: Self.number, animates: animates)
                Text(L10n.birthWeeksTogether(weeks))
                    .font(.luna(size: 22, weight: .medium, relativeTo: .title2))
                    .foregroundStyle(color(.ink))
                if let days = recap.days {
                    CountUp(value: Double(days), animates: animates) { L10n.birthDaysWithBaby(days, formatted: Self.number($0)) }
                        .font(.luna(size: 16, weight: .regular, relativeTo: .body))
                        .foregroundStyle(color(.ink2))
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                ["\(weeks) \(L10n.birthWeeksTogether(weeks))", recap.days.map { L10n.birthDaysWithBaby($0, formatted: Self.number(Double($0))) }]
                    .compactMap { $0 }.joined(separator: ", ")
            )
            nextButton(delay: 0.65)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - 3–6. Numbers

    private func statPage(art: String, value: Double, label: String, above: String? = nil, unit: String? = nil) -> some View {
        VStack(spacing: 18) {
            eyebrow(L10n.birthEyebrow)
            StatArt(image: art, side: dynamicTypeSize.isAccessibilitySize ? 100 : 140, animates: animates)
            VStack(spacing: 6) {
                if let above {
                    Text(above)
                        .font(.luna(size: 22, weight: .medium, relativeTo: .title2))
                        .foregroundStyle(color(.ink))
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    BigNumber(value: value, format: unit == nil ? Self.number : Self.signedKg, animates: animates)
                    if let unit {
                        Text(unit)
                            .font(.luna(size: 28, weight: .semibold, relativeTo: .title))
                            .foregroundStyle(color(.num))
                    }
                }
                if above == nil {
                    Text(label)
                        .font(.luna(size: 22, weight: .medium, relativeTo: .title2))
                        .foregroundStyle(color(.ink))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                above.map { "\($0): \(Self.signedKg(value)) \(unit ?? "")" } ?? "\(Self.number(value)) \(label)"
            )
            nextButton(delay: 0.65)
        }
        .frame(maxHeight: .infinity)
    }

    private var weight: some View {
        statPage(
            art: "stat-weight", value: Self.roundedKg(recap.weightChangeKg ?? 0), label: "",
            above: L10n.birthWeightChange, unit: "kg"
        )
    }

    // MARK: - 7. Thanks

    private var thanks: some View {
        VStack(spacing: 18) {
            Hero(image: "cel-thanks", side: heroSide(min: 180, max: 260), discInset: 0.04, sparkles: Sparkle.thanks, animates: animates)
            VStack(spacing: 10) {
                Text(L10n.birthThanksTitle)
                    .font(.luna(size: 30, weight: .semibold, relativeTo: .title))
                    .tracking(-0.6)
                    .foregroundStyle(color(.ink))
                Text(L10n.birthThanksBody(weeks: recap.weeks))
                    .font(.luna(size: 16, weight: .regular, relativeTo: .body))
                    .lineSpacing(8)
                    .foregroundStyle(color(.ink2))
                    .frame(maxWidth: 330)
                if recap.keptAsMemory {
                    Text(L10n.birthThanksSaved)
                        .font(.luna(size: 14, weight: .medium, relativeTo: .footnote))
                        .foregroundStyle(color(.ink2))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("birthCelebrationThanks")
            .appear(animates, delay: 0.38)
            nextButton(delay: 0.56)
        }
    }

    // MARK: - 8. Summary

    private var summary: some View {
        VStack(spacing: 16) {
            SummaryCard(recap: recap, animates: animates)
            HStack(spacing: 10) {
                SaveSummaryButton(recap: recap)
                Button(L10n.birthDone, action: onDone)
                    .buttonStyle(CelebrationButtonStyle(filled: true))
                    .accessibilityIdentifier("birthCelebrationDone")
            }
            .appear(animates, delay: 0.52, rises: false)
        }
    }

    // MARK: - Pieces

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.luna(size: 13, weight: .semibold, relativeTo: .footnote))
            .tracking(1.56)
            .foregroundStyle(color(.ink2))
            .multilineTextAlignment(.center)
            .appear(animates, delay: 0.38)
    }

    @ViewBuilder private func nextButton(delay: Double) -> some View {
        if showsNext {
            Button(L10n.birthNext, action: onNext)
                .buttonStyle(CelebrationButtonStyle(filled: true))
                .padding(.top, 6)
                .appear(animates, delay: delay, rises: false)
                .accessibilityIdentifier("birthCelebrationNext")
        }
    }

    static func number(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.locale(Formatting.locale))
    }

    /// One decimal, so a count-up reads "+11,5" at the end.
    static func roundedKg(_ kg: Double) -> Double { (kg * 10).rounded() / 10 }

    /// "+11,5"; a change that rounds to zero is "0,0", never "+0,0".
    static func signedKg(_ kg: Double) -> String {
        let rounded = roundedKg(kg)
        return rounded.formatted(
            .number.precision(.fractionLength(1)).sign(strategy: rounded == 0 ? .automatic : .always()).locale(Formatting.locale)
        )
    }
}

// MARK: - Entrance

private struct Appear: ViewModifier {
    let animates: Bool
    let delay: Double
    let rises: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !animates ? 1 : 0)
            .offset(y: shown || !animates || !rises ? 0 : 16)
            .onAppear {
                guard animates else { return }
                withAnimation(rises ? CelebrationMotion.text(delay: delay) : CelebrationMotion.button(delay: delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// Text and cards rise 16 pt and fade in; buttons (`rises: false`) only fade.
    fileprivate func appear(_ animates: Bool, delay: Double, rises: Bool = true) -> some View {
        modifier(Appear(animates: animates, delay: delay, rises: rises))
    }
}

/// Art bounces in from 0.72 and 28 pt lower, then breathes (1 → 1.025, up 4 pt).
private struct ArtEntrance: ViewModifier {
    let animates: Bool
    var delay = 0.12
    @State private var arrived = false
    @State private var breathing = false

    func body(content: Content) -> some View {
        let still = !animates
        content
            .scaleEffect(still ? 1 : (arrived ? (breathing ? 1.025 : 1) : 0.72))
            .offset(y: still ? 0 : (arrived ? (breathing ? -4 : 0) : 28))
            .opacity(still || arrived ? 1 : 0)
            .onAppear {
                guard animates else { return }
                withAnimation(CelebrationMotion.art.delay(delay)) { arrived = true }
                withAnimation(CelebrationMotion.breathe.delay(delay + 1)) { breathing = true }
            }
    }
}

// MARK: - Art

/// A ✦ placed by fractions of the art's frame, twinkling out of phase.
struct Sparkle {
    let x: Double
    let y: Double
    let size: CGFloat
    let token: CelebrationPalette.Token
    let period: Double

    /// Page 1: left 8 % top 4 % · right 4 % top 22 % · left 2 % bottom 18 %.
    static let hero = [
        Sparkle(x: 0.08, y: 0.04, size: 22, token: .accent, period: 2.4),
        Sparkle(x: 0.96, y: 0.22, size: 14, token: .moon, period: 3.2),
        Sparkle(x: 0.02, y: 0.82, size: 16, token: .accent, period: 2.8),
    ]
    static let thanks = [
        Sparkle(x: 0.1, y: 0.06, size: 20, token: .accent, period: 2.4),
        Sparkle(x: 0.94, y: 0.3, size: 14, token: .moon, period: 3.2),
    ]
}

private struct SparkleView: View {
    let sparkle: Sparkle
    let animates: Bool
    @Environment(\.colorScheme) private var scheme
    @State private var bright = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: sparkle.size))
            .foregroundStyle(CelebrationPalette.color(sparkle.token, scheme))
            .opacity(animates ? (bright ? 1 : 0.35) : 1)
            .scaleEffect(animates ? (bright ? 1.1 : 0.8) : 1)
            .onAppear {
                guard animates else { return }
                withAnimation(.easeInOut(duration: sparkle.period / 2).repeatForever(autoreverses: true).delay(sparkle.period / 4)) {
                    bright = true
                }
            }
    }
}

/// The disc, the moon art and its sparkles, square.
private struct Hero: View {
    let image: String
    let side: CGFloat
    let discInset: CGFloat
    let sparkles: [Sparkle]
    let animates: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Circle()
                .fill(CelebrationPalette.color(.disc, scheme))
                .padding(side * discInset)
            Image(image)
                .resizable()
                .scaledToFit()
            ForEach(sparkles.indices, id: \.self) { index in
                let sparkle = sparkles[index]
                SparkleView(sparkle: sparkle, animates: animates)
                    .position(x: side * sparkle.x, y: side * sparkle.y)
            }
        }
        .frame(width: side, height: side)
        .modifier(ArtEntrance(animates: animates))
        .accessibilityHidden(true)
    }
}

/// The 140 pt light disc with a number page's art at 76 %.
private struct StatArt: View {
    let image: String
    let side: CGFloat
    let animates: Bool

    var body: some View {
        Image(image)
            .resizable()
            .scaledToFit()
            .frame(width: side * 0.76, height: side * 0.76)
            .frame(width: side, height: side)
            .background(CelebrationPalette.color(.statDisc, .light), in: Circle())
            .modifier(ArtEntrance(animates: animates))
            .accessibilityHidden(true)
    }
}

/// The babies of the journey, growing left to right on a dashed line; the final
/// week is the newborn and its label is bold.
private struct WeekStrip: View {
    let weeks: [Int]
    let animates: Bool
    @Environment(\.colorScheme) private var scheme

    private static let sizes: [CGFloat] = [44, 52, 60, 68, 76]

    var body: some View {
        let sizes = Array(Self.sizes.suffix(weeks.count))
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(.clear)
                    .frame(height: 2)
                    .overlay {
                        Line()
                            .stroke(CelebrationPalette.color(.line, scheme), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                    .padding(.horizontal, 20)
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { position, week in
                        Image(Self.art(week, isFinal: position == weeks.count - 1))
                            .resizable()
                            .scaledToFit()
                            .frame(width: sizes[position], height: sizes[position])
                            .modifier(ArtEntrance(animates: animates, delay: 0.2 + 0.1 * Double(position)))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { position, week in
                    let isFinal = position == weeks.count - 1
                    Text(L10n.birthJourneyWeekLabel(week))
                        .font(.luna(size: 12, weight: isFinal ? .semibold : .regular, relativeTo: .caption))
                        .foregroundStyle(CelebrationPalette.color(isFinal ? .ink : .ink2, scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: 360)
        .accessibilityHidden(true)
    }

    static func art(_ week: Int, isFinal: Bool) -> String {
        String(format: "week-%02d", PregnancyRecap.milestoneArt(week, isFinal: isFinal))
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

// MARK: - Numbers

/// A number counting up from 0 over 1.4 s, easing out (`1 − (1 − t)³`); the final
/// value at once without motion.
struct CountUp: View {
    let value: Double
    let animates: Bool
    let text: (Double) -> String
    @State private var shown: Double?

    var body: some View {
        Text(text(shown ?? (animates ? 0 : value)))
            .monospacedDigit()
            .task {
                guard animates, shown == nil else { return }
                let frames = 60
                for frame in 0...frames {
                    let t = Double(frame) / Double(frames)
                    shown = value * (1 - pow(1 - t, 3))
                    try? await Task.sleep(for: .seconds(CelebrationMotion.countUp / Double(frames)))
                }
                shown = value
            }
    }
}

/// The 88 pt number; it grows with Dynamic Type at only 40 % of the rate.
private struct BigNumber: View {
    let value: Double
    let format: (Double) -> String
    let animates: Bool
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .largeTitle) private var scaled: CGFloat = 88

    var body: some View {
        let size = 88 + (scaled - 88) * 0.4
        CountUp(value: value, animates: animates, text: format)
            .font(.custom(LunaWeight.semibold.rawValue, fixedSize: size))
            .tracking(-size * 0.04)
            .foregroundStyle(CelebrationPalette.color(.num, scheme))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - Cards

/// Name, birth date and the filled cells of time, weight and length.
private struct BabyCard: View {
    let baby: BirthDetails
    let birthDate: Date
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let name = baby.name {
                    Text(name)
                        .font(.luna(size: 20, weight: .semibold, relativeTo: .title3))
                        .foregroundStyle(color(.ink))
                }
                Text(L10n.birthBornOn(Formatting.longDate(birthDate)))
                    .font(.luna(size: 14, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(color(.ink2))
            }
            let cells = BirthCells(baby: baby).cells
            if !cells.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(cells, id: \.label) { cell in
                        VStack(spacing: 2) {
                            Text(cell.label)
                                .font(.luna(size: 12, weight: .regular, relativeTo: .caption))
                                .foregroundStyle(color(.ink2))
                            Text(cell.value)
                                .font(.luna(size: 17, weight: .semibold, relativeTo: .body))
                                .foregroundStyle(color(.ink))
                        }
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .background(color(.track), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color(.card), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(color(.line), lineWidth: 1) }
    }

    private func color(_ token: CelebrationPalette.Token) -> Color { CelebrationPalette.color(token, scheme) }
}

/// The baby's filled details as label/value pairs, in the handoff's order.
private struct BirthCells {
    struct Cell {
        let label: String
        let value: String
    }

    let cells: [Cell]

    init(baby: BirthDetails, weightLabel: String = L10n.birthInfoWeight) {
        var cells: [Cell] = []
        if let time = baby.time { cells.append(Cell(label: L10n.birthInfoTime, value: Formatting.time(time))) }
        if let kg = baby.weightKg {
            cells.append(Cell(label: weightLabel, value: Formatting.kilograms(kg)))
        }
        if let cm = baby.lengthCm { cells.append(Cell(label: L10n.birthInfoLength, value: Formatting.centimeters(cm))) }
        self.cells = cells
    }
}

/// Page 8, also rendered on its own as the saved image.
struct SummaryCard: View {
    let recap: PregnancyRecap
    let animates: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 16) {
            header
                .modifier(ArtEntrance(animates: animates, delay: 0.1))
            grid
                .appear(animates, delay: 0.38)
        }
    }

    private func color(_ token: CelebrationPalette.Token) -> Color { CelebrationPalette.color(token, scheme) }

    private var header: some View {
        HStack(spacing: 14) {
            Image("cel-hero")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .background(color(.disc), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.birthSummaryEyebrow)
                    .font(.luna(size: 13, weight: .semibold, relativeTo: .footnote))
                    .tracking(1.56)
                    .foregroundStyle(color(.ink2))
                Text(L10n.birthSummaryTitle(name: recap.baby?.name))
                    .font(.luna(size: 22, weight: .semibold, relativeTo: .title2))
                    .foregroundStyle(color(.ink))
                    .accessibilityAddTraits(.isHeader)
                Text(bornLine)
                    .font(.luna(size: 14, weight: .regular, relativeTo: .footnote))
                    .foregroundStyle(color(.ink2))
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bornLine: String {
        let date = L10n.birthBornOn(Formatting.longDate(recap.birthDate))
        guard let time = recap.baby?.time else { return date }
        return "\(date) · \(Formatting.time(time))"
    }

    private var grid: some View {
        // Plain rows, not a lazy grid: `ImageRenderer` draws lazy cells blank in the saved image.
        let perRow = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = stride(from: 0, to: statCells.count, by: perRow).map { Array(statCells[$0..<min($0 + perRow, statCells.count)]) }
        return VStack(spacing: 10) {
            if let weeks = recap.weeks {
                weeksCell(weeks)
            }
            ForEach(rows.indices, id: \.self) { row in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(rows[row], id: \.art) { cell in statCell(cell) }
                    // An odd last cell keeps half the width.
                    if rows[row].count < perRow { Color.clear.frame(maxWidth: .infinity) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if let baby = recap.baby {
                let cells = BirthCells(baby: baby, weightLabel: L10n.birthSummaryWeightAtBirth).cells
                if !cells.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) { birthText(cells, separator: " · ") }
                        VStack(alignment: .leading, spacing: 4) { birthText(cells, separator: nil) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(color(.track), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder private func birthText(_ cells: [BirthCells.Cell], separator: String?) -> some View {
        ForEach(cells.indices, id: \.self) { index in
            let cell = cells[index]
            (Text(cell.label + " ")
                + Text(cell.value).font(.luna(size: 14, weight: .semibold, relativeTo: .footnote))
                + Text(index < cells.count - 1 ? separator ?? "" : ""))
                .font(.luna(size: 14, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(color(.ink))
                .fixedSize(horizontal: separator != nil, vertical: true)
        }
    }

    private func weeksCell(_ weeks: Int) -> some View {
        HStack(spacing: 12) {
            Image("week-40")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(weeks) \(L10n.birthWeeksTogether(weeks))")
                    .font(.luna(size: 30, weight: .semibold, relativeTo: .title))
                    .foregroundStyle(color(.num))
                    .minimumScaleFactor(0.7)
                if let days = recap.days {
                    Text(L10n.birthDaysWithBaby(days, formatted: CelebrationPage.number(Double(days))))
                        .font(.luna(size: 14, weight: .regular, relativeTo: .footnote))
                        .foregroundStyle(color(.ink2))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cell(scheme)
        .accessibilityElement(children: .combine)
    }

    private struct StatCell {
        let art: String
        let value: String
        let label: String
    }

    private var statCells: [StatCell] {
        recap.pages.compactMap { page in
            switch page {
            case .kicks:
                StatCell(art: "stat-kicks", value: CelebrationPage.number(Double(recap.totalKicks)), label: L10n.birthKicksLabel(recap.totalKicks))
            case .contractions:
                StatCell(
                    art: "stat-contractions", value: CelebrationPage.number(Double(recap.contractions)),
                    label: L10n.birthContractionsLabel(recap.contractions)
                )
            case .appointments:
                StatCell(
                    art: "stat-visits", value: CelebrationPage.number(Double(recap.appointments)),
                    label: L10n.birthAppointmentsLabel(recap.appointments)
                )
            case .weight:
                StatCell(
                    art: "stat-weight", value: "\(CelebrationPage.signedKg(recap.weightChangeKg ?? 0)) kg",
                    label: L10n.birthWeightChangeShort
                )
            default: nil
            }
        }
    }

    private func statCell(_ cell: StatCell) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(cell.art)
                .resizable()
                .scaledToFit()
                .frame(width: 31, height: 31)
                .frame(width: 40, height: 40)
                .background(CelebrationPalette.color(.statDisc, .light), in: Circle())
                .accessibilityHidden(true)
            Text(cell.value)
                .font(.luna(size: 26, weight: .semibold, relativeTo: .title))
                .monospacedDigit()
                .foregroundStyle(color(.num))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(cell.label)
                .font(.luna(size: 14, weight: .regular, relativeTo: .footnote))
                .foregroundStyle(color(.ink))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cell(scheme)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    fileprivate func cell(_ scheme: ColorScheme) -> some View {
        padding(14)
            .background(CelebrationPalette.color(.card, scheme), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(CelebrationPalette.color(.line, scheme), lineWidth: 1)
            }
    }
}

// MARK: - Buttons

/// The handoff's capsule: filled `accent` with `onAccent` text, or outlined.
struct CelebrationButtonStyle: ButtonStyle {
    let filled: Bool
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.luna(size: 17, weight: .semibold, relativeTo: .body))
            .foregroundStyle(CelebrationPalette.color(filled ? .onAccent : .ink, scheme))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if filled {
                    Capsule().fill(CelebrationPalette.color(.accent, scheme))
                } else {
                    Capsule().strokeBorder(CelebrationPalette.color(.accent, scheme), lineWidth: 1.5)
                }
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// "Lưu ảnh": the summary rendered at 3× in the light theme, through the share
/// sheet (it has "Save Image"; no Photos permission).
private struct SaveSummaryButton: View {
    let recap: PregnancyRecap
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(L10n.birthSummaryTitle(name: recap.baby?.name), image: image)) {
                    Text(L10n.birthSave)
                }
            } else {
                Button(L10n.birthSave) {}.disabled(true)
            }
        }
        .buttonStyle(CelebrationButtonStyle(filled: false))
        .accessibilityIdentifier("birthCelebrationSave")
        .task { image = render() }
    }

    private func render() -> Image? {
        let card = SummaryCard(recap: recap, animates: false)
            .padding(20)
            .frame(width: 390)
            .background(CelebrationPalette.background(.light))
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(.large)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
