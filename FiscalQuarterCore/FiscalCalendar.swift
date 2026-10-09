import Foundation

/// A calendar day with no time of day.
public struct CalendarDate: Comparable, Hashable {
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
    public let config: FiscalYearConfig

    public init(on date: CalendarDate, config: FiscalYearConfig = .builtIn) {
        let quarter = FiscalCalendar.quarter(containing: date, config: config)
        let length = FiscalCalendar.inclusiveDays(from: quarter.start, to: quarter.end)
        self.quarter = quarter
        self.today = date
        self.config = config
        self.length = length
        self.dayIndex = FiscalCalendar.inclusiveDays(from: quarter.start, to: date)
        self.daysRemaining = quarter.daysRemaining(on: date)
        self.week = max(1, (dayIndex + 6) / 7)
        self.next = FiscalCalendar.quarter(after: quarter, config: config)
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

    /// FY27 is the 11-month transition on the built-in calendar. A custom start does not use it.
    public var transitionNote: String? {
        guard config.kind == .builtIn, quarter.fiscalYear == 27 else { return nil }
        return "FY27 ends December 31. FY28 follows the calendar year."
    }

    private enum CodingKeys: String, CodingKey {
        case id, start, end, today, day, length, daysRemaining, week, percent, status, next, nextStart, pace
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
    }
}

/// Fiscal quarter for a civil date.
///
/// FY27 is an 11-month transition year, 2026-02-01 through 2026-12-31.
/// Q3 is August and September only. Q4 is 2026-10-01 through 2026-12-31.
///
/// Earlier years start on February 1. Quarters start in February, May, August,
/// and November. January belongs to Q4 of the fiscal year that started the
/// previous February. FY26-Q4 is 2025-11-01 through 2026-01-31.
///
/// From 2027-01-01, fiscal years follow the calendar year. 2027 is FY28.
/// That continuation is inferred from the transition year ending in December.
public enum FiscalCalendar {
    /// First day of the FY27 transition year.
    private static let fy27Start = CalendarDate(year: 2026, month: 2, day: 1)
    /// First day of FY28, the calendar year after the transition.
    private static let fy28Start = CalendarDate(year: 2027, month: 1, day: 1)

    public static func quarter(containing date: CalendarDate, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        switch config.kind {
        case .builtIn:
            return builtInQuarter(date)
        case .custom:
            return customQuarter(date, startMonth: config.startMonth, startDay: config.startDay)
        }
    }

    public static func quarter(on date: Date, calendar: Calendar, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        quarter(containing: CalendarDate(date, calendar: calendar), config: config)
    }

    /// The quarter that begins the day after `quarter` ends.
    public static func quarter(after quarter: FiscalQuarter, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        guard let next = day(after: quarter.end) else { return quarter }
        return self.quarter(containing: next, config: config)
    }

    /// The quarter that ends the day before `quarter` starts.
    public static func quarter(before quarter: FiscalQuarter, config: FiscalYearConfig = .builtIn) -> FiscalQuarter {
        guard let previous = day(before: quarter.start) else { return quarter }
        return self.quarter(containing: previous, config: config)
    }

    /// The built-in February calendar, including the short FY27.
    private static func builtInQuarter(_ date: CalendarDate) -> FiscalQuarter {
        if date >= fy27Start && date < fy28Start {
            return transitionQuarter(date)
        }
        if date >= fy28Start {
            return calendarYearQuarter(date)
        }
        return februaryYearQuarter(date)
    }

    /// Four quarters of three months. The FY number is the calendar year the fiscal year ends in, minus 2000.
    /// A year that starts on 1 Feb 2025 ends on 31 Jan 2026, so it is FY26.
    private static func customQuarter(_ date: CalendarDate, startMonth: Int, startDay: Int) -> FiscalQuarter {
        let month = min(12, max(1, startMonth))
        let day = min(31, max(1, startDay))
        let anniversary = anchored(year: date.year, month: month, day: day)
        let yearStart = date >= anniversary
            ? anniversary
            : anchored(year: date.year - 1, month: month, day: day)
        let nextStart = anchored(year: yearStart.year + 1, month: month, day: day)
        let yearEnd = self.day(before: nextStart) ?? yearStart
        let fiscalYear = yearEnd.year - 2000
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

    private static func shift(_ date: CalendarDate, by days: Int) -> CalendarDate? {
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

    fileprivate static let dayCountCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    fileprivate static func gregorianDate(_ date: CalendarDate) -> Date? {
        dayCountCalendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))
    }

    /// FY27: February 2026 through December 2026. Q3 is two months.
    private static func transitionQuarter(_ date: CalendarDate) -> FiscalQuarter {
        switch date.month {
        case 2, 3, 4:
            return make(27, 1, 2026, 2, 1, 2026, 4, 30)
        case 5, 6, 7:
            return make(27, 2, 2026, 5, 1, 2026, 7, 31)
        case 8, 9:
            return make(27, 3, 2026, 8, 1, 2026, 9, 30)
        case 10, 11, 12:
            return make(27, 4, 2026, 10, 1, 2026, 12, 31)
        default:
            return februaryYearQuarter(date)
        }
    }

    /// Calendar-year fiscal quarters. FY number is `year - 1999` (2027 is FY28).
    private static func calendarYearQuarter(_ date: CalendarDate) -> FiscalQuarter {
        let year = date.year
        let fiscalYear = year - 1999
        switch date.month {
        case 1, 2, 3:
            return make(fiscalYear, 1, year, 1, 1, year, 3, 31)
        case 4, 5, 6:
            return make(fiscalYear, 2, year, 4, 1, year, 6, 30)
        case 7, 8, 9:
            return make(fiscalYear, 3, year, 7, 1, year, 9, 30)
        case 10, 11, 12:
            return make(fiscalYear, 4, year, 10, 1, year, 12, 31)
        default:
            return make(fiscalYear, 1, year, 1, 1, year, 3, 31)
        }
    }

    /// February-start fiscal year.
    /// February of calendar year Y is FY(Y - 1999): February 2025 is FY26.
    /// January stays in the previous fiscal year: January 2026 is FY26-Q4.
    private static func februaryYearQuarter(_ date: CalendarDate) -> FiscalQuarter {
        let year = date.year
        switch date.month {
        case 1:
            return make(year - 2000, 4, year - 1, 11, 1, year, 1, 31)
        case 2, 3, 4:
            return make(year - 1999, 1, year, 2, 1, year, 4, 30)
        case 5, 6, 7:
            return make(year - 1999, 2, year, 5, 1, year, 7, 31)
        case 8, 9, 10:
            return make(year - 1999, 3, year, 8, 1, year, 10, 31)
        case 11, 12:
            return make(year - 1999, 4, year, 11, 1, year + 1, 1, 31)
        default:
            return make(year - 1999, 1, year, 2, 1, year, 4, 30)
        }
    }

    private static func make(
        _ fiscalYear: Int,
        _ quarter: Int,
        _ startYear: Int,
        _ startMonth: Int,
        _ startDay: Int,
        _ endYear: Int,
        _ endMonth: Int,
        _ endDay: Int
    ) -> FiscalQuarter {
        FiscalQuarter(
            fiscalYear: fiscalYear,
            quarter: quarter,
            start: CalendarDate(year: startYear, month: startMonth, day: startDay),
            end: CalendarDate(year: endYear, month: endMonth, day: endDay)
        )
    }
}
