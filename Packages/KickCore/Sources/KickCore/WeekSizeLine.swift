import Foundation

/// "Bé lớn cỡ nào?": one sentence built from the week's Hadlock figures, so the
/// numbers always match the reviewed tables (phase 6 spec §4.2). The app passes
/// its localized templates (`L10n`) and number formatters (`Formatting`), which
/// keeps KickCore free of both.
public enum WeekSizeLine {
    /// Format strings with positional `%n$@` arguments.
    public struct Templates: Sendable {
        /// Weeks 7–9: %1$@ crown–rump length, %2$@ size comparison ("cỡ …").
        public var length: String
        /// Weeks 10–13: %1$@ crown–rump length, %2$@ weight, %3$@ weight comparison
        /// ("nặng cỡ …", phase 11: the produce's `typicalGrams` is close to the weight).
        public var lengthAndWeight: String
        /// Weeks 14–42: %1$@ weight, %2$@ low end of the typical range (bare number),
        /// %3$@ high end with its unit, %4$@ weight comparison ("nặng cỡ …").
        public var weightAndRange: String

        public init(length: String, lengthAndWeight: String, weightAndRange: String) {
            self.length = length
            self.lengthAndWeight = lengthAndWeight
            self.weightAndRange = weightAndRange
        }
    }

    /// Number formatters; the app uses display ones for the text and spoken ones
    /// (units spelled out) for VoiceOver.
    public struct Numbers: Sendable {
        public var length: @Sendable (_ millimeters: Double) -> String
        public var weight: @Sendable (_ grams: Int) -> String
        /// The range's low end without a unit, in the unit `weight(reference)` uses.
        public var rangeLow: @Sendable (_ grams: Int, _ reference: Int) -> String
        /// The range's high end with its unit, in the unit `weight(reference)` uses.
        public var rangeHigh: @Sendable (_ grams: Int, _ reference: Int) -> String

        public init(
            length: @escaping @Sendable (Double) -> String,
            weight: @escaping @Sendable (Int) -> String,
            rangeLow: @escaping @Sendable (Int, Int) -> String,
            rangeHigh: @escaping @Sendable (Int, Int) -> String
        ) {
            self.length = length
            self.weight = weight
            self.rangeLow = rangeLow
            self.rangeHigh = rangeHigh
        }
    }

    /// The sentence for `week`, or nil when the week has no figures (weeks 4–6,
    /// where only the article's `sizeNote` is shown). Weeks 41–42 carry week 40's
    /// figures in the data, so they get week 40's numbers with their own comparison.
    public static func make(
        for week: WeekContent,
        language: ContentLanguage,
        templates: Templates,
        numbers: Numbers
    ) -> String? {
        let fruit = week.size.name(language)
        switch (week.crlMm, week.weightG) {
        case let (length?, grams?):
            return String(format: templates.lengthAndWeight, numbers.length(length), numbers.weight(grams), fruit)
        case let (length?, nil):
            return String(format: templates.length, numbers.length(length), fruit)
        case let (nil, grams?):
            guard let low = week.weightP10G, let high = week.weightP90G else { return nil }
            return String(
                format: templates.weightAndRange,
                numbers.weight(grams),
                numbers.rangeLow(low, grams),
                numbers.rangeHigh(high, grams),
                fruit
            )
        case (nil, nil):
            return nil
        }
    }
}
