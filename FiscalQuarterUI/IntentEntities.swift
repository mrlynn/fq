import AppIntents
import Foundation

// Choices shared by the widgets' Edit Widget and the apps' Shortcuts actions.

/// One of the other calendars saved in the app, offered as a choice in Edit Widget and Shortcuts.
struct SavedCalendarEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Saved calendar"
    static var defaultQuery = SavedCalendarQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ calendar: SavedCalendar) {
        id = calendar.id.uuidString
        name = calendar.name
    }
}

struct SavedCalendarQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SavedCalendarEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [SavedCalendarEntity] {
        all()
    }

    private func all() -> [SavedCalendarEntity] {
        SavedCalendars.load(from: SharedSettings.store).map(SavedCalendarEntity.init)
    }
}

/// One of your milestones, offered as a choice in Edit Widget and Shortcuts.
struct MilestoneEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Milestone"
    static var defaultQuery = MilestoneQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(_ milestone: Milestone) {
        id = milestone.id.uuidString
        name = milestone.name
    }
}

struct MilestoneQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MilestoneEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [MilestoneEntity] {
        all()
    }

    private func all() -> [MilestoneEntity] {
        Milestones.load(from: SharedSettings.store).map(MilestoneEntity.init)
    }
}

extension CountdownTarget: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    public static var caseDisplayRepresentations: [CountdownTarget: DisplayRepresentation] = [
        .quarter: "quarter",
        .half: "half",
        .year: "year",
    ]
}

extension CountdownUnit: AppEnum {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Unit"
    public static var caseDisplayRepresentations: [CountdownUnit: DisplayRepresentation] = [
        .days: "days",
        .workdays: "workdays",
        .weeks: "weeks",
        .weekends: "weekends",
    ]
}
