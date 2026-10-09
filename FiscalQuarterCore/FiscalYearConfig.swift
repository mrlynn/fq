import Foundation

/// Which fiscal calendar to use. `.builtIn` is the February calendar with the FY27 transition.
/// `.custom` starts a new year on `startMonth`/`startDay` and names it for the calendar year it ends in.
public struct FiscalYearConfig: Equatable, Codable {
    public enum Kind: String, Codable {
        case builtIn
        case custom
    }

    public var kind: Kind
    public var startMonth: Int
    public var startDay: Int

    public init(kind: Kind, startMonth: Int, startDay: Int) {
        self.kind = kind
        self.startMonth = min(12, max(1, startMonth))
        self.startDay = min(31, max(1, startDay))
    }

    public static let builtIn = FiscalYearConfig(kind: .builtIn, startMonth: 2, startDay: 1)

    public static let suiteName = "local.fiscalquarter"

    public static var store: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public static func load(from defaults: UserDefaults) -> FiscalYearConfig {
        let kind = Kind(rawValue: defaults.string(forKey: Keys.kind) ?? "") ?? .builtIn
        let month = defaults.object(forKey: Keys.month) as? Int ?? 2
        let day = defaults.object(forKey: Keys.day) as? Int ?? 1
        return FiscalYearConfig(kind: kind, startMonth: month, startDay: day)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(kind.rawValue, forKey: Keys.kind)
        defaults.set(startMonth, forKey: Keys.month)
        defaults.set(startDay, forKey: Keys.day)
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
    }
}
