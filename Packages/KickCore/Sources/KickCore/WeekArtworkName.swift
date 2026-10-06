import Foundation

/// Asset names of the per-week artwork (phase 6 spec §3.2, §4.3). The app falls
/// back to the shared `Fetus` image and the size emoji while an asset is missing.
public enum WeekArtworkName {
    /// "Fetus-W04" … "Fetus-W42".
    public static func fetus(week: Int) -> String { "Fetus-W" + twoDigits(week) }

    /// "Fruit-W04" … "Fruit-W42".
    public static func fruit(week: Int) -> String { "Fruit-W" + twoDigits(week) }

    private static func twoDigits(_ week: Int) -> String {
        week < 10 ? "0\(week)" : "\(week)"
    }
}
