import Foundation

/// A calendar someone added alongside their own, such as a customer's.
public struct SavedCalendar: Equatable, Codable, Identifiable {
    public var id: UUID
    public var definition: FiscalCalendarDefinition

    public init(id: UUID = UUID(), definition: FiscalCalendarDefinition) {
        self.id = id
        self.definition = definition
    }

    public var name: String { definition.name }
}

/// The other calendars, kept in the same defaults suite as `FiscalYearConfig` so `fq` sees them too.
///
/// Each calendar is stored as its own JSON blob. One that no longer decodes is skipped
/// rather than taking the rest of the list with it.
public enum SavedCalendars {
    static let storedKey = "otherCalendars"
    private static var key: String { storedKey }

    public static func load(from defaults: SettingsSource) -> [SavedCalendar] {
        let blobs = defaults.object(forKey: key) as? [Data] ?? []
        return blobs.compactMap { try? JSONDecoder().decode(SavedCalendar.self, from: $0) }
    }

    public static func save(_ calendars: [SavedCalendar], to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        defaults.set(calendars.compactMap { try? encoder.encode($0) }, forKey: key)
    }

    /// The saved calendar called `name`, ignoring case and surrounding spaces.
    public static func named(_ name: String, in calendars: [SavedCalendar]) -> SavedCalendar? {
        let wanted = normalized(name)
        return calendars.first { normalized($0.name) == wanted }
    }

    /// Why `name` cannot be used for a new calendar, or nil when it can.
    /// Names must be unique because `fq --calendar` looks calendars up by name.
    public static func problem(withName name: String, in calendars: [SavedCalendar]) -> String? {
        if normalized(name).isEmpty {
            return "Give the calendar a name."
        }
        if named(name, in: calendars) != nil {
            return "There is already a calendar called \(name.trimmingCharacters(in: .whitespaces))."
        }
        return nil
    }

    private static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension FiscalCalendarDefinition {
    /// One line that says how the calendar is built, for a settings list.
    public var summary: String {
        if eras.count == 1, case .months(let rule) = eras[0].rule {
            return "Starts \(FiscalMonth.symbol(for: rule.startMonth)) \(rule.startDay) every year"
        }
        if eras.count == 1, case .weeks(let rule) = eras[0].rule {
            return rule.summary
        }
        return "\(eras.count) eras, from a file"
    }

    /// The same calendar under another name.
    public func renamed(_ name: String) -> FiscalCalendarDefinition {
        var copy = self
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}
