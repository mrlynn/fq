import Foundation

/// Which fiscal calendar to use. `.builtIn` is the calendar year, numbered by that year.
/// `.custom` starts a new year on `startMonth`/`startDay` and names it for the calendar year it ends in.
/// `.weeks` is a 52/53-week year by `weekRule`, such as a 4-4-5 retail calendar.
public struct FiscalYearConfig: Equatable, Codable {
    public enum Kind: String, Codable {
        case builtIn
        case custom
        case weeks
    }

    public var kind: Kind
    public var startMonth: Int
    public var startDay: Int
    /// Kept while another kind is chosen, so switching back restores it.
    public var weekRule: WeekRule

    public init(kind: Kind, startMonth: Int, startDay: Int, weekRule: WeekRule = .retail) {
        self.kind = kind
        self.startMonth = min(12, max(1, startMonth))
        self.startDay = min(31, max(1, startDay))
        self.weekRule = weekRule
    }

    public static let builtIn = FiscalYearConfig(kind: .builtIn, startMonth: 1, startDay: 1)

    /// The calendar this setting describes.
    public var definition: FiscalCalendarDefinition {
        switch kind {
        case .builtIn:
            return .builtIn
        case .custom:
            return .months(startMonth: startMonth, startDay: startDay)
        case .weeks:
            return .weeks(weekRule)
        }
    }

    /// The shared settings. See `SharedSettings` for who can write them.
    public static var store: UserDefaults {
        SharedSettings.store
    }

    static let storedKeys = [Keys.kind, Keys.month, Keys.day, Keys.weekRule]

    public static func load(from defaults: SettingsSource) -> FiscalYearConfig {
        let kind = Kind(rawValue: defaults.object(forKey: Keys.kind) as? String ?? "") ?? .builtIn
        let month = defaults.object(forKey: Keys.month) as? Int ?? 1
        let day = defaults.object(forKey: Keys.day) as? Int ?? 1
        let weekRule = (defaults.object(forKey: Keys.weekRule) as? Data)
            .flatMap { try? JSONDecoder().decode(WeekRule.self, from: $0) } ?? .retail
        return FiscalYearConfig(kind: kind, startMonth: month, startDay: day, weekRule: weekRule)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(kind.rawValue, forKey: Keys.kind)
        defaults.set(startMonth, forKey: Keys.month)
        defaults.set(startDay, forKey: Keys.day)
        defaults.set(try? JSONEncoder().encode(weekRule), forKey: Keys.weekRule)
    }

    /// Longest day-of-month the start control should offer. February allows 29.
    public static func lastDay(of month: Int) -> Int {
        switch month {
        case 2:
            return 29
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }

    private enum Keys {
        static let kind = "fiscalYearKind"
        static let month = "fiscalStartMonth"
        static let day = "fiscalStartDay"
        static let weekRule = "fiscalWeekRule"
    }
}
