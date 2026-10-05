import KickCore
import SwiftUI
import UIKit

extension LunaHex {
    var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

extension UIColor {
    /// A design token (`KickCore.LunaPalette`) that follows light and dark mode.
    static func luna(_ token: LunaToken) -> UIColor {
        let pair = LunaPalette.pair(token)
        return UIColor(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark ? pair.dark.uiColor : pair.light.uiColor
        })
    }
}

extension ShapeStyle where Self == Color {
    /// The adaptive colour of a design token: `.foregroundStyle(.luna(.textPrimary))`,
    /// `Color.luna(.card)`. Views never use hex values directly.
    static func luna(_ token: LunaToken) -> Color {
        Color(uiColor: .luna(token))
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(LunaToken.allCases, id: \.self) { token in
                HStack {
                    RoundedRectangle(cornerRadius: 6).fill(.luna(token)).frame(width: 44, height: 28)
                    Text(verbatim: token.rawValue).font(.luna(.caption))
                }
            }
        }
        .padding()
    }
    .background(.luna(.background))
}
