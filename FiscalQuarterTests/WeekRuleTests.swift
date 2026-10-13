import Foundation
import XCTest

#if canImport(FiscalQuarterCore)
import FiscalQuarterCore
#endif

final class WeekRuleTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: year, month: month, day: day)
    }

    /// Days from `start` through `end`, counting both.
    private func inclusiveDays(from start: CalendarDate, to end: CalendarDate) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = calendar.date(from: DateComponents(year: start.year, month: start.month, day: start.day))!
        let to = calendar.date(from: DateComponents(year: end.year, month: end.month, day: end.day))!
        return calendar.dateComponents([.day], from: from, to: to).day! + 1
    }

    /// The year ends on the last Saturday of September, with a 53rd week in Q1, as Apple keeps it.
    private let lastSaturdayOfSeptember = WeekRule(endMonth: 9, endWeekday: 7, method: .last, extraWeek: .q1)
    /// The year ends on the last Saturday of July, as Cisco keeps it.
    private let lastSaturdayOfJuly = WeekRule(endMonth: 7, endWeekday: 7, method: .last)

    // MARK: Year ends, against published fiscal calendars

    func testRetailYearEndsOnTheSaturdayNearestJanuary31() {
        // The NRF 4-5-4 calendar's fiscal years 2022 through 2026.
        XCTAssertEqual(WeekRule.retail.yearEnd(in: 2023), date(2023, 1, 28))
        XCTAssertEqual(WeekRule.retail.yearEnd(in: 2024), date(2024, 2, 3))
        XCTAssertEqual(WeekRule.retail.yearEnd(in: 2025), date(2025, 2, 1))
        XCTAssertEqual(WeekRule.retail.yearEnd(in: 2026), date(2026, 1, 31))
        XCTAssertEqual(WeekRule.retail.yearEnd(in: 2027), date(2027, 1, 30))
    }

    func testLastSaturdayOfTheMonth() {
        XCTAssertEqual(lastSaturdayOfSeptember.yearEnd(in: 2022), date(2022, 9, 24))
        XCTAssertEqual(lastSaturdayOfSeptember.yearEnd(in: 2023), date(2023, 9, 30))
        XCTAssertEqual(lastSaturdayOfSeptember.yearEnd(in: 2024), date(2024, 9, 28))
        XCTAssertEqual(lastSaturdayOfSeptember.yearEnd(in: 2025), date(2025, 9, 27))
        XCTAssertEqual(lastSaturdayOfJuly.yearEnd(in: 2024), date(2024, 7, 27))
        XCTAssertEqual(lastSaturdayOfJuly.yearEnd(in: 2025), date(2025, 7, 26))
    }

    // MARK: Quarters

    func testA53WeekRetailYearPutsTheExtraWeekInQ4() {
        let calendar = FiscalCalendarDefinition.weeks(.retail)
        let q4 = FiscalCalendar.quarter(containing: date(2024, 2, 3), in: calendar)
        XCTAssertEqual(q4.id, "FY23-Q4")
        XCTAssertEqual(q4.start, date(2023, 10, 29))
        XCTAssertEqual(inclusiveDays(from: q4.start, to: q4.end), 98)
        let q1 = FiscalCalendar.quarter(containing: date(2024, 2, 4), in: calendar)
        XCTAssertEqual(q1.id, "FY24-Q1")
        XCTAssertEqual(q1.end, date(2024, 5, 4))
    }

    func testTheExtraWeekCanGoToQ1() {
        let calendar = FiscalCalendarDefinition.weeks(lastSaturdayOfSeptember)
        let q1 = FiscalCalendar.quarter(containing: date(2022, 10, 1), in: calendar)
        XCTAssertEqual(q1.id, "FY23-Q1")
        XCTAssertEqual(q1.start, date(2022, 9, 25))
        XCTAssertEqual(q1.end, date(2022, 12, 31))
        XCTAssertEqual(FiscalCalendar.quarter(containing: date(2023, 1, 1), in: calendar).id, "FY23-Q2")
        XCTAssertEqual(FiscalCalendar.quarter(containing: date(2023, 9, 30), in: calendar).id, "FY23-Q4")
        XCTAssertEqual(FiscalCalendar.quarter(containing: date(2023, 10, 1), in: calendar).id, "FY24-Q1")
    }

    func testQuartersTileTwentyYearsWithoutGaps() {
        for rule in [WeekRule.retail, lastSaturdayOfSeptember, lastSaturdayOfJuly, WeekRule(endMonth: 12, endWeekday: 1, method: .nearest)] {
            let calendar = FiscalCalendarDefinition.weeks(rule)
            var quarter = FiscalCalendar.quarter(containing: date(2015, 1, 1), in: calendar)
            var longYears = 0
            for _ in 0..<80 {
                let days = inclusiveDays(from: quarter.start, to: quarter.end)
                XCTAssertTrue(days == 91 || days == 98, "\(rule.summary) \(quarter.id) is \(days) days")
                XCTAssertEqual(FiscalCalendar.weekday(quarter.end), rule.endWeekday)
                if days == 98 { longYears += 1 }
                let next = FiscalCalendar.quarter(after: quarter, in: calendar)
                XCTAssertEqual(inclusiveDays(from: quarter.end, to: next.start), 2, quarter.id)
                if quarter.quarter == 4 {
                    XCTAssertEqual(next.quarter, 1)
                    XCTAssertEqual(next.fiscalYear, quarter.fiscalYear + 1)
                } else {
                    XCTAssertEqual(next.quarter, quarter.quarter + 1)
                }
                quarter = next
            }
            // A 53rd week comes every five or six years.
            XCTAssertTrue((3...4).contains(longYears), "\(rule.summary): \(longYears) long years in 20")
        }
    }

    // MARK: Periods

    func testPeriodsFollowThePatternAndAreNamedForTheMonthTheyMostlyCover() {
        let map = FiscalYearMap.containing(date(2026, 10, 13), calendar: .weeks(.retail))
        XCTAssertEqual(map.fiscalYear, 26)
        XCTAssertEqual(map.months.count, 12)
        XCTAssertEqual(map.months.map(\.symbol), ["Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan"])
        // 4-5-4: four weeks, five, then four.
        XCTAssertEqual(map.months.prefix(3).map(\.length), [28, 35, 28])
        XCTAssertEqual(map.months.reduce(0) { $0 + $1.length }, map.length)
    }

    func testThe53rdWeekGoesToTheLastPeriodOfItsQuarter() {
        let map = FiscalYearMap.containing(date(2024, 1, 15), calendar: .weeks(.retail))
        XCTAssertEqual(map.months.suffix(3).map(\.length), [28, 35, 35])
        let early = FiscalYearMap.containing(date(2022, 10, 1), calendar: .weeks(WeekRule(endMonth: 9, method: .last, pattern: .p445, extraWeek: .q1)))
        XCTAssertEqual(early.months.prefix(3).map(\.length), [28, 28, 42])
    }

    // MARK: Files and settings

    func testACalendarFileCanUseTheWeeksRule() throws {
        let json = #"{ "name": "Retail", "eras": [ { "rule": "weeks", "endMonth": 1, "endWeekday": "saturday", "method": "nearest", "pattern": "4-5-4", "yearOffset": -1 } ] }"#
        let definition = try FiscalCalendarDefinition(json: Data(json.utf8))
        XCTAssertEqual(definition, .weeks(.retail, name: "Retail"))
        let again = try FiscalCalendarDefinition(json: JSONEncoder().encode(definition))
        XCTAssertEqual(again, definition)
        XCTAssertEqual(definition.summary, "Ends the Saturday nearest 31 January, 4-5-4")
    }

    func testABadWeeksRuleIsRefused() {
        let json = #"{ "eras": [ { "rule": "weeks", "endMonth": 1, "endWeekday": "someday" } ] }"#
        XCTAssertThrowsError(try FiscalCalendarDefinition(json: Data(json.utf8)))
    }

    func testTheSettingRoundTripsThroughDefaults() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let config = FiscalYearConfig(kind: .weeks, startMonth: 1, startDay: 1, weekRule: lastSaturdayOfJuly)
        config.save(to: defaults)
        XCTAssertEqual(FiscalYearConfig.load(from: defaults), config)
        XCTAssertEqual(FiscalYearConfig.load(from: defaults).definition, .weeks(lastSaturdayOfJuly))
    }
}
