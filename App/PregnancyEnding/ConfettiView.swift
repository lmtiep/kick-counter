import KickCore
import SwiftUI

/// Confetti, hearts and stars falling in the Luna palette (birth celebration
/// spec §5). Drawn with one `Canvas` inside a `TimelineView`, so it stays at 60 fps
/// with a few dozen particles. With `isStill` (Reduce Motion, UI tests) it draws one
/// frame of the same scatter and the timeline does not run.
struct ConfettiView: View {
    var isStill: Bool

    private struct Particle {
        enum Shape { case rectangle, heart, star, dot }
        let x: Double          // 0...1 across the width
        let speed: Double      // screens per second
        let offset: Double     // start position along the fall, 0...1
        let size: Double
        let sway: Double
        let phase: Double
        let spin: Double
        let shape: Shape
        let color: LunaToken
    }

    private static let palette: [LunaToken] = [.cycle, .cycleStrong, .fertile, .preg, .pregBar, .teal, .cycleSoftBorder]

    /// A fixed pseudo-random scatter: the same on every launch, so screenshots are stable.
    private static let particles: [Particle] = {
        var generator = SeededGenerator(seed: 0x4C554E41)
        let shapes: [Particle.Shape] = [.rectangle, .rectangle, .rectangle, .heart, .star, .dot]
        return (0..<44).map { index in
            Particle(
                x: .random(in: 0...1, using: &generator),
                speed: .random(in: 0.09...0.2, using: &generator),
                offset: .random(in: 0...1, using: &generator),
                size: .random(in: 8...16, using: &generator),
                sway: .random(in: 6...22, using: &generator),
                phase: .random(in: 0...(2 * .pi), using: &generator),
                spin: .random(in: -3...3, using: &generator),
                shape: shapes[index % shapes.count],
                color: palette[index % palette.count]
            )
        }
    }()

    var body: some View {
        if isStill {
            canvas(time: 4)
        } else {
            TimelineView(.animation) { timeline in
                canvas(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func canvas(time: Double) -> some View {
        Canvas { context, size in
            let heart = context.resolve(Image(systemName: "heart.fill"))
            let star = context.resolve(Image(systemName: "star.fill"))
            for particle in Self.particles {
                let fall = (time * particle.speed + particle.offset).truncatingRemainder(dividingBy: 1.15)
                let y = fall * (size.height + 60) - 30
                let x = particle.x * size.width + sin(time * 1.4 + particle.phase) * particle.sway
                let side = particle.size
                var layer = context
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .radians(time * particle.spin + particle.phase))
                let color = Color.luna(particle.color)
                let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side * 0.6)
                switch particle.shape {
                case .rectangle:
                    layer.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                case .dot:
                    layer.fill(Path(ellipseIn: CGRect(x: -side / 3, y: -side / 3, width: side * 0.66, height: side * 0.66)), with: .color(color))
                case .heart:
                    var image = heart
                    image.shading = .color(color)
                    layer.draw(image, in: CGRect(x: -side * 0.7, y: -side * 0.7, width: side * 1.4, height: side * 1.4))
                case .star:
                    var image = star
                    image.shading = .color(color)
                    layer.draw(image, in: CGRect(x: -side * 0.7, y: -side * 0.7, width: side * 1.4, height: side * 1.4))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
