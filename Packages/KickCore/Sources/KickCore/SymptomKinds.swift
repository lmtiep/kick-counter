import Foundation

/// Menstrual flow logged for a day (spec §2.1), lightest first: merging two
/// logs of the same day keeps the heavier one. Logging flow never starts a period.
public enum MenstrualFlow: String, Sendable, CaseIterable, Comparable {
    /// Stored as "none". Not named `none`, which would be ambiguous with
    /// `Optional.none` wherever a `MenstrualFlow?` is compared.
    case noFlow = "none"
    case light
    case medium
    case heavy

    public static func < (lhs: MenstrualFlow, rhs: MenstrualFlow) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .noFlow: 0
        case .light: 1
        case .medium: 2
        case .heavy: 3
        }
    }
}

public enum Mood: String, Sendable, CaseIterable {
    case happy
    case calm
    case sensitive
    case anxious
    case tired
}

/// Symptoms of both modes in one list (spec §2.1). The UI shows only the
/// current mode's; the other mode's stay stored untouched.
public enum Symptom: String, Sendable, CaseIterable {
    // Trying to conceive
    case cramps
    case headache
    case tenderBreasts
    case acne
    case bloating
    case cravings
    // Pregnant
    case nausea
    case heartburn
    case swollenFeet
    case backPain
    case legCramps
    case insomnia
    case contractions

    public var mode: AppMode {
        switch self {
        case .cramps, .headache, .tenderBreasts, .acne, .bloating, .cravings: .tryingToConceive
        case .nausea, .heartburn, .swollenFeet, .backPain, .legCramps, .insomnia, .contractions: .pregnant
        }
    }

    /// The chips shown in that mode, in display order.
    public static func cases(for mode: AppMode) -> [Symptom] {
        allCases.filter { $0.mode == mode }
    }

    /// Contractions and swollen feet show the "when to get care" card (spec §3.2).
    public var needsSafetyNote: Bool {
        self == .contractions || self == .swollenFeet
    }

    public static func needsSafetyNote(_ symptoms: some Sequence<Symptom>) -> Bool {
        symptoms.contains { $0.needsSafetyNote }
    }
}

/// The comma-separated lists stored in `CycleLog.moodsRaw` / `symptomsRaw`:
/// stable English raw values in enum order. Values this build does not know
/// (synced from a newer version) are returned separately so they can be written
/// back unchanged.
public enum RawList {
    public static func decode<Value>(_ raw: String?) -> (known: [Value], unknown: [String])
    where Value: RawRepresentable & CaseIterable & Equatable, Value.RawValue == String {
        let tokens = (raw ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let known = Value.allCases.filter { tokens.contains($0.rawValue) }
        var unknown: [String] = []
        for token in tokens where Value(rawValue: token) == nil && !unknown.contains(token) {
            unknown.append(token)
        }
        return (known, unknown)
    }

    /// nil when both lists are empty (the attribute stays unset).
    public static func encode<Value>(_ known: [Value], unknown: [String]) -> String?
    where Value: RawRepresentable & CaseIterable & Equatable, Value.RawValue == String {
        let parts = Value.allCases.filter(known.contains).map(\.rawValue) + unknown
        return parts.isEmpty ? nil : parts.joined(separator: ",")
    }

    /// Enum order without repeats, e.g. for a merge or a sheet's selection.
    public static func ordered<Value>(_ values: some Sequence<Value>) -> [Value]
    where Value: CaseIterable & Equatable {
        let present = Array(values)
        return Value.allCases.filter(present.contains)
    }
}
