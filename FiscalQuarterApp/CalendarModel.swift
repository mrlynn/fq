import Combine
import Foundation

/// Your calendar setting and the other saved calendars, shared by the Mac panel and the iOS app.
final class CalendarModel: ObservableObject {
    @Published private(set) var config: FiscalYearConfig
    @Published private(set) var others: [SavedCalendar]

    init() {
        config = FiscalYearConfig.load(from: FiscalYearConfig.store)
        others = SavedCalendars.load(from: FiscalYearConfig.store)
    }

    func set(_ config: FiscalYearConfig) {
        self.config = config
        config.save(to: FiscalYearConfig.store)
    }

    /// Adds `definition` under `name`. Returns why it could not be added, or nil.
    @discardableResult
    func add(_ definition: FiscalCalendarDefinition, named name: String) -> String? {
        if let problem = SavedCalendars.problem(withName: name, in: others) {
            return problem
        }
        others.append(SavedCalendar(definition: definition.renamed(name)))
        SavedCalendars.save(others, to: FiscalYearConfig.store)
        return nil
    }

    func remove(_ calendar: SavedCalendar) {
        others.removeAll { $0.id == calendar.id }
        SavedCalendars.save(others, to: FiscalYearConfig.store)
    }
}
