import Foundation

/// A fiscal calendar described as data: an ordered run of eras.
///
/// Each era starts on a date and lasts until the next era starts. The first era reaches back
/// without limit and the last reaches forward without limit, so both must follow a repeating
/// rule. An era in between may list its quarters outright, which is how a short transition
/// year is written down.
///
/// The JSON form, with the built-in calendar as the example:
///
///     {
///       "name": "Built-in",
///       "eras": [
///         { "rule": "months", "startMonth": 2, "startDay": 1 },
///         { "from": "2026-02-01", "rule": "explicit", "fiscalYear": 27,
///           "note": "FY27 ends December 31. FY28 follows the calendar year.",
///           "quarters": [ { "start": "2026-02-01", "end": "2026-04-30" }, ... ] },
///         { "from": "2027-01-01", "rule": "months", "startMonth": 1, "startDay": 1, "yearOffset": 1 }
///       ]
///     }
public struct FiscalCalendarDefinition: Equatable, Codable {
    public var name: String
    public var eras: [Era]

    /// Throws when the eras are out of order, open-ended on an explicit era, or leave a gap.
    public init(name: String, eras: [Era]) throws {
        self.name = name
        self.eras = eras
        try validate()
    }

    /// Reads a definition from JSON and checks it.
    public init(json data: Data) throws {
        self = try JSONDecoder().decode(FiscalCalendarDefinition.self, from: data)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            name: container.decodeIfPresent(String.self, forKey: .name) ?? "Custom",
            eras: container.decode([Era].self, forKey: .eras)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case name, eras
    }

    /// The era in force on `date`.
    public func era(containing date: CalendarDate) -> Era {
        eras[eraIndex(containing: date)]
    }

    func eraIndex(containing date: CalendarDate) -> Int {
        eras.lastIndex { era in
            guard let start = era.start else { return true }
            return start <= date
        } ?? 0
    }

    /// The day the era after `index` starts, or nil for the last era.
    func start(afterEra index: Int) -> CalendarDate? {
        index + 1 < eras.count ? eras[index + 1].start : nil
    }

    private func validate() throws {
        guard let first = eras.first, let last = eras.last else {
            throw DefinitionError("A calendar needs at least one era.")
        }
        if first.start != nil {
            throw DefinitionError("The first era must not have a \"from\" date. It covers everything before the next era.")
        }
        if case .explicit = first.rule {
            throw DefinitionError("The first era must use the months rule, because it has no start.")
        }
        if case .explicit = last.rule {
            throw DefinitionError("The last era must use the months rule, because it has no end.")
        }
        for (index, era) in eras.enumerated().dropFirst() {
            guard let start = era.start else {
                throw DefinitionError("Era \(index + 1) needs a \"from\" date.")
            }
            if let previous = eras[index - 1].start, start <= previous {
                throw DefinitionError("Era \(index + 1) starts on \(start.iso), which is not after the era before it.")
            }
        }
        for (index, era) in eras.enumerated() {
            switch era.rule {
            case .months(let rule):
                if !(1...12).contains(rule.startMonth) || !(1...31).contains(rule.startDay) {
                    throw DefinitionError("Era \(index + 1) has a start month or day out of range.")
                }
            case .explicit(let year):
                try validate(year, era: era, index: index)
            }
        }
    }

    /// An explicit era's quarters must run back to back from the era's start to the day before the next era.
    private func validate(_ year: ExplicitYear, era: Era, index: Int) throws {
        guard let firstQuarter = year.quarters.first, let lastQuarter = year.quarters.last else {
            throw DefinitionError("Era \(index + 1) lists no quarters.")
        }
        if firstQuarter.start != era.start {
            throw DefinitionError("Era \(index + 1) starts on \(era.start?.iso ?? "?"), but its first quarter starts on \(firstQuarter.start.iso).")
        }
        for (number, span) in year.quarters.enumerated() where span.end < span.start {
            throw DefinitionError("Q\(number + 1) of era \(index + 1) ends before it starts.")
        }
        for (earlier, later) in zip(year.quarters, year.quarters.dropFirst())
        where FiscalCalendar.day(after: earlier.end) != later.start {
            throw DefinitionError("Era \(index + 1) has a gap or overlap after \(earlier.end.iso).")
        }
        let nextStart = eras[index + 1].start
        if let nextStart, FiscalCalendar.day(after: lastQuarter.end) != nextStart {
            throw DefinitionError("Era \(index + 1) ends on \(lastQuarter.end.iso), but the next era starts on \(nextStart.iso).")
        }
    }
}

