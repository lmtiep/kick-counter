import Foundation
import KickCore

/// Every date, number and unit on screen, in the language chosen in the app
/// (`AppLocale`), not the device's: vi "4 tháng 10", "36,5 °C"; en "Oct 4", "36.5 °C".
enum Formatting {
    static var locale: Locale { AppLocale.locale }

    /// e.g. "23 min", "1 hr, 5 min", "45 sec".
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2).locale(locale))
    }

    /// Whole minutes: "22 min" / "22 phút".
    static func minutes(_ minutes: Double) -> String {
        L10n.minutes(Int(minutes.rounded()))
    }

    /// Day and month in the locale's order: "04/10" (vi) / "10/04" (en).
    static func cycleDate(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(locale))
    }

    /// For VoiceOver: "October 4" / "4 tháng 10".
    static func spokenDay(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).locale(locale))
    }

    /// Headers and cards (README): "4 tháng 10" / "Oct 4".
    static func shortDay(_ date: Date) -> String {
        AppLocale.language == .vi
            ? spokenDay(date)
            : date.formatted(.dateTime.month(.abbreviated).day().locale(locale))
    }

    /// "T5, 1 tháng 10" / "Thu, Oct 1".
    static func weekdayDay(_ date: Date) -> String {
        "\(WeekdayLabel.short(for: date, calendar: AppLocale.calendar)), \(shortDay(date))"
    }

    /// The day of the month alone: "4".
    static func dayNumber(_ date: Date) -> String {
        date.formatted(.dateTime.day().locale(locale))
    }

    /// "4/10/2026" / "Oct 4, 2026".
    static func dayMonthYear(_ date: Date) -> String {
        AppLocale.language == .vi
            ? date.formatted(.dateTime.day().month(.defaultDigits).year().locale(locale))
            : date.formatted(.dateTime.month(.abbreviated).day().year().locale(locale))
    }

    /// "Tháng 10 năm 2026" / "October 2026".
    static func monthYear(_ date: Date) -> String {
        let text = date.formatted(.dateTime.month(.wide).year().locale(locale))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "18 thg 10" / "Oct 18" (the pill card's break week).
    static func dayShortMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    /// "20:05" / "8:05 PM".
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    /// A reminder time from its stored hour and minute.
    static func clockTime(hour: Int, minute: Int) -> String {
        time(Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now)
    }

    /// "June 7, 2027" / "ngày 7 tháng 6, 2027".
    static func longDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))
    }

    /// Partner mode: "10 minutes ago" / "10 phút trước".
    /// Only past moments are shown, so a clock ahead on the mother's iPhone
    /// reads "now" rather than "in 2 minutes".
    static func relative(_ date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }

    /// Appointments: "Oct 20, 2026 at 2:30 PM".
    static func dateTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    /// "36.5 °C" / "36,5 °C".
    static func temperature(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1...2)))
                .locale(locale)
        )
    }

    /// Crown–rump length, e.g. "53.5 mm" / "53,5 mm"; `spoken` spells the unit out for VoiceOver.
    static func crownRumpLength(mm: Double, spoken: Bool = false) -> String {
        Measurement(value: mm, unit: UnitLength.millimeters).formatted(
            .measurement(width: spoken ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
                .locale(locale)
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
            : grams.formatted(.number.locale(locale))
    }

    /// `grams` with a unit, in the unit `weight(grams: reference)` uses.
    static func weightInUnit(_ grams: Int, unitOf reference: Int, spoken: Bool = false) -> String {
        let width: Measurement<UnitMass>.FormatStyle.UnitWidth = spoken ? .wide : .abbreviated
        if reference >= 1000 {
            return Measurement(value: Double(grams) / 1000, unit: UnitMass.kilograms).formatted(
                .measurement(width: width, usage: .asProvided, numberFormatStyle: kilogramDigits).locale(locale)
            )
        }
        return Measurement(value: Double(grams), unit: UnitMass.grams).formatted(
            .measurement(width: width, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
                .locale(locale)
        )
    }

    /// The mother's weight: "58.0 kg" / "58,0 kg"; `signed` writes gains as
    /// "+6.0 kg" / "−0.4 kg"; `spoken` spells the unit out for VoiceOver.
    static func kilograms(_ kg: Double, signed: Bool = false, spoken: Bool = false) -> String {
        let digits = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
            .sign(strategy: signed ? .always() : .automatic)
            .locale(locale)
        return Measurement(value: kg, unit: UnitMass.kilograms).formatted(
            .measurement(width: spoken ? .wide : .abbreviated, usage: .asProvided, numberFormatStyle: digits).locale(locale)
        )
    }

    /// Height: "160 cm" / "158,5 cm".
    static func centimeters(_ cm: Double) -> String {
        Measurement(value: cm, unit: UnitLength.centimeters).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1)))
                .locale(locale)
        )
    }

    /// One decimal, e.g. a BMI: "20.3" / "20,3".
    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }

    private static var kilogramDigits: FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(1)).locale(locale)
    }
}
