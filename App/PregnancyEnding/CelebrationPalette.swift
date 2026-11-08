import SwiftUI

/// The birth celebration's own colours (handoff "Màu"): light and dark follow the
/// device, unlike onboarding. Kept local because no other screen uses them.
enum CelebrationPalette {
    enum Token {
        case disc, moon, ink, ink2, accent, onAccent, num, card, line, track, statDisc
    }

    static func color(_ token: Token, _ scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        return switch token {
        case .disc: dark ? hex(0x5A3B4B) : hex(0xF9D6DE)
        case .moon: dark ? hex(0xF6E4C8) : hex(0xFFF1DA)
        case .ink: dark ? hex(0xFBF1EC) : hex(0x3B2A2E)
        case .ink2: dark ? hex(0xDCC6C6) : hex(0x7A6266)
        case .accent: hex(0xF2A7B6)
        case .onAccent: hex(0x3B1F2B)
        case .num: dark ? hex(0xF7BAC6) : hex(0xC24F69)
        case .card: dark ? .white.opacity(0.07) : .white
        case .line: dark ? .white.opacity(0.14) : hex(0x3B2A2E).opacity(0.09)
        case .track: dark ? .white.opacity(0.10) : hex(0xFCEDE8)
        // The art's thin plum lines need a light disc in both themes.
        case .statDisc: hex(0xF9D6DE)
        }
    }

    static func background(_ scheme: ColorScheme) -> LinearGradient {
        let stops: [Gradient.Stop] = scheme == .dark
            ? [.init(color: hex(0x3E2B36), location: 0), .init(color: hex(0x34242F), location: 0.55), .init(color: hex(0x2A1D26), location: 1)]
            : [.init(color: hex(0xFFF8F1), location: 0), .init(color: hex(0xFDF1EB), location: 0.6), .init(color: hex(0xFBE9E6), location: 1)]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    static func confetti(_ scheme: ColorScheme) -> [Color] {
        (scheme == .dark
            ? [0xF2A7B6, 0xF6C59E, 0xF6E4C8, 0xB9D8C6, 0xE58CA1]
            : [0xF2A7B6, 0xF5C49C, 0xF3D9A4, 0xAFD3BE, 0xE8899B]
        ).map(hex)
    }

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
