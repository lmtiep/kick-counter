import KickCore
import SwiftUI

/// "Gọi cấp cứu 115" on the urgent cards (the kick 2-hour alert, the contraction
/// alerts of phase 20). 115 is Vietnam's number, so the button shows only on a device
/// whose region is Vietnam, whatever the app's language; elsewhere a plain line asks
/// the user to call the local emergency number (`identifier` + "Local").
struct EmergencyCallButton: View {
    let identifier: String
    @Environment(\.openURL) private var openURL

    /// Whether the device's region has the number the button dials.
    static var isAvailable: Bool {
        EmergencyNumber.offersVietnamCall(regionIdentifier: Locale.current.region?.identifier)
    }

    var body: some View {
        if Self.isAvailable {
            Button {
                if let url = URL(string: "tel:\(EmergencyNumber.vietnam)") { openURL(url) }
            } label: {
                Label(L10n.counterCall115, systemImage: "phone.fill")
            }
            .buttonStyle(.pill(.filled(.warningButton), fullWidth: false, height: 44))
            .accessibilityIdentifier(identifier)
        } else {
            Label(L10n.counterCallLocalEmergency, systemImage: "phone.fill")
                .font(.luna(.bodyStrong))
                .foregroundStyle(.luna(.articleText))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(identifier + "Local")
        }
    }
}