extension FiscalCalendarDefinition {
    /// The February calendar with the 11-month FY27, then calendar years from 2027 as FY28 onward.
    public static let builtIn: FiscalCalendarDefinition = {
        func date(_ iso: String) -> CalendarDate {
            CalendarDate(iso: iso) ?? CalendarDate(year: 1970, month: 1, day: 1)
        }
        let eras = [
            Era(start: nil, rule: .months(MonthRule(startMonth: 2, startDay: 1))),
            Era(
                start: date("2026-02-01"),
                rule: .explicit(ExplicitYear(fiscalYear: 27, quarters: [
                    QuarterSpan(start: date("2026-02-01"), end: date("2026-04-30")),
                    QuarterSpan(start: date("2026-05-01"), end: date("2026-07-31")),
                    QuarterSpan(start: date("2026-08-01"), end: date("2026-09-30")),
                    QuarterSpan(start: date("2026-10-01"), end: date("2026-12-31")),
                ])),
                note: "FY27 ends December 31. FY28 follows the calendar year."
            ),
            Era(start: date("2027-01-01"), rule: .months(MonthRule(startMonth: 1, startDay: 1, yearOffset: 1))),
        ]
        // The literal above is checked by the tests, so a failure here is a programming error.
        return try! FiscalCalendarDefinition(name: "Built-in", eras: eras)
    }()

    /// Four three-month quarters every year from `startMonth`/`startDay`, with no exceptions.
    public static func months(startMonth: Int, startDay: Int, name: String? = nil) -> FiscalCalendarDefinition {
        let rule = MonthRule(startMonth: min(12, max(1, startMonth)), startDay: min(31, max(1, startDay)))
        let label = name ?? "Starts \(FiscalMonth.symbol(for: rule.startMonth)) \(rule.startDay)"
        // One open-ended months era always passes validation.
        return try! FiscalCalendarDefinition(name: label, eras: [Era(start: nil, rule: .months(rule))])
    }
}

/// A stretch of time that follows one rule. `start` is nil only for the first era.
public struct Era: Equatable, Codable {
    public var start: CalendarDate?
    public var rule: Rule
    /// Shown alongside any quarter in this era, for example to explain a short year.
    public var note: String?

    public init(start: CalendarDate?, rule: Rule, note: String? = nil) {
        self.start = start
        self.rule = rule
        self.note = note
    }

    public enum Rule: Equatable {
        case months(MonthRule)
        case explicit(ExplicitYear)
    }

    private enum CodingKeys: String, CodingKey {
        case from, rule, note, startMonth, startDay, yearOffset, fiscalYear, quarters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeIfPresent(CalendarDate.self, forKey: .from)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        switch try container.decode(String.self, forKey: .rule) {
        case "months":
            rule = .months(MonthRule(
                startMonth: try container.decode(Int.self, forKey: .startMonth),
                startDay: try container.decodeIfPresent(Int.self, forKey: .startDay) ?? 1,
                yearOffset: try container.decodeIfPresent(Int.self, forKey: .yearOffset) ?? 0
            ))
        case "explicit":
            rule = .explicit(ExplicitYear(
                fiscalYear: try container.decode(Int.self, forKey: .fiscalYear),
                quarters: try container.decode([QuarterSpan].self, forKey: .quarters)
            ))
        case let other:
            throw DecodingError.dataCorruptedError(
                forKey: .rule,
                in: container,
                debugDescription: "Unknown rule \"\(other)\". Use \"months\" or \"explicit\"."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(start, forKey: .from)
        switch rule {
        case .months(let months):
            try container.encode("months", forKey: .rule)
            try container.encode(months.startMonth, forKey: .startMonth)
            try container.encode(months.startDay, forKey: .startDay)
            if months.yearOffset != 0 {
                try container.encode(months.yearOffset, forKey: .yearOffset)
            }
        case .explicit(let year):
            try container.encode("explicit", forKey: .rule)
            try container.encode(year.fiscalYear, forKey: .fiscalYear)
            try container.encode(year.quarters, forKey: .quarters)
        }
        try container.encodeIfPresent(note, forKey: .note)
    }
}

/// Four quarters of three months, starting each year on `startMonth`/`startDay`.
/// The FY number is the calendar year the fiscal year ends in, minus 2000, plus `yearOffset`.
/// A day that does not exist in a month, such as 31 April, falls back to that month's last day.
public struct MonthRule: Equatable {
    public var startMonth: Int
    public var startDay: Int
    public var yearOffset: Int

    public init(startMonth: Int, startDay: Int, yearOffset: Int = 0) {
        self.startMonth = startMonth
        self.startDay = startDay
        self.yearOffset = yearOffset
    }
}

/// One fiscal year with its quarters written out. Quarters are numbered in order from 1.
public struct ExplicitYear: Equatable {
    public var fiscalYear: Int
    public var quarters: [QuarterSpan]

    public init(fiscalYear: Int, quarters: [QuarterSpan]) {
        self.fiscalYear = fiscalYear
        self.quarters = quarters
    }
}

/// The first and last day of a quarter, both included.
public struct QuarterSpan: Equatable, Codable {
    public var start: CalendarDate
    public var end: CalendarDate

    public init(start: CalendarDate, end: CalendarDate) {
        self.start = start
        self.end = end
    }
}

public struct DefinitionError: Error, CustomStringConvertible {
    public let description: String

    init(_ description: String) {
        self.description = description
    }
}
