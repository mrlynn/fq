import Foundation

/// A calendar day with no time of day. Encodes as `YYYY-MM-DD`.
public struct CalendarDate: Comparable, Hashable, Codable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The year, month, and day of `date` in `calendar`.
    /// Pass `Calendar.current` to use the machine's local time zone.
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses `YYYY-MM-DD`. Returns nil for any other shape or for a day that does not exist.
    public init?(iso raw: String) {
        let parts = raw.split(separator: "-", omittingEmptySubsequences: false)
        guard
            parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            return nil
        }
        let candidate = CalendarDate(year: year, month: month, day: day)
        guard
            let resolved = FiscalCalendar.gregorianDate(candidate),
            CalendarDate(resolved, calendar: FiscalCalendar.dayCountCalendar) == candidate
        else {
            return nil
        }
        self = candidate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let date = CalendarDate(iso: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected YYYY-MM-DD, got \"\(raw)\".")
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

/// One fiscal quarter, inclusive of `start` and `end`.
public struct FiscalQuarter: Equatable {
    public let fiscalYear: Int
    public let quarter: Int
    public let start: CalendarDate
    public let end: CalendarDate

    public var id: String {
        String(format: "FY%02d-Q%d", fiscalYear, quarter)
    }

    /// Days from `date` through `end`, counting both. The last day of the quarter returns 1.
    public func daysRemaining(on date: CalendarDate) -> Int {
        FiscalCalendar.inclusiveDays(from: date, to: end)
    }
}

/// Where a civil date sits inside its fiscal quarter.
public struct QuarterSnapshot: Equatable, Encodable {
    public let quarter: FiscalQuarter
    public let today: CalendarDate
    public let dayIndex: Int
    public let length: Int
    public let daysRemaining: Int
    public let week: Int
    public let next: FiscalQuarter
    public let calendar: FiscalCalendarDefinition
    /// Which days the countdowns count as workdays.
    public let workweek: Workweek

    public init(on date: CalendarDate, config: FiscalYearConfig = .builtIn, workweek: Workweek = .weekdays) {
        self.init(on: date, calendar: config.definition, workweek: workweek)
    }

    public init(on date: CalendarDate, calendar: FiscalCalendarDefinition, workweek: Workweek = .weekdays) {
        self.workweek = workweek
        let quarter = FiscalCalendar.quarter(containing: date, in: calendar)
        let length = FiscalCalendar.inclusiveDays(from: quarter.start, to: quarter.end)
        self.quarter = quarter
        self.today = date
        self.calendar = calendar
        self.length = length
        self.dayIndex = FiscalCalendar.inclusiveDays(from: quarter.start, to: date)
        self.daysRemaining = quarter.daysRemaining(on: date)
        self.week = max(1, (dayIndex + 6) / 7)
        self.next = FiscalCalendar.quarter(after: quarter, in: calendar)
    }

    /// Share of the quarter through today, counting today. The last day is 1.
    public var fractionComplete: Double {
        guard length > 0 else { return 0 }
        return Double(dayIndex) / Double(length)
    }

    public var percent: Int {
        Int((fractionComplete * 100).rounded())
    }

    /// Week 1 is the first seven days of the quarter, counting the start date.
    public var progressLine: String {
        "Day \(dayIndex) of \(length) · week \(week)"
    }

    public var statusLine: String {
        let left = daysRemaining == 1 ? "1 day left" : "\(daysRemaining) days left"
        return "\(quarter.id) · \(progressLine) · \(left)"
    }

    public var menuBarLabel: String {
        "\(quarter.id) · \(daysRemaining)d"
    }

    public var paceNote: String? {
        switch daysRemaining {
        case 1:
            return "Last day of the quarter."
        case 2...7:
            return "Last week of the quarter."
        case 8...14:
            return "Last two weeks of the quarter."
        default:
            return nil
        }
    }

    /// The note on today's era, such as one explaining a short transition year. The built-in calendar has none.
    public var transitionNote: String? {
        calendar.era(containing: today).note
    }

    private enum CodingKeys: String, CodingKey {
        case id, start, end, today, day, length, daysRemaining, week, percent, status, next, nextStart, pace, countdowns
    }

