import KickCore
import SwiftUI
import UIKit

/// Luna tokens and Be Vietnam Pro for the widget (the app's `LunaColor`/`LunaFont`
/// live in the app target). Colours follow light and dark like the app's.
enum WidgetStyle {
    static func color(_ token: LunaToken) -> Color {
        let pair = LunaPalette.pair(token)
        return Color(uiColor: UIColor(dynamicProvider: { traits in
            let hex = traits.userInterfaceStyle == .dark ? pair.dark : pair.light
            return UIColor(red: hex.red, green: hex.green, blue: hex.blue, alpha: hex.alpha)
        }))
    }

    enum Weight: String {
        case regular = "BeVietnamPro-Regular"
        case medium = "BeVietnamPro-Medium"
        case semibold = "BeVietnamPro-SemiBold"
        case bold = "BeVietnamPro-Bold"
    }

    static func font(_ size: CGFloat, _ weight: Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

extension ShapeStyle where Self == Color {
    static func luna(_ token: LunaToken) -> Color { WidgetStyle.color(token) }
}

/// The widget's page: flat cream in light mode, the indigo gradient in dark mode
/// (the same as the app's `LunaBackground`).
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                stops: [
                    .init(color: .luna(.backgroundTop), location: 0),
                    .init(color: .luna(.background), location: 0.45),
                    .init(color: .luna(.backgroundBottom), location: 1),
                ],
                startPoint: UnitPoint(x: 0.37, y: 0),
                endPoint: UnitPoint(x: 0.63, y: 1)
            )
        } else {
            Color.luna(.background)
        }
    }
}
