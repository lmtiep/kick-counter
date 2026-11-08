import SwiftUI

/// Paper, hearts and stars falling (handoff "Pháo giấy"): 22 particles, each
/// falling linearly from above the top to past the bottom in 9–14 s, drifting
/// ±60 pt and turning ±360°, fading in over the first 8 % and out over the last
/// 15 %. One `Canvas` in a `TimelineView`, capped at 60 fps. `isStill` (Reduce
/// Motion, UI tests) draws nothing, as the handoff asks.
struct ConfettiView: View {
    /// 1 on the celebration, thanks and summary pages, 0.3 on the numbers.
    var intensity: Double
    var isStill: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date()

    private struct Particle {
        enum Shape { case paper, heart, star }
        let x: Double          // 0...1 across the width
        let duration: Double   // seconds per fall
        let delay: Double      // seconds before the first fall
        let width: Double
        let height: Double
        let drift: Double      // pt, -60...60
        let turn: Double       // degrees per fall, -360...360
        let shape: Shape
        let color: Int
    }

    /// A fixed scatter: the same on every launch.
    private static let particles: [Particle] = {
        var generator = SeededGenerator(seed: 0x4C554E41)
        return (0..<22).map { _ in
            let roll = Double.random(in: 0..<1, using: &generator)
            let shape: Particle.Shape = roll < 0.5 ? .paper : roll < 0.8 ? .heart : .star
            let side = Double.random(in: 12...20, using: &generator)
            return Particle(
                x: .random(in: 0...1, using: &generator),
                duration: .random(in: 9...14, using: &generator),
                delay: .random(in: 0...12, using: &generator),
                width: shape == .paper ? .random(in: 6...11, using: &generator) : side,
                height: shape == .paper ? .random(in: 9...15, using: &generator) : side,
                drift: .random(in: -60...60, using: &generator),
                turn: .random(in: -360...360, using: &generator),
                shape: shape,
                color: .random(in: 0..<5, using: &generator)
            )
        }
    }()

    var body: some View {
        if !isStill {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                canvas(elapsed: timeline.date.timeIntervalSince(start))
            }
            .opacity(intensity)
            .animation(.easeInOut(duration: 0.8), value: intensity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func canvas(elapsed: Double) -> some View {
        let colors = CelebrationPalette.confetti(colorScheme)
        return Canvas { context, size in
            let heart = context.resolve(Image(systemName: "heart.fill"))
            let star = context.resolve(Image(systemName: "sparkle"))
            for particle in Self.particles where elapsed > particle.delay {
                let progress = ((elapsed - particle.delay) / particle.duration).truncatingRemainder(dividingBy: 1)
                var layer = context
                layer.opacity = max(0, min(1, progress / 0.08, (1 - progress) / 0.15))
                layer.translateBy(
                    x: particle.x * size.width + particle.drift * progress,
                    y: -30 + progress * (size.height + 60)
                )
                layer.rotate(by: .degrees(particle.turn * progress))
                let color = colors[particle.color % colors.count]
                let rect = CGRect(x: -particle.width / 2, y: -particle.height / 2, width: particle.width, height: particle.height)
                switch particle.shape {
                case .paper:
                    layer.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                case .heart:
                    var image = heart
                    image.shading = .color(color)
                    layer.draw(image, in: rect)
                case .star:
                    var image = star
                    image.shading = .color(color)
                    layer.draw(image, in: rect)
                }
            }
        }
    }
}

/// A small deterministic generator (SplitMix64).
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
