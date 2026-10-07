import KickCore
import SwiftUI
import UIKit

/// Per-week artwork with fallbacks (phase 6 spec §3.2, §4.3): `Fetus-W##` or the
/// shared `Fetus` image; `Fruit-W##` or nil (the caller shows the size emoji).
enum WeekArtwork {
    static func fetus(_ week: Int) -> Image {
        let name = WeekArtworkName.fetus(week: week)
        return UIImage(named: name) == nil ? Image("Fetus") : Image(name)
    }

    static func fruit(_ week: Int) -> Image? {
        let name = WeekArtworkName.fruit(week: week)
        return UIImage(named: name) == nil ? nil : Image(name)
    }
}
