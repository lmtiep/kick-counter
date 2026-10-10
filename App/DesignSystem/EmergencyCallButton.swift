import KickCore
import SwiftUI

/// "Gọi cấp cứu 115" on the urgent cards (the kick 2-hour alert, the contraction
/// alerts of phase 20). Vietnamese only: English has no single number, so there
/// the card shows its text alone.
struct EmergencyCallButton: View {
    let identifier: String
    @Environment(\.openURL) private var openURL

    /// Whether the app's language has an emergency number to offer.
    static var isAvailable: Bool { AppLocale.language == .vi }

    var body: some View {
        if Self.isAvailable {
            Button {
                if let url = URL(string: "tel:115") { openURL(url) }
            } label: {
                Label(L10n.counterCall115, systemImage: "phone.fill")
            }
            .buttonStyle(.pill(.filled(.warningButton), fullWidth: false, height: 44))
            .accessibilityIdentifier(identifier)
        }
    }
}
