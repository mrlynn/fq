import Foundation

/// A 52/53-week fiscal year, as retailers and many companies keep: the year ends on the same
/// weekday every year, so it runs 52 weeks, with a 53rd every five or six years.
///
/// The year ends on the last `endWeekday` of `endMonth`, or the `endWeekday` nearest the last day
/// of `endMonth`. Each quarter is 13 weeks, with a 53rd week added to Q4 or Q1. Inside a quarter,
/// `pattern` splits the weeks into three periods, such as 4, 4, and 5.
///
/// The FY number is the calendar year the fiscal year ends in, minus 2000, plus `yearOffset`.
/// Retail calendars that name a year for the year it starts use an offset of -1.
public struct WeekRule: Equatable, Hashable, Codable {
    public var endMonth: Int
    /// Sunday is 1, Saturday is 7.
    public var endWeekday: Int
    public var method: Method
    public var pattern: Pattern
    public var extraWeek: ExtraWeek
    public var yearOffset: Int

    public init(endMonth: Int, endWeekday: Int = 7, method: Method, pattern: Pattern = .p445, extraWeek: ExtraWeek = .q4, yearOffset: Int = 0) {
        self.endMonth = min(12, max(1, endMonth))
        self.endWeekday = min(7, max(1, endWeekday))
        self.method = method
        self.pattern = pattern
        self.extraWeek = extraWeek
        self.yearOffset = yearOffset
    }

    public enum Method: String, CaseIterable, Codable, Identifiable {
        /// The last such weekday in the month.
        case last
        /// The such weekday nearest the month's last day, which can fall in the next month.
        case nearest
        public var id: String { rawValue }
    }

    public enum Pattern: String, CaseIterable, Codable, Identifiable {
        case p445 = "4-4-5", p454 = "4-5-4", p544 = "5-4-4"
        public var id: String { rawValue }

        /// Weeks in each period of a 13-week quarter.
        public var weeks: [Int] {
            switch self {
            case .p445: return [4, 4, 5]
            case .p454: return [4, 5, 4]
            case .p544: return [5, 4, 4]
            }
        }
    }

    /// Which quarter takes the 53rd week in a long year.
    public enum ExtraWeek: String, CaseIterable, Codable, Identifiable {
        case q1, q4
        public var id: String { rawValue }
    }

    // MARK: Common calendars

    /// The National Retail Federation's 4-5-4 calendar: the year ends on the Saturday nearest
    /// 31 January and is named for the year it starts.
    public static let retail = WeekRule(endMonth: 1, endWeekday: 7, method: .nearest, pattern: .p454, extraWeek: .q4, yearOffset: -1)

    // MARK: Dates

    /// The last day of the fiscal year that ends in calendar year `year`.
    public func yearEnd(in year: Int) -> CalendarDate {
        let monthEnd = FiscalCalendar.endOfMonth(CalendarDate(year: year, month: endMonth, day: 1))
            ?? CalendarDate(year: year, month: endMonth, day: 28)
        let weekday = FiscalCalendar.weekday(monthEnd)
        let back = (weekday - endWeekday + 7) % 7
        let earlier = FiscalCalendar.shift(monthEnd, by: -back) ?? monthEnd
        switch method {
        case .last:
            return earlier
        case .nearest:
            // The two candidates are seven days apart, so one is always three days away or less.
            return back <= 3 ? earlier : FiscalCalendar.shift(earlier, by: 7) ?? earlier
        }
    }

    /// The fiscal year containing `date`: the calendar year it ends in, and its first and last days.
    func year(containing date: CalendarDate) -> (endYear: Int, start: CalendarDate, end: CalendarDate) {
        var endYear = date.year
        if date > yearEnd(in: endYear) {
            endYear += 1
        } else if date <= yearEnd(in: endYear - 1) {
            endYear -= 1
        }
        let previousEnd = yearEnd(in: endYear - 1)
        let start = FiscalCalendar.day(after: previousEnd) ?? previousEnd
        return (endYear, start, yearEnd(in: endYear))
    }

    /// Weeks in each quarter of the year from `start` through `end`: 13 each, one 14 in a 53-week year.
    func quarterWeeks(from start: CalendarDate, through end: CalendarDate) -> [Int] {
        var weeks = [13, 13, 13, 13]
        if FiscalCalendar.inclusiveDays(from: start, to: end) > 364 {
            weeks[extraWeek == .q1 ? 0 : 3] = 14
        }
        return weeks
    }

    /// The quarter containing `date`.
    func quarter(containing date: CalendarDate) -> FiscalQuarter {
        let year = year(containing: date)
        let fiscalYear = year.endYear - 2000 + yearOffset
        var start = year.start
        for (index, weeks) in quarterWeeks(from: year.start, through: year.end).enumerated() {
            let end = FiscalCalendar.shift(start, by: weeks * 7 - 1) ?? start
            if date <= end || index == 3 {
                return FiscalQuarter(fiscalYear: fiscalYear, quarter: index + 1, start: start, end: index == 3 ? year.end : end)
            }
            start = FiscalCalendar.day(after: end) ?? end
        }
        return FiscalQuarter(fiscalYear: fiscalYear, quarter: 4, start: start, end: year.end)
    }

    /// The three periods of `quarter`, by `pattern`. A 14-week quarter's extra week goes to its last period.
    func periods(of quarter: FiscalQuarter) -> [(start: CalendarDate, end: CalendarDate)] {
        var weeks = pattern.weeks
        if FiscalCalendar.inclusiveDays(from: quarter.start, to: quarter.end) > 91 {
            weeks[2] += 1
        }
        var periods: [(CalendarDate, CalendarDate)] = []
        var start = quarter.start
        for (index, count) in weeks.enumerated() {
            let end = index == 2 ? quarter.end : min(quarter.end, FiscalCalendar.shift(start, by: count * 7 - 1) ?? start)
            periods.append((start, end))
            guard let next = FiscalCalendar.day(after: end), next <= quarter.end else { break }
            start = next
        }
        return periods
    }

    // MARK: Words

    private static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    public static func weekdayName(_ weekday: Int) -> String {
        weekdays[min(7, max(1, weekday)) - 1]
    }

    public static func monthName(_ month: Int) -> String {
        months[min(12, max(1, month)) - 1]
    }

    /// `Ends the Saturday nearest 31 January, 4-5-4`.
    public var summary: String {
        let day = Self.weekdayName(endWeekday)
        let month = Self.monthName(endMonth)
        let monthEnd = FiscalYearConfig.lastDay(of: endMonth) == 29 ? 28 : FiscalYearConfig.lastDay(of: endMonth)
        let when = method == .last ? "the last \(day) of \(month)" : "the \(day) nearest \(monthEnd) \(month)"
        return "Ends \(when), \(pattern.rawValue)"
    }
}
