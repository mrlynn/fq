import Combine
import CoreGraphics
import Foundation
import WidgetKit

/// Your calendar setting and the other saved calendars, shared by the Mac panel and the iOS app.
final class CalendarModel: ObservableObject {
    @Published private(set) var config: FiscalYearConfig
    @Published private(set) var others: [SavedCalendar]
    /// Dates that come around every quarter on your calendar, in the order they were added.
    @Published private(set) var milestones: [Milestone]
    /// Which days count as workdays: weekdays, less a country's holidays and your days off.
    @Published private(set) var workweek: Workweek
    /// Which notifications to send. All start off.
    @Published private(set) var reminders: ReminderSettings
    @Published private(set) var appearance: Appearance
    /// The picture for an image background, loaded once when the appearance changes.
    @Published private(set) var backgroundImage: CGImage?

    init() {
        SharedSettings.migrateIfNeeded()
        config = FiscalYearConfig.load(from: FiscalYearConfig.store)
        others = SavedCalendars.load(from: FiscalYearConfig.store)
        milestones = Milestones.load(from: FiscalYearConfig.store)
        reminders = ReminderSettings.load(from: FiscalYearConfig.store)
        workweek = Workweek.load(from: FiscalYearConfig.store)
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

    /// Adds `milestone`, or replaces the one with its id. Returns why it could not be saved, or nil.
    @discardableResult
    func save(_ milestone: Milestone) -> String? {
        var milestone = milestone
        milestone.name = milestone.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let problem = milestone.problem {
            return problem
        }
        if let index = milestones.firstIndex(where: { $0.id == milestone.id }) {
            milestones[index] = milestone
        } else {
            milestones.append(milestone)
        }
        Milestones.save(milestones, to: FiscalYearConfig.store)
        WidgetCenter.shared.reloadAllTimelines()
        return nil
    }

    func remove(_ milestone: Milestone) {
        milestones.removeAll { $0.id == milestone.id }
        Milestones.save(milestones, to: FiscalYearConfig.store)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setWorkweek(_ workweek: Workweek) {
        guard workweek != self.workweek else { return }
        self.workweek = workweek
        workweek.save(to: FiscalYearConfig.store)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Today on your calendar, counted with your workweek.
    func snapshot(on today: CalendarDate) -> QuarterSnapshot {
        QuarterSnapshot(on: today, config: config, workweek: workweek)
    }

    func setReminders(_ reminders: ReminderSettings) {
        guard reminders != self.reminders else { return }
        self.reminders = reminders
        reminders.save(to: FiscalYearConfig.store)
    }

    /// Each milestone's next date on or after `today`, soonest first.
    func upcoming(on today: CalendarDate) -> [MilestoneOccurrence] {
        Milestones.upcoming(milestones, onOrAfter: today, in: config.definition, workweek: workweek)
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
