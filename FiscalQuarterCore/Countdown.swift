import Foundation

/// What a countdown runs to: the end of the quarter, the half, or the fiscal year.
public enum CountdownTarget: String, CaseIterable, Codable, Identifiable, Sendable {
    case quarter
    case half
    case year

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quarter: return "Quarter"
        case .half: return "Half"
        case .year: return "Year"
        }
    }
}

/// How a countdown is counted.
public enum CountdownUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Calendar days, counting today.
    case days
    /// Monday through Friday, counting today, less the holidays and days off in the workweek.
    case workdays
    /// Whole weeks and the days left over.
    case weeks
    /// Weekends still to come, counting the one in progress.
    case weekends

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .days: return "Days"
        case .workdays: return "Workdays"
        case .weeks: return "Weeks"
        case .weekends: return "Weekends"
        }
    }
}

/// Time left from `today` through the last day of a quarter, half, or fiscal year, or through a milestone.
public struct Countdown: Equatable {
    /// The period counted down to. Nil for a milestone.
    public let target: CountdownTarget?
    /// `FY26-Q4`, `FY26-H2`, or `FY26`.
    public let label: String
    public let start: CalendarDate
    public let end: CalendarDate
    public let today: CalendarDate
    /// Which days count as workdays.
    public let workweek: Workweek

    public init(target: CountdownTarget?, label: String, start: CalendarDate, end: CalendarDate, today: CalendarDate, workweek: Workweek = .weekdays) {
        self.target = target
        self.label = label
        self.start = start
        self.end = end
        self.today = today
        self.workweek = workweek
    }

    /// Days from today through `end`, counting both. The last day is 1.
    public var days: Int {
        FiscalCalendar.inclusiveDays(from: today, to: end)
    }

    public var length: Int {
        FiscalCalendar.inclusiveDays(from: start, to: end)
    }

    /// Close enough to show in amber: the last week before a milestone, the last two weeks of a period.
    public var isSoon: Bool {
        days <= (target == nil ? 7 : 14)
    }

    /// Share of the period through today, counting today.
    public var fractionComplete: Double {
        guard length > 0 else { return 0 }
        return Double(length - days + 1) / Double(length)
    }

    /// Workdays from today through `end`, counting both: weekdays, less holidays and days off.
    public var workdays: Int {
        weekdays - workweek.weekdaysOff(from: today, through: end)
    }

    /// Monday through Friday from today through `end`, counting both.
    var weekdays: Int {
        let total = days
        guard total > 0 else { return 0 }
        let fullWeeks = total / 7
        var count = fullWeeks * 5
        var weekday = FiscalCalendar.weekday(today)
        for _ in 0..<(total % 7) {
            if weekday != 1 && weekday != 7 {
                count += 1
            }
            weekday = weekday % 7 + 1
        }
        return count
    }

    /// Saturdays from today through `end`, plus the current weekend when today is Sunday.
    public var weekends: Int {
        let total = days
        guard total > 0 else { return 0 }
        let weekday = FiscalCalendar.weekday(today)
        let untilSaturday = (7 - weekday) % 7
        let saturdays = untilSaturday < total ? (total - 1 - untilSaturday) / 7 + 1 : 0
        return saturdays + (weekday == 1 ? 1 : 0)
    }

    public func value(in unit: CountdownUnit) -> Int {
        switch unit {
        case .days: return days
        case .workdays: return workdays
        case .weeks: return days / 7
        case .weekends: return weekends
        }
    }

    /// `82 days`, `58 workdays`, `11 weeks 5 days`, or `12 weekends`.
    public func phrase(in unit: CountdownUnit) -> String {
        switch unit {
        case .days:
            return plural(days, "day")
        case .workdays:
            return plural(workdays, "workday")
        case .weeks:
            let weeks = days / 7
            let rest = days % 7
            if weeks == 0 { return plural(rest, "day") }
            if rest == 0 { return plural(weeks, "week") }
            return "\(plural(weeks, "week")) \(plural(rest, "day"))"
        case .weekends:
            return plural(weekends, "weekend")
        }
    }

    /// Short enough for the menu bar: `82d`, `58wd`, `11w 5d`, `12 wknd`.
    public func short(in unit: CountdownUnit) -> String {
        switch unit {
        case .days:
            return "\(days)d"
        case .workdays:
            return "\(workdays)wd"
        case .weeks:
            let rest = days % 7
            return days >= 7 ? (rest == 0 ? "\(days / 7)w" : "\(days / 7)w \(rest)d") : "\(rest)d"
        case .weekends:
            return "\(weekends) wknd"
        }
    }

    private func plural(_ count: Int, _ noun: String) -> String {
        count == 1 ? "1 \(noun)" : "\(count) \(noun)s"
    }
}

/// Countdowns that share an end date, such as Q4, H2, and the year all ending December 31.
public struct CountdownGroup: Equatable, Identifiable {
    public let countdowns: [Countdown]

    public var id: String { end.iso }
    public var end: CalendarDate { countdowns[0].end }
    public var first: Countdown { countdowns[0] }

    /// `FY26-Q4`, or `FY26-Q4 · H2 · FY26` when several end together.
    public var label: String {
        countdowns.enumerated().map { index, countdown in
            index > 0 && countdown.target == .half
                ? String(countdown.label.suffix(2))
                : countdown.label
        }
        .joined(separator: " · ")
    }
}

extension QuarterSnapshot {
    public func countdown(to target: CountdownTarget) -> Countdown {
        let map = FiscalYearMap.containing(today, calendar: calendar)
        let year = "FY\(String(format: "%02d", map.fiscalYear))"
        switch target {
        case .quarter:
            return Countdown(target: .quarter, label: quarter.id, start: quarter.start, end: quarter.end, today: today, workweek: workweek)
        case .half:
            // The first half is the first ceil(n/2) quarters, so a four-quarter year splits two and two.
            let quarters = map.quarters
            let split = (quarters.count + 1) / 2
            let position = quarters.firstIndex { today >= $0.start && today <= $0.end } ?? 0
            let firstHalf = position < split
            let span = firstHalf ? quarters[0..<split] : quarters[split...]
            let start = span.first?.start ?? quarter.start
            let end = span.last?.end ?? quarter.end
            return Countdown(target: .half, label: "\(year)-H\(firstHalf ? 1 : 2)", start: start, end: end, today: today, workweek: workweek)
        case .year:
            return Countdown(target: .year, label: year, start: map.start, end: map.end, today: today, workweek: workweek)
        }
    }

    public var countdowns: [Countdown] {
        CountdownTarget.allCases.map(countdown(to:))
    }

    /// Countdowns grouped by end date, nearest first.
    public var countdownGroups: [CountdownGroup] {
        var groups: [CountdownGroup] = []
        for countdown in countdowns {
            if let index = groups.firstIndex(where: { $0.end == countdown.end }) {
                groups[index] = CountdownGroup(countdowns: groups[index].countdowns + [countdown])
            } else {
                groups.append(CountdownGroup(countdowns: [countdown]))
            }
        }
        return groups
    }
}
