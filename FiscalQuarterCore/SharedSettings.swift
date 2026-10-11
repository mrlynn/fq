import Foundation

/// Where the calendar settings live, so the apps, the widgets, and `fq` all read the same ones.
///
/// The apps and widgets hold the App Group entitlement and use the group's defaults suite.
/// `fq` does not hold it, so it reads the group's preferences file directly and never writes.
///
/// The group ID must match the entitlements generated from `project.yml`. On the Mac it starts with
/// the signing team, which needs no provisioning profile. iOS requires the `group.` form.
public enum SharedSettings {
    #if os(macOS)
    public static let appGroup = "YZ36Z8GSEN.local.fiscalquarter"
    #else
    public static let appGroup = "group.local.fiscalquarter"
    #endif

    /// The suite the settings used before the App Group. On the Mac it is the app's own domain.
    public static let legacySuite = "local.fiscalquarter"

    static let migratedKey = "migratedFromLegacySuite"

    /// Keys that belong to the calendar settings, as opposed to the panel's own preferences.
    static var keys: [String] {
        FiscalYearConfig.storedKeys + [SavedCalendars.storedKey]
    }

    /// The group suite. Use it only from a process that holds the App Group entitlement.
    public static var store: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// The settings from before the App Group. Asking for a suite named after the app's own bundle
    /// identifier returns nil, and then `.standard` is that same domain.
    public static var legacyStore: UserDefaults {
        UserDefaults(suiteName: legacySuite) ?? .standard
    }

    /// Copies the calendar settings from the legacy suite into the group once.
    /// A key the group already has is left alone, and the legacy suite is not changed.
    public static func migrateIfNeeded(from legacy: UserDefaults = legacyStore, to group: UserDefaults = store) {
        guard !group.bool(forKey: migratedKey) else { return }
        for key in keys where group.object(forKey: key) == nil {
            if let value = legacy.object(forKey: key) {
                group.set(value, forKey: key)
            }
        }
        group.set(true, forKey: migratedKey)
    }

    #if os(macOS)
    /// The group's preferences file, where an entitled process's `store` writes.
    public static var groupPreferencesFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/\(appGroup)/Library/Preferences/\(appGroup).plist")
    }

    /// Settings for a process without the entitlement, such as `fq`. Reads the group's file once the
    /// app has moved the settings there, and the legacy suite until then. Nothing is written.
    public static func readOnlySource(file: URL = groupPreferencesFile, fallback: UserDefaults = legacyStore) -> SettingsSource {
        if let data = try? Data(contentsOf: file),
           let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           values[migratedKey] as? Bool == true {
            return SettingsSnapshot(values: values)
        }
        var values: [String: Any] = [:]
        for key in keys {
            values[key] = fallback.object(forKey: key)
        }
        return SettingsSnapshot(values: values)
    }
    #endif
}

/// Anything the settings can be read from: a defaults suite, or a snapshot of a preferences file.
public protocol SettingsSource {
    func object(forKey key: String) -> Any?
}

extension UserDefaults: SettingsSource {}

/// Settings read once from a preferences file.
public struct SettingsSnapshot: SettingsSource {
    let values: [String: Any]

    public init(values: [String: Any]) {
        self.values = values
    }

    public func object(forKey key: String) -> Any? {
        values[key]
    }
}
