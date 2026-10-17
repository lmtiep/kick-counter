import Foundation

/// Which emergency call the urgent cards offer (the kick 2-hour alert, the contraction
/// alerts). 115 is Vietnam's ambulance number: it is offered only where it works, on a
/// device whose region is Vietnam, whatever the app's language. Elsewhere the card asks
/// the user to call the local emergency number, without a button.
public enum EmergencyNumber {
    public static let vietnam = "115"

    /// `regionIdentifier`: the device region, `Locale.current.region?.identifier`.
    public static func offersVietnamCall(regionIdentifier: String?) -> Bool {
        regionIdentifier == "VN"
    }
}
