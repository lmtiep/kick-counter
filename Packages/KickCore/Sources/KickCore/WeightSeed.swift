import Foundation

/// Sample weights for UI tests and screenshots (`-uiTesting -seedWeights`): the
/// design's `PRE_KG` and `SEED_W`, placed at those weeks of the stored pregnancy.
public enum WeightSeed {
    public static let preWeightKg = 52.0
    public static let heightCm = 160.0
    /// (gestational week, kg) from the prototype.
    public static let samples: [(week: Int, kg: Double)] = [
        (12, 53.1), (16, 54.6), (20, 56.2), (24, 58.0), (27, 59.4), (30, 60.9),
    ]

    public static var profile: MaternalProfile {
        MaternalProfile(preWeightKg: preWeightKg, heightCm: heightCm)
    }

    /// The samples on the first day of their week, leaving out days after today.
    public static func entries(dueDate: Date, today now: Date, calendar: Calendar = .current) -> [WeightRecord] {
        let today = calendar.startOfDay(for: now)
        guard let lmp = calendar.date(
            byAdding: .day, value: -PregnancyTimeline.pregnancyLengthDays, to: calendar.startOfDay(for: dueDate)
        ) else { return [] }
        return samples.compactMap { sample in
            guard let day = calendar.date(byAdding: .day, value: sample.week * 7, to: lmp), day <= today else { return nil }
            return WeightRecord(day: day, kg: sample.kg)
        }
    }
}
