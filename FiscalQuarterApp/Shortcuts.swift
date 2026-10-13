import AppIntents
import Foundation

// Actions for Shortcuts, Siri, and Spotlight, on the Mac and iPhone. Each reads the shared
// settings, so it answers with the calendar, workdays, and milestones set in the app.

/// Your calendar and workweek as the app has them, or a saved calendar in their place.
private struct Settings {
    let calendar: FiscalCalendarDefinition
    let name: String?
    let workweek: Workweek
    let today: CalendarDate

    init(saved: SavedCalendarEntity? = nil, now: Date = Date()) {
        let store = SharedSettings.store
        let yours = FiscalYearConfig.load(from: store).definition
        let match = saved.flatMap { entity in SavedCalendars.load(from: store).first { $0.id.uuidString == entity.id } }
        calendar = match?.definition ?? yours
        name = match?.name
        workweek = Workweek.load(from: store)
        today = CalendarDate(now, calendar: .current)
    }
}

struct FiscalQuarterIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Fiscal Quarter"
    static var description = IntentDescription("Today's fiscal quarter, such as FY26-Q4, with how far through it you are.")

    @Parameter(title: "Calendar", description: "One of your saved calendars. Leave it empty for yours.")
    var calendar: SavedCalendarEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get the fiscal quarter on \(\.$calendar)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let settings = Settings(saved: calendar)
        let snapshot = QuarterSnapshot(on: settings.today, calendar: settings.calendar, workweek: settings.workweek)
        return .result(value: snapshot.quarter.id, dialog: "\(Answers.quarter(snapshot, name: settings.name))")
    }
}

struct TimeLeftIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Time Left"
    static var description = IntentDescription("How long is left in the quarter, half, or fiscal year, in days, workdays, weeks, or weekends.")

    @Parameter(title: "Period", default: .quarter)
    var target: CountdownTarget

    @Parameter(title: "Unit", default: .days)
    var unit: CountdownUnit

    static var parameterSummary: some ParameterSummary {
        Summary("Get the \(\.$unit) left in the \(\.$target)")
    }

    /// The number in the chosen unit. Weeks gives whole weeks.
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let settings = Settings()
        let countdown = QuarterSnapshot(on: settings.today, calendar: settings.calendar, workweek: settings.workweek)
            .countdown(to: target)
        return .result(value: countdown.value(in: unit), dialog: "\(Answers.timeLeft(countdown, unit: unit))")
    }
}

struct QuarterForDateIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Fiscal Quarter for Date"
    static var description = IntentDescription("The fiscal quarter a date falls in, such as FY27-Q1.")

    @Parameter(title: "Date", kind: .date, requestValueDialog: "Which date?")
    var date: Date

    @Parameter(title: "Calendar", description: "One of your saved calendars. Leave it empty for yours.")
    var calendar: SavedCalendarEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get the fiscal quarter of \(\.$date) on \(\.$calendar)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let settings = Settings(saved: calendar)
        let day = CalendarDate(date, calendar: .current)
        let quarter = FiscalCalendar.quarter(containing: day, in: settings.calendar)
        let answer = Answers.quarter(of: day, in: settings.calendar, today: settings.today)
        return .result(value: quarter.id, dialog: "\(answer)")
    }
}

struct NextMilestoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Next Milestone"
    static var description = IntentDescription("When a milestone next falls. Leave the milestone empty for whichever comes soonest.")

    @Parameter(title: "Milestone")
    var milestone: MilestoneEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get the next date of \(\.$milestone)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Date> & ProvidesDialog {
        let settings = Settings()
        let all = Milestones.load(from: SharedSettings.store)
        let chosen = milestone.map { entity in all.filter { $0.id.uuidString == entity.id } } ?? all
        let upcoming = Milestones.upcoming(chosen, onOrAfter: settings.today, in: settings.calendar, workweek: settings.workweek)
        guard let next = upcoming.first else {
            throw ShortcutsError(Answers.noMilestones)
        }
        let components = DateComponents(year: next.date.year, month: next.date.month, day: next.date.day, hour: 12)
        let date = Calendar.current.date(from: components) ?? Date()
        return .result(value: date, dialog: "\(Answers.milestone(next, today: settings.today))")
    }
}

/// A plain sentence for Shortcuts and Siri to show when an action has nothing to answer with.
struct ShortcutsError: Error, CustomLocalizedStringResourceConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var localizedStringResource: LocalizedStringResource { "\(message)" }
}

/// Phrases Siri and Spotlight offer with no setup. Each must name the app.
struct FiscalQuarterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FiscalQuarterIntent(),
            phrases: [
                "What quarter is it in \(.applicationName)",
                "Get the quarter from \(.applicationName)",
                "\(.applicationName) quarter",
            ]
        )
        AppShortcut(
            intent: TimeLeftIntent(),
            phrases: [
                "How long is left in \(.applicationName)",
                "Time left in \(.applicationName)",
                "\(.applicationName) time left",
            ]
        )
        AppShortcut(
            intent: NextMilestoneIntent(),
            phrases: [
                "When is my next milestone in \(.applicationName)",
                "Next milestone in \(.applicationName)",
            ]
        )
    }
}
