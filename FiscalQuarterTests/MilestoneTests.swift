import Foundation
import XCTest

#if canImport(FiscalQuarterCore)
import FiscalQuarterCore
#endif

final class MilestoneTests: XCTestCase {
    private let builtIn = FiscalCalendarDefinition.builtIn

    private func date(_ year: Int, _ month: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: year, month: month, day: day)
    }

    private func quarter(on year: Int, _ month: Int, _ day: Int, in calendar: FiscalCalendarDefinition = .builtIn) -> FiscalQuarter {
        FiscalCalendar.quarter(containing: date(year, month, day), in: calendar)
    }

    // MARK: Dates in one quarter

    func testWorkdaysBeforeQuarterEndSkipTheWeekend() {
        // FY26-Q4 ends Thursday 31 December 2026. Five weekdays back is Thursday the 24th.
        let forecast = Milestone(name: "Forecast due", offset: 5)
        XCTAssertEqual(forecast.date(in: quarter(on: 2026, 10, 1)), date(2026, 12, 24))
    }

    func testZeroIsTheAnchorDay() {
        let q4 = quarter(on: 2026, 10, 1)
        XCTAssertEqual(Milestone(name: "Close", offset: 0, unit: .days).date(in: q4), date(2026, 12, 31))
        XCTAssertEqual(Milestone(name: "Kickoff", offset: 0, unit: .days, anchor: .quarterStart).date(in: q4), date(2026, 10, 1))
    }

    func testWeeksAfterQuarterStart() {
        let review = Milestone(name: "Pipeline review", offset: 2, unit: .weeks, direction: .after, anchor: .quarterStart)
        XCTAssertEqual(review.date(in: quarter(on: 2026, 10, 1)), date(2026, 10, 15))
    }

    func testAWeekendDayMovesToTheFridayBeforeUnlessKept() {
        // Five days before Thursday 31 December 2026 is Saturday the 26th.
        let moved = Milestone(name: "Deck", offset: 5, unit: .days)
        XCTAssertEqual(moved.date(in: quarter(on: 2026, 10, 1)), date(2026, 12, 25))
        let kept = Milestone(name: "Deck", offset: 5, unit: .days, weekend: .keep)
        XCTAssertEqual(kept.date(in: quarter(on: 2026, 10, 1)), date(2026, 12, 26))
    }

    func testTheShortTransitionQuarterUsesItsOwnEnd() {
        // In the February calendar, FY27-Q3 is August and September 2026 only.
        let february = FiscalCalendarTests.february
        let q3 = quarter(on: 2026, 8, 15, in: february)
        XCTAssertEqual(q3.id, "FY27-Q3")
        let close = Milestone(name: "Close", offset: 0, unit: .days, quarters: [3])
        XCTAssertEqual(close.next(onOrAfter: date(2026, 8, 15), in: february)?.date, date(2026, 9, 30))
    }

    // MARK: The next date

    func testTheNextDateIsTodayOnTheDayItself() throws {
        let forecast = Milestone(name: "Forecast due", offset: 5)
        let next = try XCTUnwrap(forecast.next(onOrAfter: date(2026, 12, 24), in: builtIn))
        XCTAssertEqual(next.date, date(2026, 12, 24))
        XCTAssertEqual(next.countdown(from: date(2026, 12, 24)).days, 1)
    }

    func testAPassedDateRollsToTheNextQuarter() throws {
        // FY27-Q1 ends Wednesday 31 March 2027. Five weekdays back is Wednesday the 24th.
        let forecast = Milestone(name: "Forecast due", offset: 5)
        let next = try XCTUnwrap(forecast.next(onOrAfter: date(2026, 12, 28), in: builtIn))
        XCTAssertEqual(next.date, date(2027, 3, 24))
        XCTAssertEqual(next.quarter.id, "FY27-Q1")
    }

    func testARuleAfterQuarterEndLandsInTheNextQuarter() throws {
        // Ten days after FY26-Q3 ends on 30 September is Saturday 10 October, so Friday the 9th.
        let commissions = Milestone(name: "Commissions", offset: 10, unit: .days, direction: .after)
        let next = try XCTUnwrap(commissions.next(onOrAfter: date(2026, 10, 5), in: builtIn))
        XCTAssertEqual(next.date, date(2026, 10, 9))
        XCTAssertEqual(next.quarter.id, "FY26-Q3")
    }

    func testAOneQuarterRuleWaitsForThatQuarter() throws {
        // FY27-Q4 ends Friday 31 December 2027. Five weekdays back is Friday the 24th.
        let plan = Milestone(name: "Annual plan", offset: 5, quarters: [4])
        let next = try XCTUnwrap(plan.next(onOrAfter: date(2027, 1, 5), in: builtIn))
        XCTAssertEqual(next.date, date(2027, 12, 24))
        XCTAssertEqual(next.quarter.id, "FY27-Q4")
    }

    func testTheLongestOffsetStillFindsADate() throws {
        let far = Milestone(name: "Far", offset: Milestone.maximumOffset, unit: .days, direction: .after, weekend: .keep)
        let next = try XCTUnwrap(far.next(onOrAfter: date(2026, 10, 12), in: builtIn))
        // A year and a day after FY25-Q4 ends on 31 December 2025, four quarters back.
        XCTAssertEqual(next.date, date(2027, 1, 1))
        XCTAssertEqual(next.quarter.id, "FY25-Q4")
    }

    func testEveryDateFromARuleIsOnOrAfterToday() {
        let rules = [
            Milestone(name: "A", offset: 5),
            Milestone(name: "B", offset: 3, unit: .weeks, direction: .after, anchor: .quarterStart),
            Milestone(name: "C", offset: 20, unit: .days, direction: .after, quarters: [2]),
            Milestone(name: "D", offset: 0, unit: .days, anchor: .quarterStart, weekend: .keep),
        ]
        var today = date(2026, 1, 1)
        for _ in 0..<400 {
            for rule in rules {
                guard let next = rule.next(onOrAfter: today, in: builtIn) else {
                    return XCTFail("\(rule.name) has no date after \(today.iso)")
                }
                XCTAssertGreaterThanOrEqual(next.date, today, "\(rule.name) on \(today.iso)")
                XCTAssertTrue(rule.applies(to: next.quarter), "\(rule.name) on \(today.iso)")
            }
            today = dayAfter(today)
        }
    }

    func testUpcomingIsSoonestFirst() {
        let list = [
            Milestone(name: "Forecast due", offset: 5),
            Milestone(name: "Pipeline review", offset: 2, unit: .weeks, direction: .after, anchor: .quarterStart),
            Milestone(name: "Close", offset: 0, unit: .days),
        ]
        let upcoming = Milestones.upcoming(list, onOrAfter: date(2026, 10, 12), in: builtIn)
        XCTAssertEqual(upcoming.map(\.milestone.name), ["Pipeline review", "Forecast due", "Close"])
        XCTAssertEqual(upcoming.map(\.date.iso), ["2026-10-15", "2026-12-24", "2026-12-31"])
    }

    // MARK: Words and checks

    func testSummaries() {
        XCTAssertEqual(Milestone(name: "F", offset: 5).summary, "5 workdays before quarter end, every quarter")
        XCTAssertEqual(Milestone(name: "F", offset: 1, unit: .weeks, direction: .after, anchor: .quarterStart).summary,
                       "1 week after quarter start, every quarter")
        XCTAssertEqual(Milestone(name: "F", offset: 0, quarters: [4]).summary, "On quarter end, Q4 only")
        XCTAssertEqual(Milestone(name: "F", offset: 2, unit: .days, quarters: [4, 2]).summary, "2 days before quarter end, Q2 and Q4")
        XCTAssertEqual(Milestone(name: "F", offset: 2, quarters: [1, 2, 3, 4]).quartersSummary, "every quarter")
    }

    func testProblems() {
        XCTAssertNil(Milestone(name: "Forecast", offset: 5).problem)
        XCTAssertNotNil(Milestone(name: "  ", offset: 5).problem)
        XCTAssertNotNil(Milestone(name: "Forecast", offset: -1).problem)
        XCTAssertNotNil(Milestone(name: "Forecast", offset: Milestone.maximumOffset + 1).problem)
        XCTAssertNotNil(Milestone(name: "Forecast", offset: 5, quarters: [5]).problem)
    }

    func testAMilestoneCountdownHasNoPeriod() {
        let occurrence = Milestone(name: "Forecast due", offset: 5).next(onOrAfter: date(2026, 10, 12), in: builtIn)
        let countdown = occurrence?.countdown(from: date(2026, 10, 12))
        XCTAssertNil(countdown?.target)
        XCTAssertEqual(countdown?.label, "Forecast due")
        XCTAssertEqual(countdown?.phrase(in: .days), "74 days")
    }

    func testAMilestoneIsSoonInItsLastWeekAndAPeriodInItsLastTwo() {
        let eightDays = Milestone(name: "F", offset: 0, unit: .days).next(onOrAfter: date(2026, 12, 24), in: builtIn)!
        XCTAssertFalse(eightDays.countdown(from: date(2026, 12, 24)).isSoon)
        XCTAssertTrue(eightDays.countdown(from: date(2026, 12, 25)).isSoon)
        XCTAssertFalse(QuarterSnapshot(on: date(2026, 12, 17)).countdown(to: .quarter).isSoon)
        XCTAssertTrue(QuarterSnapshot(on: date(2026, 12, 18)).countdown(to: .quarter).isSoon)
    }

    // MARK: Storage

    func testMilestonesRoundTripThroughDefaults() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(Milestones.load(from: defaults), [])

        let saved = [
            Milestone(name: "Forecast due", offset: 5),
            Milestone(name: "Annual plan", offset: 3, unit: .weeks, quarters: [4], weekend: .keep),
        ]
        Milestones.save(saved, to: defaults)
        XCTAssertEqual(Milestones.load(from: defaults), saved)
    }

    func testMilestonesSkipAnEntryThatNoLongerDecodes() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let good = Milestone(name: "Forecast due", offset: 5)
        defaults.set([Data("not json".utf8), try JSONEncoder().encode(good)], forKey: "milestones")
        XCTAssertEqual(Milestones.load(from: defaults), [good])
    }

    private func dayAfter(_ date: CalendarDate) -> CalendarDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))!
        return CalendarDate(calendar.date(byAdding: .day, value: 1, to: day)!, calendar: calendar)
    }
}
