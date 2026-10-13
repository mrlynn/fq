import Foundation

/// One civil month inside a fiscal year. `start` and `end` stay inside the year.
public struct FiscalMonth: Equatable, Identifiable {
    public let start: CalendarDate
    public let end: CalendarDate
    public let quarter: Int
    /// The civil month it is named for. A 4-4-5 period is named for the month it mostly covers.
    public let labelMonth: Int

    public init(start: CalendarDate, end: CalendarDate, quarter: Int, labelMonth: Int? = nil) {
        self.start = start
        self.end = end
        self.quarter = quarter
        self.labelMonth = labelMonth ?? start.month
    }

    public var id: String { start.iso }

    public var length: Int {
        FiscalCalendar.inclusiveDays(from: start, to: end)
    }

    public var symbol: String {
        Self.symbol(for: labelMonth)
    }

    static func symbol(for month: Int) -> String {
        let symbols = [
            "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        ]
        guard month >= 1, month <= 12 else { return "" }
        return symbols[month]
    }

    public func contains(_ date: CalendarDate) -> Bool {
        date >= start && date <= end
    }

    /// Fraction of this month that is over on `date`, counting today. 0 before the month, 1 after it.
    public func fill(on date: CalendarDate) -> Double {
        if date < start { return 0 }
        if date >= end { return 1 }
        guard length > 0 else { return 0 }
        return Double(FiscalCalendar.inclusiveDays(from: start, to: date)) / Double(length)
    }

    /// Sunday-first cells, including leading and trailing blanks so the weeks line up.
    public func cells() -> [MonthCell] {
        let leading = max(0, FiscalCalendar.weekday(start) - 1)
        var cells = Array(repeating: MonthCell.empty, count: leading)
        var cursor = start
        var guardCount = 0
        while cursor <= end && guardCount < 32 {
            cells.append(MonthCell(date: cursor))
            guard let next = FiscalCalendar.day(after: cursor) else { break }
            cursor = next
            guardCount += 1
        }
        while cells.count % 7 != 0 {
            cells.append(.empty)
        }
        return cells
    }
}

public struct MonthCell: Equatable {
    public let date: CalendarDate?

    public static let empty = MonthCell(date: nil)

    public var day: Int? { date?.day }
}

/// The fiscal year that contains a date, as quarters and months in order.
public struct FiscalYearMap: Equatable {
    public let fiscalYear: Int
    public let calendar: FiscalCalendarDefinition
    public let quarters: [FiscalQuarter]
    public let months: [FiscalMonth]

    public var start: CalendarDate { quarters[0].start }
    public var end: CalendarDate { quarters[quarters.count - 1].end }

    public var length: Int {
        FiscalCalendar.inclusiveDays(from: start, to: end)
    }

    public static func containing(_ date: CalendarDate, config: FiscalYearConfig = .builtIn) -> FiscalYearMap {
        containing(date, calendar: config.definition)
    }

    public static func containing(_ date: CalendarDate, calendar: FiscalCalendarDefinition) -> FiscalYearMap {
        let anchor = FiscalCalendar.quarter(containing: date, in: calendar)
        var quarters = [anchor]

        var earlier = anchor
        for _ in 0..<6 {
            let previous = FiscalCalendar.quarter(before: earlier, in: calendar)
            if previous == earlier || previous.fiscalYear != anchor.fiscalYear { break }
            quarters.insert(previous, at: 0)
            earlier = previous
        }

        var later = anchor
        for _ in 0..<6 {
            let next = FiscalCalendar.quarter(after: later, in: calendar)
            if next == later || next.fiscalYear != anchor.fiscalYear { break }
            quarters.append(next)
            later = next
        }

        return FiscalYearMap(
            fiscalYear: anchor.fiscalYear,
            calendar: calendar,
            quarters: quarters,
            months: periods(of: quarters, calendar: calendar)
                ?? months(from: quarters[0].start, through: quarters[quarters.count - 1].end, calendar: calendar)
        )
    }

    public func quarterNumber(on date: CalendarDate) -> Int {
        quarters.first { date >= $0.start && date <= $0.end }?.quarter ?? 1
    }

    public func months(in quarter: FiscalQuarter) -> [FiscalMonth] {
        months.filter { $0.quarter == quarter.quarter && $0.start >= quarter.start && $0.end <= quarter.end }
    }

    public func summary(on date: CalendarDate) -> String {
        let quarter = FiscalCalendar.quarter(containing: date, in: calendar)
        let opening = months.first?.symbol ?? start.iso
        let closing = months.last?.symbol ?? end.iso
        return "FY\(fiscalYear), \(opening) through \(closing). \(FiscalMonth.symbol(for: date.month)) \(date.day) is in Q\(quarter.quarter)."
    }

    /// A 52/53-week year's periods, three a quarter by its pattern. Nil for a calendar of months.
    private static func periods(of quarters: [FiscalQuarter], calendar: FiscalCalendarDefinition) -> [FiscalMonth]? {
        guard case .weeks(let rule) = calendar.era(containing: quarters[0].start).rule else { return nil }
        return quarters.flatMap { quarter in
            rule.periods(of: quarter).map { period in
                // Named for the month of its middle day, which is the month it mostly covers.
                let middle = FiscalCalendar.shift(period.start, by: FiscalCalendar.inclusiveDays(from: period.start, to: period.end) / 2) ?? period.start
                return FiscalMonth(start: period.start, end: period.end, quarter: quarter.quarter, labelMonth: middle.month)
            }
        }
    }

    private static func months(
        from start: CalendarDate,
        through end: CalendarDate,
        calendar: FiscalCalendarDefinition
    ) -> [FiscalMonth] {
        var months: [FiscalMonth] = []
        var cursor = start
        for _ in 0..<24 {
            if cursor > end { break }
            guard let monthEnd = FiscalCalendar.endOfMonth(cursor) else { break }
            let quarter = FiscalCalendar.quarter(containing: cursor, in: calendar)
            let clipped = [monthEnd, quarter.end, end].min() ?? end
            months.append(FiscalMonth(start: cursor, end: clipped, quarter: quarter.quarter))
            guard let next = FiscalCalendar.day(after: clipped), next > cursor else { break }
            cursor = next
        }
        return months
    }
}
