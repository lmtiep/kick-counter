import SwiftUI
import UIKit

/// Be Vietnam Pro (SIL OFL, `App/Fonts/OFL.txt`), registered through
/// `UIAppFonts` in `project.yml`. The raw values are the PostScript names.
enum LunaWeight: String, CaseIterable {
    case light = "BeVietnamPro-Light"
    case regular = "BeVietnamPro-Regular"
    case medium = "BeVietnamPro-Medium"
    case semibold = "BeVietnamPro-SemiBold"
    case bold = "BeVietnamPro-Bold"
}

/// The design's type scale (README "Typography"). Every style grows with
/// Dynamic Type through `relativeTo`.
enum LunaTextStyle {
    case kickCount        // 72/700 — number on the kick dial
    case doneCount        // 60/700 — dial when 10 is reached
    case ringNumber       // 52/700 — "16 days" in the cycle ring
    case display          // 32/700 — "24 weeks, 3 days"
    case averageFigure    // 30/700 — history average
    case screenTitle      // 28/700
    case weekTitle        // 26/700 — week detail headline
    case sheetTitle       // 22/700
    case statFigure       // 19/700 — Coming up card figures
    case figure           // 18/700 — week detail figures
    case cardTitle        // 16/600
    case cardTitleSmall   // 15/600
    case articleBody      // 15/400 — week detail paragraphs
    case button           // 15/600
    case bodyStrong       // 14/600
    case bodyMedium       // 14/500
    case body             // 14/400
    case captionStrong    // 13/600
    case captionMedium    // 13/500
    case caption          // 13/400
    case label            // 12/600 — uppercase labels, chips
    case small            // 12/400 — legends, sub-lines
    case tiny             // 11/600 — weekday names, tab labels

    var size: CGFloat {
        switch self {
        case .kickCount: 72
        case .doneCount: 60
        case .ringNumber: 52
        case .display: 32
        case .averageFigure: 30
        case .screenTitle: 28
        case .weekTitle: 26
        case .sheetTitle: 22
        case .statFigure: 19
        case .figure: 18
        case .cardTitle: 16
        case .cardTitleSmall, .articleBody, .button: 15
        case .bodyStrong, .bodyMedium, .body: 14
        case .captionStrong, .captionMedium, .caption: 13
        case .label, .small: 12
        case .tiny: 11
        }
    }

    var weight: LunaWeight {
        switch self {
        case .kickCount, .doneCount, .ringNumber, .display, .averageFigure, .screenTitle, .weekTitle,
             .sheetTitle, .statFigure, .figure:
            .bold
        case .cardTitle, .cardTitleSmall, .button, .bodyStrong, .captionStrong, .label, .tiny:
            .semibold
        case .bodyMedium, .captionMedium:
            .medium
        case .articleBody, .body, .caption, .small:
            .regular
        }
    }

    var relativeTo: Font.TextStyle {
        switch self {
        case .kickCount, .doneCount, .ringNumber, .display: .largeTitle
        case .averageFigure, .screenTitle, .weekTitle: .title
        case .sheetTitle: .title2
        case .statFigure, .figure: .title3
        case .cardTitle: .headline
        case .cardTitleSmall: .subheadline
        case .articleBody, .button, .bodyStrong, .bodyMedium, .body: .body
        case .captionStrong, .captionMedium, .caption: .footnote
        case .label, .small: .caption
        case .tiny: .caption2
        }
    }
}

extension Font {
    static func luna(_ style: LunaTextStyle) -> Font {
        .custom(style.weight.rawValue, size: style.size, relativeTo: style.relativeTo)
    }

    /// For the few one-off sizes of the design (e.g. 22/500 on the due-date picker).
    static func luna(size: CGFloat, weight: LunaWeight, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}

extension UIFont {
    /// Be Vietnam Pro for UIKit appearances (navigation bar, segmented control),
    /// scaled with Dynamic Type like `textStyle`, up to `maximumPointSize` when given.
    static func luna(
        size: CGFloat,
        weight: LunaWeight,
        textStyle: UIFont.TextStyle,
        maximumPointSize: CGFloat? = nil
    ) -> UIFont {
        let base = lunaFixed(size: size, weight: weight)
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        if let maximumPointSize {
            return metrics.scaledFont(for: base, maximumPointSize: maximumPointSize)
        }
        return metrics.scaledFont(for: base)
    }

    /// Be Vietnam Pro at a fixed size (tab bar labels, which UIKit lays out in a
    /// fixed-height bar and must not grow with Dynamic Type).
    static func lunaFixed(size: CGFloat, weight: LunaWeight) -> UIFont {
        UIFont(name: weight.rawValue, size: size) ?? .systemFont(ofSize: size)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        Text(verbatim: "52 ngày").font(.luna(.ringNumber))
        Text(verbatim: "24 tuần, 3 ngày").font(.luna(.display))
        Text(verbatim: "Dự đoán sắp tới").font(.luna(.cardTitle))
        Text(verbatim: "Ghi que thử, nhiệt độ, dịch nhầy").font(.luna(.body))
        Text(verbatim: "KỲ KINH TIẾP THEO").font(.luna(.label))
    }
    .padding()
}
