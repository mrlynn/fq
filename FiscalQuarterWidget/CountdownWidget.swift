import AppIntents
import SwiftUI
import WidgetKit

@main
struct FiscalQuarterWidgets: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
    }
}

/// Days left in the quarter, half, or fiscal year, for the desktop, the Home Screen, and the Lock Screen.
///
/// Each widget picks a calendar: yours from the app, one of your saved calendars, the built-in one,
/// or a start date. The app and the widget share settings through the App Group in `SharedSettings`.
struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Countdown", intent: CountdownIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fiscal countdown")
        .description("Time left in the quarter, half, or fiscal year.")
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

    static var parameterSummary: some ParameterSummary {
        Switch(\.$calendar) {
            Case(.startDate) {
                Summary("Count \(\.$unit) to the end of the \(\.$target)") {
                    \.$calendar
                    \.$startMonth
                    \.$startDay
                    \.$label
                }
            }
            Case(.saved) {
                Summary("Count \(\.$unit) to the end of the \(\.$target)") {
                    \.$calendar
                    \.$saved
                    \.$label
                }
            }
            DefaultCase {
                Summary("Count \(\.$unit) to the end of the \(\.$target)") {
                    \.$calendar
                    \.$label
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

struct CountdownEntry: TimelineEntry {
    let date: Date
    let snapshot: QuarterSnapshot
    let target: CountdownTarget
    let unit: CountdownUnit
    let label: String?

    var countdown: Countdown { snapshot.countdown(to: target) }
}

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
        return Timeline(entries: dates.map { entry(at: $0, for: configuration) }, policy: .atEnd)
    }

    private func entry(at date: Date, for configuration: CountdownIntent) -> CountdownEntry {
        let resolved = configuration.resolve(from: SharedSettings.store)
        let typed = configuration.label?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CountdownEntry(
            date: date,
            snapshot: QuarterSnapshot(on: CalendarDate(date, calendar: .current), calendar: resolved.definition),
            target: configuration.target,
            unit: configuration.unit,
            label: typed?.isEmpty == false ? typed : resolved.name
        )
    }
}

// MARK: Views

enum WidgetColor {
    static let green = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)
    static let warning = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)

    static func tint(for countdown: Countdown) -> Color {
        countdown.days <= 14 ? warning : green
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            CircularCountdown(entry: entry)
        case .accessoryRectangular:
            RectangularCountdown(entry: entry)
        case .accessoryInline:
            Text("\(entry.countdown.label) · \(entry.countdown.short(in: entry.unit))")
        #endif
        case .systemMedium:
            MediumCountdown(entry: entry)
        default:
            SmallCountdown(entry: entry)
        }
    }
}

/// The big number, its unit, and how far through the period today is.
struct SmallCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        let countdown = entry.countdown
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.label ?? countdown.label)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            if entry.label != nil {
                Text(countdown.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(BigNumber.text(countdown, entry.unit))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(countdown.days <= 14 ? WidgetColor.warning : Color.primary)
            Text(BigNumber.caption(countdown, entry.unit))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            ProgressBar(fraction: countdown.fractionComplete, tint: WidgetColor.tint(for: countdown))
            Text("Ends \(ShortDate.text(countdown.end))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

/// The chosen countdown on the left. On the right, quarter, half, and year side by side,
/// each with its own progress, because they start on different days even when they end together.
struct MediumCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SmallCountdown(entry: entry)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entry.snapshot.countdowns, id: \.target) { countdown in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(countdown.label)
                                .font(.system(size: 12, weight: countdown.target == entry.target ? .semibold : .regular))
                            Spacer(minLength: 4)
                            Text(countdown.short(in: entry.unit))
                                .font(.system(size: 12))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        ProgressBar(fraction: countdown.fractionComplete, tint: WidgetColor.tint(for: countdown))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if os(iOS)
struct CircularCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        let countdown = entry.countdown
        Gauge(value: countdown.fractionComplete) {
            Text(countdown.label)
        } currentValueLabel: {
            Text("\(countdown.value(in: entry.unit))")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }
}

struct RectangularCountdown: View {
    let entry: CountdownEntry

    var body: some View {
        let countdown = entry.countdown
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.label.map { "\($0) · \(countdown.label)" } ?? countdown.label)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text("\(countdown.phrase(in: entry.unit)) left")
                .lineLimit(1)
            ProgressBar(fraction: countdown.fractionComplete, tint: .primary)
                .widgetAccentable()
        }
    }
}
#endif

/// How much of the period is behind us. Drawn rather than a ProgressView so the tint always applies.
struct ProgressBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, proxy.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("\(Int((fraction * 100).rounded())) percent through")
    }
}

enum BigNumber {
    static func text(_ countdown: Countdown, _ unit: CountdownUnit) -> String {
        unit == .weeks ? countdown.short(in: .weeks) : "\(countdown.value(in: unit))"
    }

    static func caption(_ countdown: Countdown, _ unit: CountdownUnit) -> String {
        let value = countdown.value(in: unit)
        switch unit {
        case .days: return value == 1 ? "day left" : "days left"
        case .workdays: return value == 1 ? "workday left" : "workdays left"
        case .weeks: return "left"
        case .weekends: return value == 1 ? "weekend left" : "weekends left"
        }
    }
}

enum ShortDate {
    /// `Dec 31`.
    static func text(_ date: CalendarDate) -> String {
        "\(FiscalMonth.symbol(for: date.month)) \(date.day)"
    }
}
