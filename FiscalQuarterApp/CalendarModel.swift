import Combine
import Foundation
import WidgetKit

/// Your calendar setting and the other saved calendars, shared by the Mac panel and the iOS app.
final class CalendarModel: ObservableObject {
    @Published private(set) var config: FiscalYearConfig
    @Published private(set) var others: [SavedCalendar]

    init() {
        SharedSettings.migrateIfNeeded()
        config = FiscalYearConfig.load(from: FiscalYearConfig.store)
        others = SavedCalendars.load(from: FiscalYearConfig.store)
        // Widgets keep the timeline they built before an update. Rebuilding on launch means a new
        // version's calendar rules reach them as soon as the app opens.
        WidgetCenter.shared.reloadAllTimelines()
    }

    func set(_ config: FiscalYearConfig) {
        self.config = config
        config.save(to: FiscalYearConfig.store)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Adds `definition` under `name`. Returns why it could not be added, or nil.
    @discardableResult
    func add(_ definition: FiscalCalendarDefinition, named name: String) -> String? {
        if let problem = SavedCalendars.problem(withName: name, in: others) {
            return problem
        }
        others.append(SavedCalendar(definition: definition.renamed(name)))
        SavedCalendars.save(others, to: FiscalYearConfig.store)
        WidgetCenter.shared.reloadAllTimelines()
        return nil
    }

    func remove(_ calendar: SavedCalendar) {
        others.removeAll { $0.id == calendar.id }
        SavedCalendars.save(others, to: FiscalYearConfig.store)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
