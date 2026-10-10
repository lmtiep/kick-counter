import SwiftUI

extension View {
    /// Keeps scrolled content out from under the status bar: a zero-height top
    /// inset whose background fills the top safe area with the screen colour
    /// (the top of the dark-mode gradient, `backgroundTop`).
    /// Apply to the `ScrollView`/`List` of a screen whose header scrolls away.
    func lunaStatusBarBackdrop() -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(Color.luna(.backgroundTop).ignoresSafeArea(edges: .top))
                .accessibilityHidden(true)
        }
    }
}
