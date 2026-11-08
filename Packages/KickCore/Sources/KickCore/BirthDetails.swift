import Foundation

/// What she told about the baby when the birth ended the pregnancy (celebration
/// art spec §1). Every field is optional; out-of-range numbers are left out
/// rather than refused, so asking never blocks the ending.
public struct BirthDetails: Codable, Equatable, Sendable {
    public var name: String?
    /// The birth day at the hour and minute she chose.
    public var time: Date?
    public var weightKg: Double?
    public var lengthCm: Double?

    public static let weightRange = 0.5...7.0
    public static let lengthRange = 25.0...65.0
    static let gramsRange = 500.0...7000.0

    public init(name: String? = nil, time: Date? = nil, weightKg: Double? = nil, lengthCm: Double? = nil) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmed?.isEmpty == false ? trimmed : nil
        self.time = time
        // 500…7000 is a weight in grams ("3200"), as it is often said in Vietnam.
        let kg = weightKg.map { Self.gramsRange.contains($0) ? $0 / 1000 : $0 }
        self.weightKg = kg.flatMap { Self.weightRange.contains($0) ? $0 : nil }
        self.lengthCm = lengthCm.flatMap { Self.lengthRange.contains($0) ? $0 : nil }
    }

    public var isEmpty: Bool { name == nil && time == nil && weightKg == nil && lengthCm == nil }

    /// "3,2" (Vietnamese) or "3.2"; nil for anything else.
    public static func parseDecimal(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, normalized.filter({ $0 == "." }).count <= 1 else { return nil }
        return Double(normalized)
    }
}
