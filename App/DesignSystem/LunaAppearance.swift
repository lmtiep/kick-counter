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
        // Fixed 11 pt: the tab bar has a fixed height, so its labels must not scale.
        let tabFont = UIFont.lunaFixed(size: 11, weight: .semibold)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .selected)
        // #A89890 fails AA on the tab bar (ContrastTests): inactive tabs use textSecondary.
        UITabBar.appearance().unselectedItemTintColor = .luna(.textSecondary)
        // The iOS 26 tab bar ignores UITabBarItem appearance; it reads the item
        // appearances of UITabBarAppearance instead.
        let tabBar = UITabBarAppearance()
        tabBar.configureWithDefaultBackground()
        for item in [tabBar.stackedLayoutAppearance, tabBar.inlineLayoutAppearance, tabBar.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: tabFont, .foregroundColor: UIColor.luna(.textSecondary)]
            item.normal.iconColor = .luna(.textSecondary)
            item.selected.titleTextAttributes = [.font: tabFont]
        }
        UITabBar.appearance().standardAppearance = tabBar
        // scrollEdgeAppearance stays unset so iOS 17/18 keeps the transparent scroll-edge bar.

        let navigation = UINavigationBar.appearance()
        navigation.titleTextAttributes = [
            .font: UIFont.luna(size: 17, weight: .semibold, textStyle: .headline, maximumPointSize: 22),
            .foregroundColor: UIColor.luna(.textPrimary),
        ]
        navigation.largeTitleTextAttributes = [
            .font: UIFont.luna(size: 28, weight: .bold, textStyle: .largeTitle, maximumPointSize: 40),
            .foregroundColor: UIColor.luna(.textPrimary),
        ]

        let segmented = UISegmentedControl.appearance()
        // Light: a white segment on the tinted track; dark: the pink accent with plum text.
        segmented.selectedSegmentTintColor = .luna(.segmentSelected)
        segmented.backgroundColor = .luna(.surfaceAlt)
        // Capped: segments share one line, so accessibility sizes would truncate every label.
        let segmentFont = UIFont.luna(size: 13, weight: .semibold, textStyle: .footnote, maximumPointSize: 21)
        segmented.setTitleTextAttributes([
            .font: segmentFont,
            .foregroundColor: UIColor.luna(.textPrimary),
        ], for: .normal)
        segmented.setTitleTextAttributes([
            .font: segmentFont,
            .foregroundColor: UIColor.luna(.onSegmentSelected),
        ], for: .selected)
    }
}
