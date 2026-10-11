import Combine
import CoreGraphics
import Foundation
import WidgetKit

/// Your calendar setting and the other saved calendars, shared by the Mac panel and the iOS app.
final class CalendarModel: ObservableObject {
    @Published private(set) var config: FiscalYearConfig
    @Published private(set) var others: [SavedCalendar]
    @Published private(set) var appearance: Appearance
    /// The picture for an image background, loaded once when the appearance changes.
    @Published private(set) var backgroundImage: CGImage?

    init() {
        SharedSettings.migrateIfNeeded()
        config = FiscalYearConfig.load(from: FiscalYearConfig.store)
        others = SavedCalendars.load(from: FiscalYearConfig.store)
        appearance = Appearance.load(from: FiscalYearConfig.store)
        backgroundImage = appearance.imageFile.flatMap(BackgroundImageStore.load)
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

    /// Saves the look for the app and the widgets. Pictures the new look no longer uses are deleted.
    func setAppearance(_ appearance: Appearance) {
        guard appearance != self.appearance else { return }
        self.appearance = appearance
        backgroundImage = appearance.imageFile.flatMap(BackgroundImageStore.load)
        appearance.save(to: FiscalYearConfig.store)
        BackgroundImageStore.removeAll(except: appearance.imageFile)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func remove(_ calendar: SavedCalendar) {
        others.removeAll { $0.id == calendar.id }
        SavedCalendars.save(others, to: FiscalYearConfig.store)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
