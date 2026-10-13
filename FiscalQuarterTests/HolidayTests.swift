import Foundation
import XCTest

#if canImport(FiscalQuarterCore)
import FiscalQuarterCore
#endif

final class HolidayTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: year, month: month, day: day)
    }

    private func dates(_ region: HolidayRegion, _ year: Int) -> [String] {
        region.holidays(in: year).map(\.date.iso)
    }

    // MARK: Rules, checked against each government's published dates

    func testUnitedStates2026KeepsASaturdayHolidayOnTheFriday() {
        XCTAssertEqual(dates(.unitedStates, 2026), [
            "2026-01-01", "2026-01-19", "2026-02-16", "2026-05-25", "2026-06-19", "2026-07-03",
            "2026-09-07", "2026-10-12", "2026-11-11", "2026-11-26", "2026-12-25",
        ])
    }

    func testUnitedStatesNewYearOnASaturdayFallsInTheYearBefore() {
        // 1 January 2028 is a Saturday, kept on Friday 31 December 2027. Christmas 2027 is a Saturday too.
        XCTAssertEqual(HolidayRegion.unitedStates.holiday(on: date(2027, 12, 31))?.name, "New Year's Day")
        XCTAssertEqual(HolidayRegion.unitedStates.holiday(on: date(2027, 12, 24))?.name, "Christmas Day")
    }

    func testUnitedKingdomSubstitutesForward() {
        XCTAssertEqual(dates(.unitedKingdom, 2026), [
            "2026-01-01", "2026-04-03", "2026-04-06", "2026-05-04", "2026-05-25", "2026-08-31", "2026-12-25", "2026-12-28",
        ])
        // Christmas on a Saturday and Boxing Day on a Sunday become Monday and Tuesday.
        XCTAssertEqual(dates(.unitedKingdom, 2027), [
            "2027-01-01", "2027-03-26", "2027-03-29", "2027-05-03", "2027-05-31", "2027-08-30", "2027-12-27", "2027-12-28",
        ])
    }

    func testCanada2026() {
        XCTAssertEqual(dates(.canada, 2026), [
            "2026-01-01", "2026-04-03", "2026-05-18", "2026-07-01", "2026-09-07", "2026-09-30",
            "2026-10-12", "2026-11-11", "2026-12-25", "2026-12-28",
        ])
    }

    func testIrelandStBrigidsDay() {
        XCTAssertEqual(HolidayRegion.ireland.holidays(in: 2026).first { $0.name == "St Brigid's Day" }?.date, date(2026, 2, 2))
        // 1 February 2030 is a Friday, so the holiday is that day.
        XCTAssertEqual(HolidayRegion.ireland.holidays(in: 2030).first { $0.name == "St Brigid's Day" }?.date, date(2030, 2, 1))
        XCTAssertNil(HolidayRegion.ireland.holidays(in: 2022).first { $0.name == "St Brigid's Day" })
        XCTAssertEqual(HolidayRegion.ireland.holidays(in: 2026).first { $0.name == "October bank holiday" }?.date, date(2026, 10, 26))
    }

    func testAustraliaKeepsAnzacDayOnItsDay() {
        let holidays = HolidayRegion.australia.holidays(in: 2026)
        XCTAssertEqual(holidays.first { $0.name == "Anzac Day" }?.date, date(2026, 4, 25))
        XCTAssertEqual(holidays.first { $0.name == "Boxing Day" }?.date, date(2026, 12, 28))
    }

    func testGermanyAndFranceFollowEaster() {
        XCTAssertEqual(dates(.germany, 2026), [
            "2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-05-14", "2026-05-25", "2026-10-03", "2026-12-25", "2026-12-26",
        ])
        XCTAssertEqual(HolidayRegion.france.holidays(in: 2026).count, 11)
        XCTAssertEqual(HolidayRegion.france.holiday(on: date(2026, 5, 14))?.name, "Ascension Day")
    }

    func testEaster() {
        let known = ["2024-03-31", "2025-04-20", "2026-04-05", "2027-03-28", "2038-04-25", "2285-03-22"]
        for iso in known {
            let expected = CalendarDate(iso: iso)!
            XCTAssertEqual(HolidayRegion.easter(expected.year), expected, iso)
        }
    }

    // MARK: Counting

    func testWorkdaysSkipHolidays() {
        // From Tuesday 13 October 2026 to 31 December: 58 weekdays, less Veterans Day,
        // Thanksgiving, and Christmas.
        let plain = QuarterSnapshot(on: date(2026, 10, 13)).countdown(to: .quarter)
        let us = QuarterSnapshot(on: date(2026, 10, 13), workweek: Workweek(region: .unitedStates)).countdown(to: .quarter)
        XCTAssertEqual(plain.workdays, 58)
        XCTAssertEqual(us.workdays, 55)
        XCTAssertEqual(us.days, plain.days)
    }

    func testDaysOffCountOnlyOnWeekdays() {
        let off = Workweek(daysOff: [date(2026, 12, 28), date(2026, 12, 26)])
        let countdown = QuarterSnapshot(on: date(2026, 12, 21), workweek: off).countdown(to: .quarter)
        // 21–31 December has 9 weekdays. Monday the 28th is off; Saturday the 26th changes nothing.
        XCTAssertEqual(countdown.workdays, 8)
        XCTAssertFalse(off.isWorkday(date(2026, 12, 28)))
        XCTAssertTrue(off.isWorkday(date(2026, 12, 29)))
    }

    func testAHolidayAndADayOffOnTheSameDateCountOnce() {
        let both = Workweek(region: .unitedStates, daysOff: [date(2026, 12, 25)])
        let countdown = QuarterSnapshot(on: date(2026, 12, 21), workweek: both).countdown(to: .quarter)
        XCTAssertEqual(countdown.workdays, 8)
    }

    func testWorkdaysMatchADayByDayCount() throws {
        let workweek = Workweek(region: .unitedKingdom, daysOff: [date(2027, 2, 15)])
        var today = date(2026, 9, 1)
        for _ in 0..<500 {
            let countdown = QuarterSnapshot(on: today, workweek: workweek).countdown(to: .year)
            var count = 0
            var cursor = today
            while cursor <= countdown.end {
                if workweek.isWorkday(cursor) { count += 1 }
                cursor = Self.dayAfter(cursor)
            }
            XCTAssertEqual(countdown.workdays, count, today.iso)
            today = Self.dayAfter(today)
        }
    }

    // MARK: Milestones and reminders

    func testWorkdayMilestonesSkipHolidays() {
        // Five workdays before Thursday 31 December 2026, skipping Christmas, is Wednesday the 23rd.
        let forecast = Milestone(name: "Forecast due", offset: 5)
        let us = Workweek(region: .unitedStates)
        XCTAssertEqual(forecast.next(onOrAfter: date(2026, 10, 13), in: .builtIn, workweek: us)?.date, date(2026, 12, 23))
        XCTAssertEqual(forecast.next(onOrAfter: date(2026, 10, 13), in: .builtIn)?.date, date(2026, 12, 24))
    }

    func testAMilestoneOnAHolidayMovesToTheWorkdayBefore() {
        // Quarter start of FY27-Q1 is New Year's Day, a Friday, so it moves to Thursday 31 December.
        let kickoff = Milestone(name: "Kickoff", offset: 0, unit: .days, anchor: .quarterStart)
        let q1 = FiscalCalendar.quarter(containing: date(2027, 1, 5))
        XCTAssertEqual(kickoff.date(in: q1, workweek: Workweek(region: .unitedStates)), date(2026, 12, 31))
        var kept = kickoff
        kept.weekend = .keep
        XCTAssertEqual(kept.date(in: q1, workweek: Workweek(region: .unitedStates)), date(2027, 1, 1))
    }

    func testReminderLeadsSkipHolidays() {
        // Two workdays ahead of Wednesday 23 December, skipping nothing, is Monday the 21st.
        let forecast = Milestone(name: "Forecast due", offset: 5, reminderLead: 2)
        let plan = ReminderPlan.plan(
            settings: ReminderSettings(milestones: true),
            milestones: [forecast],
            calendar: .builtIn,
            today: date(2026, 12, 2),
            workweek: Workweek(region: .unitedStates)
        )
        XCTAssertEqual(plan.map(\.date.iso), ["2026-12-21"])
        XCTAssertEqual(Milestone.workdays(1, before: date(2026, 12, 28), workweek: Workweek(region: .unitedStates)), date(2026, 12, 24))
    }

    // MARK: Storage

    func testWorkweekRoundTripsThroughDefaults() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(Workweek.load(from: defaults), .weekdays)
        let workweek = Workweek(region: .germany, daysOff: [date(2026, 12, 31)])
        workweek.save(to: defaults)
        XCTAssertEqual(Workweek.load(from: defaults), workweek)
    }

    private static func dayAfter(_ date: CalendarDate) -> CalendarDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))!
        return CalendarDate(calendar.date(byAdding: .day, value: 1, to: day)!, calendar: calendar)
    }
}