    private enum CountdownKeys: String, CodingKey {
        case target, label, end, days, workdays, weekends
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(quarter.id, forKey: .id)
        try container.encode(quarter.start.iso, forKey: .start)
        try container.encode(quarter.end.iso, forKey: .end)
        try container.encode(today.iso, forKey: .today)
        try container.encode(dayIndex, forKey: .day)
        try container.encode(length, forKey: .length)
        try container.encode(daysRemaining, forKey: .daysRemaining)
        try container.encode(week, forKey: .week)
        try container.encode(percent, forKey: .percent)
        try container.encode(statusLine, forKey: .status)
        try container.encode(next.id, forKey: .next)
        try container.encode(next.start.iso, forKey: .nextStart)
        try container.encodeIfPresent(paceNote, forKey: .pace)
        var list = container.nestedUnkeyedContainer(forKey: .countdowns)
        for countdown in countdowns {
            var item = list.nestedContainer(keyedBy: CountdownKeys.self)
            try item.encodeIfPresent(countdown.target?.rawValue, forKey: .target)
            try item.encode(countdown.label, forKey: .label)
            try item.encode(countdown.end.iso, forKey: .end)
            try item.encode(countdown.days, forKey: .days)
            try item.encode(countdown.workdays, forKey: .workdays)
            try item.encode(countdown.weekends, forKey: .weekends)
        }
    }
}

/// Fiscal quarter for a civil date, read from a `FiscalCalendarDefinition`.
///
/// The built-in calendar is `FiscalCalendarDefinition.builtIn`: the calendar year, numbered by that year.
public enum FiscalCalendar {
    public static func quarter(containing date: CalendarDate, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        quarter(containing: date, in: config.definition)
    }

    public static func quarter(on date: Date, calendar: Calendar, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        quarter(containing: CalendarDate(date, calendar: calendar), config: config)
    }

    /// The quarter that begins the day after `quarter` ends.
    public static func quarter(after quarter: FiscalQuarter, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        self.quarter(after: quarter, in: config.definition)
    }

    /// The quarter that ends the day before `quarter` starts.
    public static func quarter(before quarter: FiscalQuarter, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        self.quarter(before: quarter, in: config.definition)
    }

    /// The quarter containing `date`, clipped to the era it falls in.
    public static func quarter(containing date: CalendarDate, in definition: FiscalCalendarDefinition) -> FiscalQuarter {
        let index = definition.eraIndex(containing: date)
        let era = definition.eras[index]
        let quarter: FiscalQuarter
        switch era.rule {
        case .months(let rule):
            quarter = monthQuarter(date, rule: rule)
        case .explicit(let year):
            // Validation guarantees the spans cover the era, so the fallback is never reached.
            let number = year.quarters.firstIndex { date >= $0.start && date <= $0.end } ?? 0
            let span = year.quarters[number]
            quarter = FiscalQuarter(fiscalYear: year.fiscalYear, quarter: number + 1, start: span.start, end: span.end)
        case .weeks(let rule):
            quarter = rule.quarter(containing: date)
        }
        return clip(quarter, from: era.start, before: definition.start(afterEra: index))
    }

    public static func quarter(after quarter: FiscalQuarter, in definition: FiscalCalendarDefinition) -> FiscalQuarter {
        guard let next = day(after: quarter.end) else { return quarter }
        return self.quarter(containing: next, in: definition)
    }

    public static func quarter(before quarter: FiscalQuarter, in definition: FiscalCalendarDefinition) -> FiscalQuarter {
        guard let previous = day(before: quarter.start) else { return quarter }
        return self.quarter(containing: previous, in: definition)
    }

    /// A rule-based quarter can spill past its era when an era starts mid-year. Trim it to the era.
    private static func clip(_ quarter: FiscalQuarter, from eraStart: CalendarDate?, before nextStart: CalendarDate?) -> FiscalQuarter {
        var start = quarter.start
        var end = quarter.end
        if let eraStart, start < eraStart {
            start = eraStart
        }
        if let nextStart, let lastDay = day(before: nextStart), end > lastDay {
            end = lastDay
        }
        return FiscalQuarter(fiscalYear: quarter.fiscalYear, quarter: quarter.quarter, start: start, end: end)
    }

