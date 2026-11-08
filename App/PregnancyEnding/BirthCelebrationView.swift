import KickCore
import SwiftUI
import UIKit

/// The full-screen moment after "Bé đã chào đời" (celebration art spec §3, the
/// Claude Design handoff): Stories-style pages with a progress bar that moves on
/// by itself every 6 s. A tap on the right half goes on, on the left half back;
/// holding pauses; ✕ closes from every page. While VoiceOver runs (and in UI
/// tests) nothing moves on by itself and "Tiếp" shows on every page but the last.
struct BirthCelebrationView: View {
    let recap: PregnancyRecap
    /// The success haptic belongs to the moment of birth, not to a replay.
    var playsHaptic = true
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorScheme) private var scheme
    @State private var index = 0
    @State private var progress = 0.0
    @State private var paused = false

    static let pageDuration = 6.0

    private var animates: Bool { LunaMotion.isEnabled && !reduceMotion }
    private var autoAdvances: Bool { LunaMotion.isEnabled && !voiceOver }
    private var pages: [PregnancyRecap.Page] { recap.pages }
    private var page: PregnancyRecap.Page { pages[min(index, pages.count - 1)] }
    private var isLast: Bool { index >= pages.count - 1 }

    var body: some View {
        ZStack(alignment: .top) {
            CelebrationPalette.background(scheme).ignoresSafeArea()
            ConfettiView(intensity: page.isQuiet ? 0.3 : 1, isStill: !animates)
                .ignoresSafeArea()
            content
                .id(index)
                .transition(pageTransition)
            chrome
        }
        .animation(pageAnimation, value: index)
        .task(id: TimerKey(index: index, paused: paused, running: autoAdvances)) { await runTimer() }
        // VoiceOver follows to the new page instead of staying on a button of the old one.
        .onChange(of: index) { UIAccessibility.post(notification: .screenChanged, argument: nil) }
        .onAppear {
            if playsHaptic { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Chrome

    private var chrome: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(pages.indices, id: \.self) { segment in
                    let fill = segment < index ? 1 : segment > index ? 0 : (autoAdvances ? progress : 1)
                    GeometryReader { bar in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(.track))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color(.accent))
                                    .frame(width: bar.size.width * fill)
                            }
                    }
                    .frame(height: 4)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.birthPage(index + 1, of: pages.count))
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color(.ink))
                    .frame(width: 44, height: 44)
                    .background(color(.card), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.commonClose)
            .accessibilityIdentifier("birthCelebrationClose")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Paging

    private struct TimerKey: Equatable {
        let index: Int
        let paused: Bool
        let running: Bool
    }

    /// Fills the current segment linearly; when full, moves on (the last page stays).
    private func runTimer() async {
        guard autoAdvances, !paused else { return }
        let tick = 0.05
        while progress < 1 {
            try? await Task.sleep(for: .seconds(tick))
            if Task.isCancelled { return }
            progress = min(1, progress + tick / Self.pageDuration)
        }
        if !isLast { advance() }
    }

    private var pageAnimation: Animation? {
        guard LunaMotion.isEnabled else { return nil }
        return reduceMotion ? .easeInOut(duration: 0.24) : CelebrationMotion.page
    }

    private var pageTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .offset(x: 28).combined(with: .opacity),
            removal: .offset(x: -28).combined(with: .scale(scale: 0.98)).combined(with: .opacity)
        )
    }

    private func advance() {
        guard !isLast else { return }
        progress = 0
        index += 1
    }

    private func goBack() {
        progress = 0
        if index > 0 { index -= 1 }
    }

    // MARK: - Pages

    private var content: some View {
        GeometryReader { proxy in
            ScrollView {
                CelebrationPage(
                    page: page, recap: recap, animates: animates, availableHeight: proxy.size.height,
                    showsNext: !isLast && (page == .celebration || page == .thanks || !autoAdvances),
                    onNext: advance, onDone: onClose
                )
                .padding(.horizontal, page == .summary ? 20 : 24)
                // Room for the progress bar and ✕ above.
                .padding(.top, 60)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                .contentShape(Rectangle())
                // Buttons inside win over these: a tap on one is not a page tap.
                .onTapGesture(coordinateSpace: .local) { location in
                    location.x < proxy.size.width / 2 ? goBack() : advance()
                }
                .onLongPressGesture(minimumDuration: 0.25) {
                    paused = true
                } onPressingChanged: { pressing in
                    if !pressing { paused = false }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func color(_ token: CelebrationPalette.Token) -> Color { CelebrationPalette.color(token, scheme) }
}

/// The handoff's curves and timings.
enum CelebrationMotion {
    static let page = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.52)
    static let art = Animation.spring(response: 0.6, dampingFraction: 0.62)
    static let breathe = Animation.easeInOut(duration: 4.8).repeatForever(autoreverses: true)
    static func text(delay: Double) -> Animation { .timingCurve(0.22, 1, 0.36, 1, duration: 0.6).delay(delay) }
    static func button(delay: Double) -> Animation { .easeOut(duration: 0.5).delay(delay) }
    static let countUp = 1.4
}

extension PregnancyRecap.Page {
    /// The number pages: confetti drops to 30 %.
    var isQuiet: Bool { ![.celebration, .thanks, .summary].contains(self) }
}
