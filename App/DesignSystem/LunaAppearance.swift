import KickCore
import UIKit

/// UIKit parts SwiftUI can't style directly: tab bar labels, navigation bar
/// titles and segmented controls use Be Vietnam Pro and the palette.
@MainActor
enum LunaAppearance {
    static func configure() {
        #if DEBUG
        // Fails the first UI test on CI when a font is missing from UIAppFonts (project.yml).
        for weight in LunaWeight.allCases {
            assert(UIFont(name: weight.rawValue, size: 12) != nil, "Missing font \(weight.rawValue)")
        }
        #endif
        let tabFont = UIFont.luna(size: 11, weight: .semibold, textStyle: .caption2)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .selected)
        // #A89890 fails AA on the tab bar (ContrastTests): inactive tabs use textSecondary.
        UITabBar.appearance().unselectedItemTintColor = .luna(.textSecondary)

        let navigation = UINavigationBar.appearance()
        navigation.titleTextAttributes = [
            .font: UIFont.luna(size: 17, weight: .semibold, textStyle: .headline),
            .foregroundColor: UIColor.luna(.textPrimary),
        ]
        navigation.largeTitleTextAttributes = [
            .font: UIFont.luna(size: 28, weight: .bold, textStyle: .largeTitle),
            .foregroundColor: UIColor.luna(.textPrimary),
        ]

        let segmented = UISegmentedControl.appearance()
        segmented.selectedSegmentTintColor = .luna(.card)
        segmented.backgroundColor = .luna(.surfaceAlt)
        segmented.setTitleTextAttributes([
            .font: UIFont.luna(size: 13, weight: .semibold, textStyle: .footnote),
            .foregroundColor: UIColor.luna(.textPrimary),
        ], for: .normal)
    }
}
