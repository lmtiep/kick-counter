import KickCore
import SwiftUI
import UIKit

/// The full-screen moment after "Bé đã chào đời" and the recap that follows it
/// (birth celebration spec §5): a confetti page, then one fact per page. A tap
/// anywhere (or "Tiếp") moves on, a swipe right goes back, ✕ closes from every
/// page. Reduce Motion (and UI tests) get a still scatter, no count-up and a
/// cross-fade between pages.
struct BirthCelebrationView: View {
    let recap: PregnancyRecap
    /// The success haptic belongs to the moment of birth, not to a replay.
    var playsHaptic = true
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var index = 0

    private var animates: Bool { LunaMotion.isEnabled && !reduceMotion }
    private var pages: [PregnancyRecap.Page] { recap.pages }
    private var page: PregnancyRecap.Page { pages[min(index, pages.count - 1)] }
    private var isLast: Bool { index >= pages.count - 1 }

    var body: some View {
        ZStack {
            background
            if page == .celebration {
                ConfettiView(isStill: !animates)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            content
                .id(index)
                .transition(pageTransition)
            VStack {
                HStack {
                    Spacer()
                    closeButton
                }
                Spacer()
                controls
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .animation(pageAnimation, value: index)
        // VoiceOver follows to the new page instead of staying on a button of the old one.
        .onChange(of: index) { UIAccessibility.post(notification: .screenChanged, argument: nil) }
        .onAppear {
            if playsHaptic { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Chrome

    private var background: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [.luna(.backgroundTop), .luna(.backgroundBottom)], startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient(colors: [.luna(.cycleSoft), .luna(.background)], startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.luna(.textPrimary))
                .frame(width: 44, height: 44)
                .background(.luna(.card), in: Circle())
                .overlay { Circle().strokeBorder(.luna(.cardBorder), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.commonClose)
        .accessibilityIdentifier("birthCelebrationClose")
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { dot in
                    Capsule()
                        .fill(dot == index ? Color.luna(.cycleStrong) : Color.luna(.chevron).opacity(0.5))
                        .frame(width: dot == index ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.birthPage(index + 1, of: pages.count))
            if isLast {
                Button(L10n.birthDone, action: onClose)
                    .buttonStyle(.pill(.dark))
                    .accessibilityIdentifier("birthCelebrationDone")
            } else {
                Button(L10n.birthNext, action: advance)
                    .buttonStyle(.pill(.filled(.cycleStrong)))
                    .accessibilityIdentifier("birthCelebrationNext")
            }
        }
    }

    // MARK: - Paging

    private var pageAnimation: Animation? {
        guard LunaMotion.isEnabled else { return nil }
        return reduceMotion ? LunaMotion.fade : .spring(response: 0.5, dampingFraction: 0.85)
    }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        guard !isLast else { return }
        index += 1
    }

    private func goBack() {
        guard index > 0 else { return }
        index -= 1
    }

    // MARK: - Pages

    private var content: some View {
        GeometryReader { proxy in
            ScrollView {
                pageBody
                    .padding(.horizontal, 28)
                    // Room for the close button above and the controls below.
                    .padding(.top, 64)
                    .padding(.bottom, 130)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: advance)
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                if value.translation.width > 60, abs(value.translation.height) < 80 { goBack() }
            }
        )
    }

    @ViewBuilder private var pageBody: some View {
        switch page {
        case .celebration: celebrationPage
        case .journey: journeyPage
        case .kicks:
            StatPage(
                symbol: "hand.tap.fill", target: recap.totalKicks,
                format: { Self.number($0) },
                line: L10n.birthKicksLine(sessions: recap.kickSessions, formattedSessions: Self.number(recap.kickSessions)),
                animates: animates, compactArt: dynamicTypeSize.isAccessibilitySize
            )
        case .contractions:
            StatPage(
                symbol: "waveform.path.ecg", target: recap.contractions,
                format: { Self.number($0) },
                line: L10n.birthContractionsLine(recap.contractions),
                animates: animates, compactArt: dynamicTypeSize.isAccessibilitySize
            )
        case .appointments:
            StatPage(
                symbol: "stethoscope", target: recap.appointments,
                format: { Self.number($0) },
                line: L10n.birthAppointmentsLine(recap.appointments),
                animates: animates, compactArt: dynamicTypeSize.isAccessibilitySize
            )
        case .weight:
            StatPage(
                symbol: "scalemass.fill", target: nil,
                fixedText: Self.weightText(recap.weightChangeKg ?? 0, spoken: false),
                spokenText: Self.weightText(recap.weightChangeKg ?? 0, spoken: true),
                format: { _ in "" },
                line: L10n.birthWeightLine,
                animates: animates, compactArt: dynamicTypeSize.isAccessibilitySize
            )
        case .thanks: thanksPage
        }
    }

    /// "+11,5 kg"; a change that rounds to zero is "0,0 kg", never "+0,0 kg".
    private static func weightText(_ kg: Double, spoken: Bool) -> String {
        let rounded = (kg * 10).rounded() / 10
        return Formatting.kilograms(rounded, signed: rounded != 0, spoken: spoken)
    }

    private static func number(_ value: Int) -> String {
        value.formatted(.number.locale(Formatting.locale))
    }

    private var celebrationPage: some View {
        VStack(spacing: 22) {
            HeroArt(week: recap.artworkWeek ?? 40, animates: animates, compact: dynamicTypeSize.isAccessibilitySize)
            VStack(spacing: 10) {
                Text(L10n.birthCelebrationTitle)
                    .font(.luna(.display))
                    .foregroundStyle(.luna(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.pregnancyEndOpener(.birth))
                    .font(.luna(.articleBody))
                    .foregroundStyle(.luna(.articleText))
                Text(L10n.birthCelebrationDate(Formatting.dayMonthYear(recap.birthDate)))
                    .font(.luna(.bodyStrong))
                    .foregroundStyle(.luna(.cycleText))
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
        }
    }

    private var journeyPage: some View {
        let weeks = recap.weeks ?? 0
        return VStack(spacing: 22) {
            VStack(spacing: 6) {
                CountUpText(target: weeks, animates: animates) { L10n.birthJourneyWeeks($0) }
                    .font(.luna(size: 56, weight: .bold, relativeTo: .largeTitle))
                    .foregroundStyle(.luna(.cycleText))
                if let days = recap.days {
                    Text(L10n.birthJourneyDays(days))
                        .font(.luna(.cardTitle))
                        .foregroundStyle(.luna(.textSecondary))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([L10n.birthJourneyWeeks(weeks), recap.days.map(L10n.birthJourneyDays)].compactMap { $0 }.joined(separator: " "))
            JourneyStrip(weeks: recap.journeyWeeks, animates: animates)
        }
    }

    private var thanksPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 44 : 72))
                .foregroundStyle(.luna(.cycle))
                .accessibilityHidden(true)
            Text(L10n.birthThanks)
                .font(.luna(.sheetTitle))
                .foregroundStyle(.luna(.textPrimary))
            if recap.keptAsMemory {
                Text(L10n.birthThanksSaved)
                    .font(.luna(.body))
                    .foregroundStyle(.luna(.textSecondary))
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("birthCelebrationThanks")
    }
}

// MARK: - Pieces

/// The baby's art in a glowing circle: bounces in, then breathes slowly.
private struct HeroArt: View {
    let week: Int
    let animates: Bool
    let compact: Bool
    @State private var arrived = false
    @State private var breathing = false

    var body: some View {
        let side: CGFloat = compact ? 150 : 250
        WeekArtwork.fetus(week)
            .resizable()
            .scaledToFit()
            .padding(side * 0.08)
            .frame(width: side, height: side)
            .background(
                RadialGradient(
                    stops: [
                        .init(color: .luna(.fetusGlowInner), location: 0),
                        .init(color: .luna(.fetusGlowOuter), location: 0.6),
                        .init(color: .luna(.fetusGlowEdge), location: 0.71),
                    ],
                    center: .center, startRadius: 0, endRadius: side / 2 * 2.0.squareRoot()
                )
                .clipShape(Circle())
            )
            .scaleEffect(arrived ? (breathing ? 1.04 : 1) : 0.4)
            .opacity(arrived ? 1 : 0)
            .onAppear {
                guard animates else {
                    arrived = true
                    return
                }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.55)) { arrived = true }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true).delay(0.8)) { breathing = true }
            }
            .accessibilityHidden(true)
    }
}

/// A number that counts up to `target` (at once without motion).
private struct CountUpText: View {
    let target: Int
    let animates: Bool
    let text: (Int) -> String
    @State private var shown: Int?

    var body: some View {
        Text(text(shown ?? (animates ? 0 : target)))
            .monospacedDigit()
            .task {
                guard animates, shown == nil else { return }
                let steps = 30
                for step in 0...steps {
                    // Ease-out: fast at first, settling on the final number.
                    let progress = 1 - pow(1 - Double(step) / Double(steps), 3)
                    shown = Int((Double(target) * progress).rounded())
                    try? await Task.sleep(for: .milliseconds(30))
                }
                shown = target
            }
    }
}

/// One big number (or text), an icon and a warm line.
private struct StatPage: View {
    let symbol: String
    let target: Int?
    var fixedText: String?
    var spokenText: String?
    let format: (Int) -> String
    let line: String
    let animates: Bool
    let compactArt: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: compactArt ? 28 : 40, weight: .semibold))
                .foregroundStyle(.luna(.cycleOnSoft))
                .frame(width: compactArt ? 64 : 96, height: compactArt ? 64 : 96)
                .background(.luna(.card), in: Circle())
                .overlay { Circle().strokeBorder(.luna(.cycleSoftBorder), lineWidth: 2) }
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Group {
                    if let target {
                        CountUpText(target: target, animates: animates, text: format)
                    } else {
                        Text(fixedText ?? "")
                    }
                }
                .font(.luna(size: 64, weight: .bold, relativeTo: .largeTitle))
                .foregroundStyle(.luna(.cycleText))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                Text(line)
                    .font(.luna(.cardTitle))
                    .foregroundStyle(.luna(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(target.map(format) ?? spokenText ?? fixedText ?? "") \(line)")
        }
    }
}

/// The growth strip: the fruit of each sampled week, appearing one after another.
private struct JourneyStrip: View {
    let weeks: [Int]
    let animates: Bool
    @State private var shown = 0

    var body: some View {
        // Centred while it fits, scrolling sideways when it does not.
        ViewThatFits(in: .horizontal) {
            strip
            ScrollView(.horizontal, showsIndicators: false) { strip }
        }
        .task {
            guard animates else {
                shown = weeks.count
                return
            }
            for _ in weeks {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { shown += 1 }
            }
        }
    }

    private var strip: some View {
            HStack(spacing: 14) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { position, week in
                    VStack(spacing: 6) {
                        (WeekArtwork.fruit(week) ?? WeekArtwork.fetus(week))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .padding(10)
                            .background(.luna(.card), in: Circle())
                            .overlay { Circle().strokeBorder(.luna(.cycleSoftBorder), lineWidth: 1.5) }
                        Text(L10n.birthJourneyWeekLabel(week))
                            .font(.luna(.label))
                            .foregroundStyle(.luna(.textSecondary))
                            .fixedSize()
                    }
                    .opacity(position < shown ? 1 : 0)
                    .scaleEffect(position < shown ? 1 : 0.6)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
    }
}
