import AppIntents
import SwiftUI
import WidgetKit

@main
struct FiscalQuarterWidgets: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
    }
}

/// Days left in the quarter, half, or fiscal year, or to one of your milestones, for the desktop,
/// the Home Screen, and the Lock Screen.
///
/// Each widget picks a calendar: yours from the app, one of your saved calendars, the built-in one,
/// or a start date. The app and the widget share settings through the App Group in `SharedSettings`.
struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Countdown", intent: CountdownIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    CountdownBackground(entry: entry)
                }
        }
        .configurationDisplayName("Fiscal countdown")
        .description("Time left in the quarter, half, or fiscal year, or to a milestone.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }
}

// MARK: Configuration

struct CountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Fiscal countdown"
    static var description = IntentDescription("Choose what to count down to and which fiscal calendar to use.")

    @Parameter(title: "Count to", default: .quarter)
    var target: CountdownTarget

    @Parameter(title: "Count in", default: .days)
    var unit: CountdownUnit

    @Parameter(title: "Calendar", default: .yours)
    var calendar: CalendarChoice

    @Parameter(title: "Saved calendar")
    var saved: SavedCalendarEntity?

    @Parameter(title: "Year starts in", default: .january)
    var startMonth: StartMonth

    @Parameter(title: "On day", default: 1, inclusiveRange: (1, 31))
    var startDay: Int

    @Parameter(title: "Label")
    var label: String?

    /// Counts to this milestone instead of the period. Milestones run on your calendar.
    @Parameter(title: "Milestone")
    var milestone: MilestoneEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$milestone, .hasAnyValue) {
            Summary("Count \(\.$unit) to \(\.$milestone)") {
                \.$label
            }
        } otherwise: {
            Switch(\.$calendar) {
                Case(.startDate) {
                    Summary("Count \(\.$unit) to the end of the \(\.$target)") {
                        \.$calendar
                        \.$startMonth
                        \.$startDay
                        \.$label
                        \.$milestone
                    }
                }
                Case(.saved) {
                    Summary("Count \(\.$unit) to the end of the \(\.$target)") {
                        \.$calendar
                        \.$saved
                        \.$label
                        \.$milestone
                    }
                }
                DefaultCase {
                    Summary("Count \(\.$unit) to the end of the \(\.$target)") {
                        \.$calendar
                        \.$label
                        \.$milestone
                    }
                }
            }
        }
    }

    /// The calendar to count with, and the name to show when no label was typed.
    /// A saved calendar that has since been removed falls back to yours.
    func resolve(from settings: SettingsSource) -> (definition: FiscalCalendarDefinition, name: String?) {
        switch calendar {
        case .yours:
            return (FiscalYearConfig.load(from: settings).definition, nil)
        case .saved:
            let calendars = SavedCalendars.load(from: settings)
            if let id = saved?.id, let match = calendars.first(where: { $0.id.uuidString == id }) {
                return (match.definition, match.name)
            }
            return (FiscalYearConfig.load(from: settings).definition, nil)
        case .builtIn:
            return (.builtIn, nil)
        case .startDate:
            let month = startMonth.number
            return (.months(startMonth: month, startDay: min(startDay, FiscalYearConfig.lastDay(of: month))), nil)
        }
    }
}

enum CalendarChoice: String, AppEnum {
    case yours
    case saved
    case builtIn
    case startDate

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
    static var caseDisplayRepresentations: [CalendarChoice: DisplayRepresentation] = [
        .yours: "Yours",
        .saved: "A saved calendar",
        .builtIn: "Built-in",
        .startDate: "Starts on a date",
    ]
}

/// One of the other calendars saved in the app, offered as a choice in Edit Widget.
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

/// One of your milestones, offered as a choice in Edit Widget.
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

enum StartMonth: String, AppEnum, CaseIterable {
    case january, february, march, april, may, june, july, august, september, october, november, december

    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Month"
    static var caseDisplayRepresentations: [StartMonth: DisplayRepresentation] = [
        .january: "January", .february: "February", .march: "March", .april: "April",
        .may: "May", .june: "June", .july: "July", .august: "August",
        .september: "September", .october: "October", .november: "November", .december: "December",
    ]
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

// MARK: Timeline

/// One entry now and one at each of the next seven local midnights, then a fresh timeline.
struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        entry(at: Date(), for: CountdownIntent())
    }

    func snapshot(for configuration: CountdownIntent, in context: Context) async -> CountdownEntry {
        entry(at: Date(), for: configuration)
    }

    func timeline(for configuration: CountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let calendar = Calendar.current
        let now = Date()
        var dates = [now]
        var midnight = calendar.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            dates.append(next)
            midnight = next
        }
        // Read the appearance and its picture once, not once per entry.
        let look = Look.current()
        return Timeline(entries: dates.map { entry(at: $0, for: configuration, look: look) }, policy: .atEnd)
    }

    private func entry(at date: Date, for configuration: CountdownIntent, look: Look = .current()) -> CountdownEntry {
        let settings = SharedSettings.store
        let today = CalendarDate(date, calendar: .current)
        let typed = configuration.label?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = typed?.isEmpty == false ? typed : nil

        // A milestone runs on your calendar, whatever calendar the widget was set to.
        // One that has since been removed falls back to the period.
        if let id = configuration.milestone?.id,
           let milestone = Milestones.load(from: settings).first(where: { $0.id.uuidString == id }) {
            let yours = FiscalYearConfig.load(from: settings).definition
            if let occurrence = milestone.next(onOrAfter: today, in: yours) {
                return CountdownEntry(
                    date: date,
                    snapshot: QuarterSnapshot(on: today, calendar: yours),
                    target: configuration.target,
                    unit: configuration.unit,
                    label: label,
                    appearance: look.appearance,
                    backgroundImage: look.image,
                    milestone: occurrence.countdown(from: today)
                )
            }
        }

        let resolved = configuration.resolve(from: settings)
        return CountdownEntry(
            date: date,
            snapshot: QuarterSnapshot(on: today, calendar: resolved.definition),
            target: configuration.target,
            unit: configuration.unit,
            label: label ?? resolved.name,
            appearance: look.appearance,
            backgroundImage: look.image
        )
    }

    /// The shared appearance, with its background picture when it has one.
    private struct Look {
        let appearance: Appearance
        let image: CGImage?

        static func current() -> Look {
            let appearance = Appearance.load(from: SharedSettings.store)
            return Look(appearance: appearance, image: appearance.imageFile.flatMap(BackgroundImageStore.load))
        }
    }
}
