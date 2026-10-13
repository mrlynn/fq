import Foundation

/// Which notifications to send, and when in the day. All of them start off.
///
/// Kept in the App Group beside the calendar settings, so the iOS app can share them later.
public struct ReminderSettings: Equatable, Codable {
    /// Each milestone, as many workdays ahead as it asks for.
    public var milestones: Bool
    /// The day 14 days are left in the quarter, when the countdown turns amber.
    public var lastTwoWeeks: Bool
    /// The first day of each quarter.
    public var newQuarter: Bool
    /// 30 days before the fiscal year ends.
    public var yearEnd: Bool
    /// Local time of day to send them, as hour and minute.
    public var hour: Int
    public var minute: Int

    public init(milestones: Bool = false, lastTwoWeeks: Bool = false, newQuarter: Bool = false, yearEnd: Bool = false, hour: Int = 9, minute: Int = 0) {
        self.milestones = milestones
        self.lastTwoWeeks = lastTwoWeeks
        self.newQuarter = newQuarter
        self.yearEnd = yearEnd
        self.hour = hour
        self.minute = minute
    }

    public static let off = ReminderSettings()

    public var anyOn: Bool {
        milestones || lastTwoWeeks || newQuarter || yearEnd
    }

    static let storedKey = "reminders"

    public static func load(from settings: SettingsSource) -> ReminderSettings {
        guard let data = settings.object(forKey: storedKey) as? Data,
              let reminders = try? JSONDecoder().decode(ReminderSettings.self, from: data)
        else {
            return .off
        }
        return reminders
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.storedKey)
    }
}

/// One notification to send on one day.
public struct PlannedReminder: Equatable {
    /// Stable for the same reminder on the same day, so planning again replaces rather than duplicates.
    public let id: String
    public let date: CalendarDate
    public let title: String
    public let body: String
}

public enum ReminderPlan {
    /// Every identifier starts with this, so the app can clear its own and nothing else.
    public static let idPrefix = "fq."

    /// How far ahead to plan. Planning runs again each day, so this only needs to cover a gap.
    public static let horizon = 30

    /// The reminders that fall from `today` through `horizon` days later, soonest first.
    public static func plan(
        settings: ReminderSettings,
        milestones: [Milestone],
        calendar: FiscalCalendarDefinition,
        today: CalendarDate,
        workweek: Workweek = .weekdays
    ) -> [PlannedReminder] {
        guard settings.anyOn, let last = FiscalCalendar.shift(today, by: horizon) else { return [] }
        var plan: [PlannedReminder] = []

        if settings.milestones {
            for milestone in milestones {
                plan += milestoneReminders(milestone, calendar: calendar, workweek: workweek, from: today, through: last)
            }
        }

        // Quarter and year moments. Walk the quarters that touch the window.
        var quarter = FiscalCalendar.quarter(containing: today, in: calendar)
        while quarter.start <= last {
            if settings.newQuarter, quarter.start >= today {
                let length = FiscalCalendar.inclusiveDays(from: quarter.start, to: quarter.end)
                plan.append(PlannedReminder(
                    id: "\(idPrefix)quarter-start.\(quarter.start.iso)",
                    date: quarter.start,
                    title: "\(quarter.id) starts today",
                    body: "\(length) days, through \(DayWords.short(quarter.end))."
                ))
            }
            if settings.lastTwoWeeks, let day = FiscalCalendar.shift(quarter.end, by: -13), day >= today, day <= last {
                let countdown = Countdown(target: .quarter, label: quarter.id, start: quarter.start, end: quarter.end, today: day, workweek: workweek)
                plan.append(PlannedReminder(
                    id: "\(idPrefix)last-two-weeks.\(day.iso)",
                    date: day,
                    title: "Two weeks left in \(quarter.id)",
                    body: "\(countdown.phrase(in: .workdays)) to \(DayWords.short(quarter.end))."
                ))
            }
            quarter = FiscalCalendar.quarter(after: quarter, in: calendar)
        }

        if settings.yearEnd {
            // The window is shorter than a year, so at most two fiscal years matter.
            var map = FiscalYearMap.containing(today, calendar: calendar)
            for _ in 0..<2 {
                if let day = FiscalCalendar.shift(map.end, by: -29), day >= today, day <= last {
                    let year = "FY\(String(format: "%02d", map.fiscalYear))"
                    let countdown = Countdown(target: .year, label: year, start: map.start, end: map.end, today: day, workweek: workweek)
                    plan.append(PlannedReminder(
                        id: "\(idPrefix)year-end.\(day.iso)",
                        date: day,
                        title: "30 days left in \(year)",
                        body: "\(countdown.phrase(in: .workdays)) to \(DayWords.short(map.end))."
                    ))
                }
                guard let next = FiscalCalendar.day(after: map.end) else { break }
                map = FiscalYearMap.containing(next, calendar: calendar)
            }
        }

        return plan.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    /// A milestone's reminders in the window: each date it falls on, moved earlier by its lead.
    private static func milestoneReminders(_ milestone: Milestone, calendar: FiscalCalendarDefinition, workweek: Workweek, from today: CalendarDate, through last: CalendarDate) -> [PlannedReminder] {
        var reminders: [PlannedReminder] = []
        var cursor = today
        while let occurrence = milestone.next(onOrAfter: cursor, in: calendar, workweek: workweek) {
            let day = Milestone.workdays(milestone.reminderLead, before: occurrence.date, workweek: workweek)
            if day > last { break }
            if day >= today {
                reminders.append(PlannedReminder(
                    id: "\(idPrefix)milestone.\(milestone.id.uuidString).\(occurrence.date.iso)",
                    date: day,
                    title: title(for: occurrence, on: day),
                    body: "\(milestone.summary.prefix(1).uppercased())\(milestone.summary.dropFirst()) · \(occurrence.quarter.id)"
                ))
            }
            guard let next = FiscalCalendar.day(after: occurrence.date) else { break }
            cursor = next
        }
        return reminders
    }

    /// `Forecast due today`, `Forecast due tomorrow`, `Forecast due Thursday`, or `Forecast due Thu 24 Dec`.
    static func title(for occurrence: MilestoneOccurrence, on day: CalendarDate) -> String {
        let name = occurrence.milestone.name
        let away = FiscalCalendar.inclusiveDays(from: day, to: occurrence.date) - 1
        switch away {
        case 0: return "\(name) today"
        case 1: return "\(name) tomorrow"
        case 2...6: return "\(name) \(DayWords.weekday(occurrence.date))"
        default: return "\(name) \(DayWords.short(occurrence.date, today: day))"
        }
    }
}

/// Dates in words: `Thursday`, `Thu 24 Dec`, and `Thu 24 Dec 2027` when the year is not today's.
public enum DayWords {
    private static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    public static func weekday(_ date: CalendarDate) -> String {
        weekdays[FiscalCalendar.weekday(date) - 1]
    }

    public static func short(_ date: CalendarDate, today: CalendarDate? = nil) -> String {
        let weekday = String(weekday(date).prefix(3))
        let month = FiscalMonth.symbol(for: date.month)
        let sameYear = today.map { $0.year == date.year } ?? true
        let year = sameYear ? "" : " \(date.year)"
        return "\(weekday) \(date.day) \(month)\(year)"
    }
}