    /// Four quarters of three months. The FY number is the calendar year the fiscal year ends in, minus 2000,
    /// plus the rule's offset. A year that starts on 1 Feb 2025 ends on 31 Jan 2026, so it is FY26.
    private static func monthQuarter(_ date: CalendarDate, rule: MonthRule) -> FiscalQuarter {
        let month = min(12, max(1, rule.startMonth))
        let day = min(31, max(1, rule.startDay))
        let anniversary = anchored(year: date.year, month: month, day: day)
        let yearStart = date >= anniversary
            ? anniversary
            : anchored(year: date.year - 1, month: month, day: day)
        let nextStart = anchored(year: yearStart.year + 1, month: month, day: day)
        let yearEnd = self.day(before: nextStart) ?? yearStart
        let fiscalYear = yearEnd.year - 2000 + rule.yearOffset
        let boundaries = [
            yearStart,
            shiftedAnchor(3, from: yearStart, day: day),
            shiftedAnchor(6, from: yearStart, day: day),
            shiftedAnchor(9, from: yearStart, day: day),
            nextStart,
        ]
        for index in 0..<4 {
            let start = boundaries[index]
            let end = self.day(before: boundaries[index + 1]) ?? yearEnd
            if date >= start && date <= end {
                return FiscalQuarter(fiscalYear: fiscalYear, quarter: index + 1, start: start, end: end)
            }
        }
        return FiscalQuarter(fiscalYear: fiscalYear, quarter: 4, start: boundaries[3], end: yearEnd)
    }

    /// `day` in `month` of `year`, or the last real day of that month when `day` does not exist.
    private static func anchored(year: Int, month: Int, day: Int) -> CalendarDate {
        var candidate = min(31, max(1, day))
        while candidate >= 1 {
            let date = CalendarDate(year: year, month: month, day: candidate)
            if let resolved = gregorianDate(date) {
                let parts = dayCountCalendar.dateComponents([.year, .month, .day], from: resolved)
                if parts.year == year, parts.month == month, parts.day == candidate {
                    return date
                }
            }
            candidate -= 1
        }
        return CalendarDate(year: year, month: month, day: 1)
    }

    private static func shiftedAnchor(_ months: Int, from start: CalendarDate, day: Int) -> CalendarDate {
        var month = start.month + months
        var year = start.year
        while month > 12 {
            month -= 12
            year += 1
        }
        return anchored(year: year, month: month, day: day)
    }

    /// Sunday is 1, Saturday is 7. Matches the Gregorian calendar used for day counts.
    public static func weekday(_ date: CalendarDate) -> Int {
        guard let day = gregorianDate(date) else { return 1 }
        return dayCountCalendar.component(.weekday, from: day)
    }

    static func day(after date: CalendarDate) -> CalendarDate? {
        shift(date, by: 1)
    }

    static func day(before date: CalendarDate) -> CalendarDate? {
        shift(date, by: -1)
    }

    static func endOfMonth(_ date: CalendarDate) -> CalendarDate? {
        guard
            let day = gregorianDate(date),
            let range = dayCountCalendar.range(of: .day, in: .month, for: day)
        else {
            return nil
        }
        return CalendarDate(year: date.year, month: date.month, day: range.upperBound - 1)
    }

    static func shift(_ date: CalendarDate, by days: Int) -> CalendarDate? {
        guard
            let day = gregorianDate(date),
            let shifted = dayCountCalendar.date(byAdding: .day, value: days, to: day)
        else {
            return nil
        }
        return CalendarDate(shifted, calendar: dayCountCalendar)
    }

    /// Days from `start` through `end`, counting both. Returns 0 when `end` is before `start`.
    static func inclusiveDays(from start: CalendarDate, to end: CalendarDate) -> Int {
        guard
            let from = gregorianDate(start),
            let to = gregorianDate(end),
            let span = dayCountCalendar.dateComponents([.day], from: from, to: to).day
        else {
            return 0
        }
        if span < 0 {
            return 0
        }
        return span + 1
    }

    static let dayCountCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static func gregorianDate(_ date: CalendarDate) -> Date? {
        dayCountCalendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))
    }
}
