import KickCore
import SwiftUI

/// The page behind every main screen and sheet (phase 18, handoff §3): the flat
/// `background` colour in light mode, the indigo gradient in dark mode
/// (`linear-gradient(165deg, top 0 %, middle 45 %, bottom 100 %)`).
///
/// The handoff's decorative glows are left out: they lighten the top of the
/// gradient, where the contrast of glass cards is already tightest
/// (`LunaContrast.backdrops`).
struct LunaBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                stops: [
                    .init(color: .luna(.backgroundTop), location: 0),
                    .init(color: .luna(.background), location: 0.45),
                    .init(color: .luna(.backgroundBottom), location: 1),
                ],
                // 165°: towards the bottom, slightly to the right.
                startPoint: UnitPoint(x: 0.37, y: 0),
                endPoint: UnitPoint(x: 0.63, y: 1)
            )
            .ignoresSafeArea()
        } else {
            Color.luna(.background).ignoresSafeArea()
        }
    }
}

extension View {
    /// Fills the whole screen behind this view with `LunaBackground`.
    func lunaBackground() -> some View {
        background { LunaBackground() }
    }
}

#Preview {
    VStack(spacing: 12) {
        Text(verbatim: "Dự đoán sắp tới").font(.luna(.cardTitle)).lunaCard()
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .lunaBackground()
    .preferredColorScheme(.dark)
}
