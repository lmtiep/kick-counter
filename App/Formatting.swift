import Foundation

enum Formatting {
    /// e.g. "23 min", "1 hr, 5 min", "45 sec" — localized by the system.
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }

    /// Day and month in the locale's order: "04/10" (vi) / "10/04" (en).
    static func cycleDate(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }

    /// For VoiceOver: "October 4" / "4 tháng 10".
    static func spokenDay(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide))
    }

    /// "36.5 °C" / "36,5 °C".
    static func temperature(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1...2)))
        )
    }

    /// Crown–rump length, e.g. "53.5 mm" / "53,5 mm"; `spoken` spells the unit out for VoiceOver.
    static func crownRumpLength(mm: Double, spoken: Bool = false) -> String {
        Measurement(value: mm, unit: UnitLength.millimeters).formatted(
            .measurement(width: spoken ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
        )
    }

    /// Grams below 1 kg ("600 g"), kilograms with one decimal from 1 kg ("3.6 kg" / "3,6 kg").
    static func weight(grams: Int, spoken: Bool = false) -> String {
        weightInUnit(grams, unitOf: grams, spoken: spoken)
    }

    /// A weight range in the unit `weight(grams: reference)` uses, unit written once:
    /// "275–387 g", "758–1,068 g", "3.0–4.2 kg". Word joiners around the dash and a
    /// no-break space before the unit keep the range on one line when the text wraps.
    static func weightRange(_ low: Int, _ high: Int, unitOf reference: Int) -> String {
        let end = weightInUnit(high, unitOf: reference).replacingOccurrences(of: " ", with: "\u{00A0}")
        return "\(weightRangeStart(low, unitOf: reference))\u{2060}–\u{2060}\(end)"
    }

    /// The bare number that starts a range, e.g. "275" or "3.0" (kg).
    static func weightRangeStart(_ grams: Int, unitOf reference: Int) -> String {
        reference >= 1000
            ? (Double(grams) / 1000).formatted(kilogramDigits)
            : grams.formatted(.number)
    }

    /// `grams` with a unit, in the unit `weight(grams: reference)` uses.
    static func weightInUnit(_ grams: Int, unitOf reference: Int, spoken: Bool = false) -> String {
        let width: Measurement<UnitMass>.FormatStyle.UnitWidth = spoken ? .wide : .abbreviated
        if reference >= 1000 {
            return Measurement(value: Double(grams) / 1000, unit: UnitMass.kilograms).formatted(
                .measurement(width: width, usage: .asProvided, numberFormatStyle: kilogramDigits)
            )
        }
        return Measurement(value: Double(grams), unit: UnitMass.grams).formatted(
            .measurement(width: width, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
        )
    }

    private static var kilogramDigits: FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(1))
    }
}
