import Foundation

/// A setting's value in a backup, typed by `BackupSettings.table`.
public enum BackupValue: Equatable, Sendable, Encodable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    /// Written as an ISO 8601 string (the encoder's date strategy).
    case date(Date)

    public var type: BackupSettingType {
        switch self {
        case .bool: .bool
        case .int: .int
        case .double: .double
        case .string: .string
        case .date: .date
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .date(let value): try container.encode(value)
        }
    }
}

public enum BackupSettingType: Sendable {
    case bool, int, double, string, date
}

/// Any JSON value under `settings`, before the table gives it a type. Each reading
/// that succeeds is kept, so the table's type picks the right one; values that are
/// not scalars read as nothing and are dropped.
struct BackupJSONScalar: Decodable {
    var bool: Bool?
    var int: Int?
    var double: Double?
    var string: String?

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.singleValueContainer() else { return }
        bool = try? container.decode(Bool.self)
        int = try? container.decode(Int.self)
        double = try? container.decode(Double.self)
        string = try? container.decode(String.self)
    }
}

/// Which preferences a backup carries, and how they are read and written. The
/// `UserDefaults` types are never guessed: every key has an explicit type.
public enum BackupSettings {
    /// Owned keys a backup never carries: the partner state belongs to one phone,
    /// and restoring always completes onboarding.
    public static let excludedKeys: Set<String> = [
        SettingsKey.partnerSkippedOnboarding,
        SettingsKey.partnerPublishedSnapshot,
        SettingsKey.partnerCachedSnapshot,
        SettingsKey.partnerPendingZoneDeletion,
        SettingsKey.hasCompletedOnboarding,
    ]

    /// `AppDataReset.ownedKeys` minus `excludedKeys` (`BackupSettingsTests` checks it).
    public static let table: [String: BackupSettingType] = [
        SettingsKey.reminderEnabled: .bool,
        SettingsKey.reminderHour: .int,
        SettingsKey.reminderMinute: .int,
        SettingsKey.dueDate: .double,
        SettingsKey.pregnancyDateSource: .string,
        SettingsKey.lmpDate: .double,
        SettingsKey.appMode: .string,
        SettingsKey.previousAppMode: .string,
        SettingsKey.typicalCycleLength: .int,
        SettingsKey.typicalPeriodLength: .int,
        SettingsKey.cycleRemindersEnabled: .bool,
        SettingsKey.cycleGoal: .string,
        SettingsKey.contraception: .string,
        SettingsKey.cycleRegularity: .string,
        SettingsKey.cycleShowsFertilityTests: .bool,
        SettingsKey.appLanguage: .string,
        SettingsKey.kickHapticsEnabled: .bool,
        SettingsKey.maternalPreWeightKg: .double,
        SettingsKey.maternalHeightCm: .double,
        SettingsKey.lastBackupAt: .date,
        SettingsKey.pillReminderEnabled: .bool,
        SettingsKey.pillPackType: .string,
        SettingsKey.pillPackStart: .int,
        SettingsKey.pillReminderHour: .int,
        SettingsKey.pillReminderMinute: .int,
        SettingsKey.contractionEpisodeEndedAt: .date,
    ]

    /// The table's keys that `defaults` holds, read with their table type.
    public static func read(from defaults: UserDefaults) -> [String: BackupValue] {
        var values: [String: BackupValue] = [:]
        for (key, type) in table where defaults.object(forKey: key) != nil {
            switch type {
            case .bool: values[key] = .bool(defaults.bool(forKey: key))
            case .int: values[key] = .int(defaults.integer(forKey: key))
            case .double: values[key] = .double(defaults.double(forKey: key))
            case .string: values[key] = defaults.string(forKey: key).map(BackupValue.string)
            case .date: values[key] = (defaults.object(forKey: key) as? Date).map(BackupValue.date)
            }
        }
        return values
    }

    /// Writes the values whose key is in the table with that key's type; others are ignored.
    public static func write(_ values: [String: BackupValue], to defaults: UserDefaults) {
        for (key, value) in values where table[key] == value.type {
            switch value {
            case .bool(let bool): defaults.set(bool, forKey: key)
            case .int(let int): defaults.set(int, forKey: key)
            case .double(let double): defaults.set(double, forKey: key)
            case .string(let string): defaults.set(string, forKey: key)
            case .date(let date): defaults.set(date, forKey: key)
            }
        }
    }

    /// The preferences half of a restore (spec §4.2 step 2), run only after the
    /// store was replaced: clears every owned key, writes the file's settings and
    /// completes onboarding. The phone's last backup is now the restored file
    /// (`backupCreatedAt`), not the date the file itself remembers.
    public static func restore(_ values: [String: BackupValue], backupCreatedAt: Date, to defaults: UserDefaults) {
        AppDataReset.clearDefaults(defaults)
        var restored = values
        restored[SettingsKey.lastBackupAt] = nil
        write(restored, to: defaults)
        defaults.set(backupCreatedAt, forKey: SettingsKey.lastBackupAt)
        defaults.set(true, forKey: SettingsKey.hasCompletedOnboarding)
    }

    /// Types decoded JSON values by the table; unknown keys and wrong types are dropped.
    static func typed(_ raw: [String: BackupJSONScalar]) -> [String: BackupValue] {
        var values: [String: BackupValue] = [:]
        for (key, scalar) in raw {
            guard let type = table[key] else { continue }
            let value: BackupValue? = switch type {
            case .bool: scalar.bool.map(BackupValue.bool)
            case .int: scalar.int.map(BackupValue.int)
            case .double: scalar.double.map(BackupValue.double)
            case .string: scalar.string.map(BackupValue.string)
            case .date: scalar.string.flatMap(BackupCodec.parseDate).map(BackupValue.date)
            }
            values[key] = value
        }
        return values
    }
}
