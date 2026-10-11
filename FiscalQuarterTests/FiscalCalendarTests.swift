import Foundation
import XCTest

// Swift Package builds this against the FiscalQuarterCore module.
// The Xcode test target compiles FiscalCalendar.swift into the test bundle instead.
#if canImport(FiscalQuarterCore)
import FiscalQuarterCore
#endif

final class FiscalCalendarTests: XCTestCase {
    /// The February calendar with the 11-month FY27 that used to be built in. It keeps the explicit-era
    /// and transition behaviour covered now that the built-in calendar is the calendar year.
    static let february: FiscalCalendarDefinition = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("calendars/february-transition.json")
        // The file is checked in beside the tests, so failing to read it is a broken checkout.
        return try! FiscalCalendarDefinition(json: Data(contentsOf: url))
    }()

    func testOctober52026IsFY26Q4() {
        let today = CalendarDate(year: 2026, month: 10, day: 5)
        let quarter = FiscalCalendar.quarter(containing: today)

        XCTAssertEqual(quarter.id, "FY26-Q4")
        XCTAssertEqual(quarter.fiscalYear, 26)
        XCTAssertEqual(quarter.quarter, 4)
        XCTAssertEqual(quarter.start, CalendarDate(year: 2026, month: 10, day: 1))
        XCTAssertEqual(quarter.end, CalendarDate(year: 2026, month: 12, day: 31))
        XCTAssertEqual(quarter.daysRemaining(on: today), 88)
    }

    func testFebruaryCalendarRanges() {
        assertQuarter("FY25-Q4", 2024, 11, 1, 2025, 1, 31, on: 2025, 1, 31)
        assertQuarter("FY26-Q1", 2025, 2, 1, 2025, 4, 30, on: 2025, 2, 1)
        assertQuarter("FY26-Q1", 2025, 2, 1, 2025, 4, 30, on: 2025, 4, 30)
        assertQuarter("FY26-Q2", 2025, 5, 1, 2025, 7, 31, on: 2025, 5, 1)
        assertQuarter("FY26-Q2", 2025, 5, 1, 2025, 7, 31, on: 2025, 7, 31)
        assertQuarter("FY26-Q3", 2025, 8, 1, 2025, 10, 31, on: 2025, 8, 1)
        assertQuarter("FY26-Q3", 2025, 8, 1, 2025, 10, 31, on: 2025, 10, 1)
        assertQuarter("FY26-Q3", 2025, 8, 1, 2025, 10, 31, on: 2025, 10, 31)
        assertQuarter("FY26-Q4", 2025, 11, 1, 2026, 1, 31, on: 2025, 11, 1)
        assertQuarter("FY26-Q4", 2025, 11, 1, 2026, 1, 31, on: 2026, 1, 31)

        assertQuarter("FY27-Q1", 2026, 2, 1, 2026, 4, 30, on: 2026, 2, 1)
        assertQuarter("FY27-Q1", 2026, 2, 1, 2026, 4, 30, on: 2026, 4, 30)
        assertQuarter("FY27-Q2", 2026, 5, 1, 2026, 7, 31, on: 2026, 5, 1)
        assertQuarter("FY27-Q2", 2026, 5, 1, 2026, 7, 31, on: 2026, 7, 31)
        assertQuarter("FY27-Q3", 2026, 8, 1, 2026, 9, 30, on: 2026, 8, 1)
        assertQuarter("FY27-Q3", 2026, 8, 1, 2026, 9, 30, on: 2026, 9, 30)
        assertQuarter("FY27-Q4", 2026, 10, 1, 2026, 12, 31, on: 2026, 10, 1)
        assertQuarter("FY27-Q4", 2026, 10, 1, 2026, 12, 31, on: 2026, 10, 5)
        assertQuarter("FY27-Q4", 2026, 10, 1, 2026, 12, 31, on: 2026, 12, 31)

        assertQuarter("FY28-Q1", 2027, 1, 1, 2027, 3, 31, on: 2027, 1, 1)
        assertQuarter("FY28-Q1", 2027, 1, 1, 2027, 3, 31, on: 2027, 3, 31)
        assertQuarter("FY28-Q2", 2027, 4, 1, 2027, 6, 30, on: 2027, 4, 1)
        assertQuarter("FY28-Q2", 2027, 4, 1, 2027, 6, 30, on: 2027, 6, 30)
        assertQuarter("FY28-Q3", 2027, 7, 1, 2027, 9, 30, on: 2027, 7, 1)
        assertQuarter("FY28-Q3", 2027, 7, 1, 2027, 9, 30, on: 2027, 9, 30)
        assertQuarter("FY28-Q4", 2027, 10, 1, 2027, 12, 31, on: 2027, 10, 5)
        assertQuarter("FY28-Q4", 2027, 10, 1, 2027, 12, 31, on: 2027, 12, 31)
        assertQuarter("FY29-Q1", 2028, 1, 1, 2028, 3, 31, on: 2028, 1, 1)
    }

    func testOctober2025StaysInFY26Q3() {
        let october = FiscalCalendar.quarter(containing: CalendarDate(year: 2025, month: 10, day: 5), in: Self.february)
        XCTAssertEqual(october.id, "FY26-Q3")
        XCTAssertEqual(october.end, CalendarDate(year: 2025, month: 10, day: 31))
    }

    func testLeapDayStaysInQ1() {
        assertQuarter("FY25-Q1", 2024, 2, 1, 2024, 4, 30, on: 2024, 2, 29)
    }

    func testDaysRemainingLiterals() {
        assertDays(88, on: 2026, 10, 5)
        assertDays(92, on: 2026, 10, 1)
        assertDays(1, on: 2026, 12, 31)
        assertDays(61, on: 2026, 8, 1)
        assertDays(1, on: 2026, 9, 30)
        assertDays(92, on: 2025, 11, 1)
        assertDays(17, on: 2026, 1, 15)
    }

    func testDaysRemainingMatchesGregorianSpan() throws {
        let samples = [
            CalendarDate(year: 2024, month: 2, day: 29),
            CalendarDate(year: 2026, month: 10, day: 5),
            CalendarDate(year: 2026, month: 10, day: 1),
            CalendarDate(year: 2026, month: 12, day: 31),
            CalendarDate(year: 2026, month: 8, day: 1),
            CalendarDate(year: 2025, month: 11, day: 1),
            CalendarDate(year: 2027, month: 2, day: 28),
        ]
        let calendar = utcCalendar()
        for sample in samples {
            let quarter = FiscalCalendar.quarter(containing: sample, in: Self.february)
            let from = try XCTUnwrap(calendar.date(from: components(sample)))
            let to = try XCTUnwrap(calendar.date(from: components(quarter.end)))
            let span = try XCTUnwrap(calendar.dateComponents([.day], from: from, to: to).day)
            XCTAssertEqual(quarter.daysRemaining(on: sample), span + 1, sample.iso)
        }
    }

    func testQuartersTileTheTimelineWithoutGaps() throws {
        for definition in [FiscalCalendarDefinition.builtIn, Self.february] {
            try assertQuartersTile(definition)
        }
    }

    private func assertQuartersTile(_ definition: FiscalCalendarDefinition) throws {
        let calendar = utcCalendar()
        // Start on the first day of a quarter, so the walk can check every boundary it crosses.
        let first = FiscalCalendar.quarter(containing: CalendarDate(year: 2023, month: 2, day: 1), in: definition).start
        var cursor = try XCTUnwrap(calendar.date(from: components(first)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2028, month: 6, day: 30)))
        var previous: FiscalQuarter?

        while cursor <= end {
            let civil = CalendarDate(cursor, calendar: calendar)
            let quarter = FiscalCalendar.quarter(containing: civil, in: definition)
            XCTAssertGreaterThanOrEqual(civil, quarter.start, civil.iso)
            XCTAssertLessThanOrEqual(civil, quarter.end, civil.iso)

            if let previous, previous.id != quarter.id {
                let nextDay = try dayAfter(previous.end, calendar: calendar)
                XCTAssertEqual(
                    quarter.start,
                    nextDay,
                    "Gap or overlap between \(previous.id) and \(quarter.id)"
                )
                XCTAssertEqual(civil, quarter.start, civil.iso)
            } else if previous == nil {
                XCTAssertEqual(civil, quarter.start)
            }

            previous = quarter
            cursor = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: cursor))
        }
    }

    func testLocalTimeZoneDecidesTheQuarterOnTheOctoberBoundary() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        var components = DateComponents()
        components.calendar = tokyo
        components.timeZone = tokyo.timeZone
        components.year = 2026
        components.month = 10
        components.day = 1
        components.hour = 0
        components.minute = 30
        let instant = try XCTUnwrap(components.date)

        XCTAssertEqual(FiscalCalendar.quarter(on: instant, calendar: tokyo).id, "FY26-Q4")
        XCTAssertEqual(FiscalCalendar.quarter(on: instant, calendar: losAngeles).id, "FY26-Q3")
    }

    func testOctober52026Snapshot() throws {
        let snapshot = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 5))

        XCTAssertEqual(snapshot.dayIndex, 5)
        XCTAssertEqual(snapshot.length, 92)
        XCTAssertEqual(snapshot.daysRemaining, 88)
        XCTAssertEqual(snapshot.week, 1)
        XCTAssertEqual(snapshot.percent, 5)
        XCTAssertEqual(snapshot.progressLine, "Day 5 of 92 · week 1")
        XCTAssertEqual(snapshot.statusLine, "FY26-Q4 · Day 5 of 92 · week 1 · 88 days left")
        XCTAssertEqual(snapshot.menuBarLabel, "FY26-Q4 · 88d")
        XCTAssertEqual(snapshot.next.id, "FY27-Q1")
        XCTAssertEqual(snapshot.next.start, CalendarDate(year: 2027, month: 1, day: 1))
        XCTAssertNil(snapshot.transitionNote)
        XCTAssertNil(snapshot.paceNote)

        let data = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["id"] as? String, "FY26-Q4")
        XCTAssertEqual(object["day"] as? Int, 5)
        XCTAssertEqual(object["length"] as? Int, 92)
        XCTAssertEqual(object["daysRemaining"] as? Int, 88)
        XCTAssertEqual(object["week"] as? Int, 1)
        XCTAssertEqual(object["percent"] as? Int, 5)
        XCTAssertEqual(object["next"] as? String, "FY27-Q1")
        XCTAssertEqual(object["nextStart"] as? String, "2027-01-01")
        XCTAssertNil(object["pace"])
    }

    func testOctober92026IsWeekTwo() {
        let snapshot = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 9))
        XCTAssertEqual(snapshot.dayIndex, 9)
        XCTAssertEqual(snapshot.daysRemaining, 84)
        XCTAssertEqual(snapshot.week, 2)
        XCTAssertEqual(snapshot.percent, 10)
        XCTAssertEqual(snapshot.menuBarLabel, "FY26-Q4 · 84d")
    }

    func testWeeksBreakEverySevenDays() {
        let start = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 7))
        let next = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 8))
        XCTAssertEqual(start.week, 1)
        XCTAssertEqual(next.week, 2)
    }

    func testPaceNotesAndLastDayCopy() {
        XCTAssertNil(QuarterSnapshot(on: CalendarDate(year: 2026, month: 12, day: 17)).paceNote)
        XCTAssertEqual(
            QuarterSnapshot(on: CalendarDate(year: 2026, month: 12, day: 18)).paceNote,
            "Last two weeks of the quarter."
        )
        XCTAssertEqual(
            QuarterSnapshot(on: CalendarDate(year: 2026, month: 12, day: 25)).paceNote,
            "Last week of the quarter."
        )
        let last = QuarterSnapshot(on: CalendarDate(year: 2026, month: 12, day: 31))
        XCTAssertEqual(last.dayIndex, 92)
        XCTAssertEqual(last.daysRemaining, 1)
        XCTAssertEqual(last.percent, 100)
        XCTAssertEqual(last.paceNote, "Last day of the quarter.")
        XCTAssertEqual(last.statusLine, "FY26-Q4 · Day 92 of 92 · week 14 · 1 day left")
    }

    func testFebruaryCalendarNextQuarterCrossesTheTransition() {
        let fy26q4 = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 1, day: 31), in: Self.february)
        let next = FiscalCalendar.quarter(after: fy26q4, in: Self.february)
        XCTAssertEqual(next.id, "FY27-Q1")
        XCTAssertEqual(next.start, CalendarDate(year: 2026, month: 2, day: 1))

        let fy27q3 = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 9, day: 30), in: Self.february)
        XCTAssertEqual(FiscalCalendar.quarter(after: fy27q3, in: Self.february).id, "FY27-Q4")
    }

    func testFebruaryCalendarHasNoNoteAfterTheTransition() {
        let snapshot = QuarterSnapshot(on: CalendarDate(year: 2027, month: 1, day: 1), calendar: Self.february)
        XCTAssertEqual(snapshot.quarter.id, "FY28-Q1")
        XCTAssertNil(snapshot.transitionNote)
        XCTAssertEqual(snapshot.length, 90)
        XCTAssertEqual(snapshot.dayIndex, 1)
    }

    func testFY27MapShowsTheShortThirdQuarter() {
        let map = FiscalYearMap.containing(CalendarDate(year: 2026, month: 10, day: 9), calendar: Self.february)

        XCTAssertEqual(map.fiscalYear, 27)
        XCTAssertEqual(map.quarters.map(\.id), ["FY27-Q1", "FY27-Q2", "FY27-Q3", "FY27-Q4"])
        XCTAssertEqual(map.months.map(\.symbol), [
            "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        ])
        XCTAssertEqual(map.months(in: map.quarters[2]).map(\.symbol), ["Aug", "Sep"])
        XCTAssertEqual(map.months(in: map.quarters[3]).map(\.symbol), ["Oct", "Nov", "Dec"])
        XCTAssertEqual(map.start, CalendarDate(year: 2026, month: 2, day: 1))
        XCTAssertEqual(map.end, CalendarDate(year: 2026, month: 12, day: 31))
        XCTAssertEqual(map.months.reduce(0) { $0 + $1.length }, map.length)

        let october = map.months[8]
        XCTAssertEqual(october.fill(on: CalendarDate(year: 2026, month: 10, day: 9)), 9 / 31, accuracy: 0.0001)
        XCTAssertEqual(map.months[7].fill(on: CalendarDate(year: 2026, month: 10, day: 9)), 1)
        XCTAssertEqual(map.months[9].fill(on: CalendarDate(year: 2026, month: 10, day: 9)), 0)
        XCTAssertEqual(
            map.summary(on: CalendarDate(year: 2026, month: 10, day: 9)),
            "FY27, Feb through Dec. Oct 9 is in Q4."
        )
    }

    func testOctober2026OpensOnAThursday() {
        let october = FiscalYearMap.containing(CalendarDate(year: 2026, month: 10, day: 1), calendar: Self.february).months[8]
        let cells = october.cells()
        XCTAssertEqual(FiscalCalendar.weekday(october.start), 5)
        XCTAssertNil(cells[0].date)
        XCTAssertEqual(cells[3].date, nil)
        XCTAssertEqual(cells[4].date, CalendarDate(year: 2026, month: 10, day: 1))
        XCTAssertEqual(cells[4 + 8].date, CalendarDate(year: 2026, month: 10, day: 9))
        XCTAssertEqual(cells.count % 7, 0)
    }

    func testFebruary2026StartsOnSunday() {
        let february = FiscalYearMap.containing(CalendarDate(year: 2026, month: 2, day: 1), calendar: Self.february).months[0]
        XCTAssertEqual(february.cells().first?.date, CalendarDate(year: 2026, month: 2, day: 1))
        XCTAssertEqual(february.length, 28)
    }

    func testLeapFebruaryStaysInTheMap() {
        let map = FiscalYearMap.containing(CalendarDate(year: 2024, month: 2, day: 29), calendar: Self.february)
        XCTAssertEqual(map.months[0].symbol, "Feb")
        XCTAssertEqual(map.months[0].length, 29)
        XCTAssertEqual(map.months.last?.symbol, "Jan")
        XCTAssertEqual(map.months.last?.start.year, 2025)
    }

    func testFY26ClosesInJanuary() {
        let map = FiscalYearMap.containing(CalendarDate(year: 2026, month: 1, day: 15), calendar: Self.february)
        XCTAssertEqual(map.fiscalYear, 26)
        XCTAssertEqual(map.months.first?.symbol, "Feb")
        XCTAssertEqual(map.months.first?.start, CalendarDate(year: 2025, month: 2, day: 1))
        XCTAssertEqual(map.months.last?.symbol, "Jan")
        XCTAssertEqual(map.months.last?.end, CalendarDate(year: 2026, month: 1, day: 31))
        XCTAssertEqual(map.quarters.count, 4)
    }

    func testCustomFebruaryStartNamesTheYearItEnds() {
        let config = FiscalYearConfig(kind: .custom, startMonth: 2, startDay: 1)
        let march = FiscalCalendar.quarter(containing: CalendarDate(year: 2025, month: 3, day: 15), config: config)
        XCTAssertEqual(march.id, "FY26-Q1")
        XCTAssertEqual(march.start, CalendarDate(year: 2025, month: 2, day: 1))
        XCTAssertEqual(march.end, CalendarDate(year: 2025, month: 4, day: 30))

        let october = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 10, day: 9), config: config)
        XCTAssertEqual(october.id, "FY27-Q3")
        XCTAssertEqual(october.start, CalendarDate(year: 2026, month: 8, day: 1))
        XCTAssertEqual(october.end, CalendarDate(year: 2026, month: 10, day: 31))

        let builtIn = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 10, day: 9))
        XCTAssertEqual(builtIn.id, "FY26-Q4")
        XCTAssertNil(QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 9), config: config).transitionNote)
    }

    func testCustomJanuaryStartStaysInTheSameCalendarYear() {
        let config = FiscalYearConfig(kind: .custom, startMonth: 1, startDay: 1)
        let october = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 10, day: 9), config: config)
        XCTAssertEqual(october.id, "FY26-Q4")
        XCTAssertEqual(october.start, CalendarDate(year: 2026, month: 10, day: 1))
        XCTAssertEqual(october.end, CalendarDate(year: 2026, month: 12, day: 31))
    }

    func testCustomOctoberStartIsTheFollowingFiscalYear() {
        let config = FiscalYearConfig(kind: .custom, startMonth: 10, startDay: 1)
        let october = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 10, day: 9), config: config)
        XCTAssertEqual(october.id, "FY27-Q1")
        XCTAssertEqual(october.start, CalendarDate(year: 2026, month: 10, day: 1))
        XCTAssertEqual(october.end, CalendarDate(year: 2026, month: 12, day: 31))
        let map = FiscalYearMap.containing(CalendarDate(year: 2026, month: 10, day: 9), config: config)
        XCTAssertEqual(map.end, CalendarDate(year: 2027, month: 9, day: 30))
    }

    func testCustomFebruary29ClampsInANonLeapYear() {
        let config = FiscalYearConfig(kind: .custom, startMonth: 2, startDay: 29)
        let march = FiscalCalendar.quarter(containing: CalendarDate(year: 2025, month: 3, day: 1), config: config)
        XCTAssertEqual(march.start, CalendarDate(year: 2025, month: 2, day: 28))
        XCTAssertEqual(march.fiscalYear, 26)
    }

    func testCustomQuartersTileAYear() throws {
        let config = FiscalYearConfig(kind: .custom, startMonth: 4, startDay: 15)
        let calendar = utcCalendar()
        var cursor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 4, day: 15)))
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 14)))
        var previous: FiscalQuarter?
        while cursor <= end {
            let civil = CalendarDate(cursor, calendar: calendar)
            let quarter = FiscalCalendar.quarter(containing: civil, config: config)
            XCTAssertGreaterThanOrEqual(civil, quarter.start, civil.iso)
            XCTAssertLessThanOrEqual(civil, quarter.end, civil.iso)
            if let previous, previous.id != quarter.id {
                XCTAssertEqual(quarter.start, try dayAfter(previous.end, calendar: calendar))
            }
            previous = quarter
            cursor = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: cursor))
        }
    }

    func testFiscalYearConfigRoundTripsThroughDefaults() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(FiscalYearConfig.load(from: defaults).kind, .builtIn)
        let config = FiscalYearConfig(kind: .custom, startMonth: 10, startDay: 1)
        config.save(to: defaults)
        XCTAssertEqual(FiscalYearConfig.load(from: defaults), config)
    }

    func testFebruaryCalendarFY28FollowsTheCalendarYear() {
        let map = FiscalYearMap.containing(CalendarDate(year: 2027, month: 4, day: 1), calendar: Self.february)
        XCTAssertEqual(map.fiscalYear, 28)
        XCTAssertEqual(map.months.first?.symbol, "Jan")
        XCTAssertEqual(map.months.map(\.quarter), [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4])
        XCTAssertEqual(map.end, CalendarDate(year: 2027, month: 12, day: 31))
    }

    func testOctober52026LocalMorningIsFY26Q4() throws {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        var components = DateComponents()
        components.calendar = losAngeles
        components.timeZone = losAngeles.timeZone
        components.year = 2026
        components.month = 10
        components.day = 5
        components.hour = 0
        components.minute = 30
        let instant = try XCTUnwrap(components.date)
        let quarter = FiscalCalendar.quarter(on: instant, calendar: losAngeles)
        let civil = CalendarDate(instant, calendar: losAngeles)

        XCTAssertEqual(civil, CalendarDate(year: 2026, month: 10, day: 5))
        XCTAssertEqual(quarter.id, "FY26-Q4")
        XCTAssertEqual(quarter.daysRemaining(on: civil), 88)
    }

    // MARK: Calendar definitions

    func testBuiltInFileMatchesTheBuiltInDefinition() throws {
        let definition = try FiscalCalendarDefinition(json: Data(contentsOf: calendarFile("built-in.json")))
        XCTAssertEqual(definition, .builtIn)
    }

    func testDefinitionRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(FiscalCalendarDefinition.builtIn)
        XCTAssertEqual(try FiscalCalendarDefinition(json: data), .builtIn)
    }

    func testCalendarYearFileStaysInTheSameYear() throws {
        let definition = try FiscalCalendarDefinition(json: Data(contentsOf: calendarFile("calendar-year.json")))
        let today = CalendarDate(year: 2026, month: 10, day: 11)
        let quarter = FiscalCalendar.quarter(containing: today, in: definition)
        XCTAssertEqual(quarter.id, "FY26-Q4")
        XCTAssertEqual(quarter.start, CalendarDate(year: 2026, month: 10, day: 1))
        XCTAssertEqual(quarter.end, CalendarDate(year: 2026, month: 12, day: 31))
        XCTAssertEqual(FiscalCalendar.quarter(containing: today, in: Self.february).id, "FY27-Q4")
    }

    func testBuiltInIsTheCalendarYear() {
        assertBuiltIn("FY26-Q1", 2026, 1, 1, 2026, 3, 31, on: 2026, 1, 1)
        assertBuiltIn("FY26-Q1", 2026, 1, 1, 2026, 3, 31, on: 2026, 3, 31)
        assertBuiltIn("FY26-Q2", 2026, 4, 1, 2026, 6, 30, on: 2026, 5, 15)
        assertBuiltIn("FY26-Q3", 2026, 7, 1, 2026, 9, 30, on: 2026, 9, 30)
        assertBuiltIn("FY26-Q4", 2026, 10, 1, 2026, 12, 31, on: 2026, 10, 11)
        assertBuiltIn("FY27-Q1", 2027, 1, 1, 2027, 3, 31, on: 2027, 1, 1)
        assertBuiltIn("FY25-Q4", 2025, 10, 1, 2025, 12, 31, on: 2025, 12, 31)
        assertBuiltIn("FY24-Q1", 2024, 1, 1, 2024, 3, 31, on: 2024, 2, 29)
        let map = FiscalYearMap.containing(CalendarDate(year: 2026, month: 10, day: 11))
        XCTAssertEqual(map.fiscalYear, 26)
        XCTAssertEqual(map.months.map(\.symbol), ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"])
        XCTAssertEqual(map.summary(on: CalendarDate(year: 2026, month: 10, day: 11)), "FY26, Jan through Dec. Oct 11 is in Q4.")
    }

    private func assertBuiltIn(
        _ id: String,
        _ startYear: Int, _ startMonth: Int, _ startDay: Int,
        _ endYear: Int, _ endMonth: Int, _ endDay: Int,
        on year: Int, _ month: Int, _ day: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let quarter = FiscalCalendar.quarter(containing: CalendarDate(year: year, month: month, day: day))
        XCTAssertEqual(quarter.id, id, file: file, line: line)
        XCTAssertEqual(quarter.start, CalendarDate(year: startYear, month: startMonth, day: startDay), file: file, line: line)
        XCTAssertEqual(quarter.end, CalendarDate(year: endYear, month: endMonth, day: endDay), file: file, line: line)
    }

    func testCustomConfigMatchesItsDefinition() throws {
        let config = FiscalYearConfig(kind: .custom, startMonth: 7, startDay: 1)
        var cursor = CalendarDate(year: 2024, month: 1, day: 1)
        while cursor < CalendarDate(year: 2029, month: 1, day: 1) {
            XCTAssertEqual(
                FiscalCalendar.quarter(containing: cursor, config: config),
                FiscalCalendar.quarter(containing: cursor, in: .months(startMonth: 7, startDay: 1)),
                cursor.iso
            )
            cursor = try dayAfter(cursor, calendar: utcCalendar())
        }
    }

    func testTransitionNoteComesFromTheEra() {
        let fy27 = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 11), calendar: Self.february)
        XCTAssertEqual(fy27.transitionNote, "FY27 ends December 31. FY28 follows the calendar year.")
        XCTAssertNil(QuarterSnapshot(on: CalendarDate(year: 2026, month: 1, day: 31), calendar: Self.february).transitionNote)
        XCTAssertNil(QuarterSnapshot(on: CalendarDate(year: 2027, month: 1, day: 1), calendar: Self.february).transitionNote)
    }

    func testMidYearEraClipsTheQuarterOnBothSides() throws {
        let definition = try FiscalCalendarDefinition(name: "Switch", eras: [
            Era(start: nil, rule: .months(MonthRule(startMonth: 1, startDay: 1))),
            Era(start: CalendarDate(year: 2030, month: 2, day: 15), rule: .months(MonthRule(startMonth: 4, startDay: 1))),
        ])
        let before = FiscalCalendar.quarter(containing: CalendarDate(year: 2030, month: 2, day: 14), in: definition)
        XCTAssertEqual(before.id, "FY30-Q1")
        XCTAssertEqual(before.end, CalendarDate(year: 2030, month: 2, day: 14))
        let after = FiscalCalendar.quarter(after: before, in: definition)
        XCTAssertEqual(after.id, "FY30-Q4")
        XCTAssertEqual(after.start, CalendarDate(year: 2030, month: 2, day: 15))
        XCTAssertEqual(after.end, CalendarDate(year: 2030, month: 3, day: 31))
    }

    func testDefinitionRejectsBadShapes() {
        let months = Era.Rule.months(MonthRule(startMonth: 1, startDay: 1))
        let gap = Era.Rule.explicit(ExplicitYear(fiscalYear: 30, quarters: [
            QuarterSpan(start: CalendarDate(year: 2030, month: 1, day: 1), end: CalendarDate(year: 2030, month: 6, day: 30)),
            QuarterSpan(start: CalendarDate(year: 2030, month: 7, day: 2), end: CalendarDate(year: 2030, month: 12, day: 31)),
        ]))
        let jan2030 = CalendarDate(year: 2030, month: 1, day: 1)
        let jan2031 = CalendarDate(year: 2031, month: 1, day: 1)

        XCTAssertThrowsError(try FiscalCalendarDefinition(name: "Empty", eras: []))
        XCTAssertThrowsError(try FiscalCalendarDefinition(name: "Dated first", eras: [Era(start: jan2030, rule: months)]))
        XCTAssertThrowsError(try FiscalCalendarDefinition(name: "Open explicit", eras: [Era(start: nil, rule: months), Era(start: jan2030, rule: gap)]))
        XCTAssertThrowsError(try FiscalCalendarDefinition(name: "Gap", eras: [Era(start: nil, rule: months), Era(start: jan2030, rule: gap), Era(start: jan2031, rule: months)]))
        XCTAssertThrowsError(try FiscalCalendarDefinition(name: "Backwards", eras: [Era(start: nil, rule: months), Era(start: jan2031, rule: months), Era(start: jan2030, rule: months)]))
        XCTAssertThrowsError(try FiscalCalendarDefinition(json: Data(#"{"eras":[{"rule":"weeks","startMonth":1}]}"#.utf8)))
    }

    func testISODateParsing() {
        XCTAssertEqual(CalendarDate(iso: "2024-02-29"), CalendarDate(year: 2024, month: 2, day: 29))
        XCTAssertNil(CalendarDate(iso: "2025-02-29"))
        XCTAssertNil(CalendarDate(iso: "2026-10-1"))
        XCTAssertNil(CalendarDate(iso: "October"))
    }

    // MARK: Saved calendars

    func testSavedCalendarsRoundTripThroughDefaults() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(SavedCalendars.load(from: defaults), [])

        let saved = [
            SavedCalendar(definition: .months(startMonth: 1, startDay: 1, name: "SpaceX")),
            SavedCalendar(definition: FiscalCalendarDefinition.builtIn.renamed("Ours, again")),
        ]
        SavedCalendars.save(saved, to: defaults)
        XCTAssertEqual(SavedCalendars.load(from: defaults), saved)
    }

    func testSavedCalendarsSkipAnEntryThatNoLongerDecodes() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let good = SavedCalendar(definition: .months(startMonth: 7, startDay: 1, name: "Acme"))
        defaults.set([Data("not json".utf8), try JSONEncoder().encode(good)], forKey: "otherCalendars")
        XCTAssertEqual(SavedCalendars.load(from: defaults), [good])
    }

    func testSavedCalendarNamesAreUniqueIgnoringCase() {
        let saved = [SavedCalendar(definition: .months(startMonth: 1, startDay: 1, name: "SpaceX"))]
        XCTAssertEqual(SavedCalendars.named("  spacex ", in: saved)?.name, "SpaceX")
        XCTAssertNotNil(SavedCalendars.problem(withName: "SPACEX", in: saved))
        XCTAssertNotNil(SavedCalendars.problem(withName: "   ", in: saved))
        XCTAssertNil(SavedCalendars.problem(withName: "Acme", in: saved))
    }

    func testDefinitionSummary() {
        XCTAssertEqual(FiscalCalendarDefinition.months(startMonth: 7, startDay: 1).summary, "Starts Jul 1 every year")
        XCTAssertEqual(FiscalCalendarDefinition.builtIn.summary, "Starts Jan 1 every year")
        XCTAssertEqual(Self.february.summary, "3 eras, from a file")
    }

    // MARK: Shared settings

    func testMigrationCopiesCalendarSettingsOnce() throws {
        let (legacy, legacyName) = try scratchDefaults()
        let (group, groupName) = try scratchDefaults()
        defer {
            legacy.removePersistentDomain(forName: legacyName)
            group.removePersistentDomain(forName: groupName)
        }
        FiscalYearConfig(kind: .custom, startMonth: 7, startDay: 1).save(to: legacy)
        let saved = [SavedCalendar(definition: .months(startMonth: 1, startDay: 1, name: "SpaceX"))]
        SavedCalendars.save(saved, to: legacy)
        legacy.set("ring", forKey: "yearPicture")

        SharedSettings.migrateIfNeeded(from: legacy, to: group)
        XCTAssertEqual(FiscalYearConfig.load(from: group), FiscalYearConfig(kind: .custom, startMonth: 7, startDay: 1))
        XCTAssertEqual(SavedCalendars.load(from: group), saved)
        XCTAssertNil(group.object(forKey: "yearPicture"), "panel preferences stay with the app")

        // A second run does not overwrite a change made in the group since.
        FiscalYearConfig.builtIn.save(to: group)
        SharedSettings.migrateIfNeeded(from: legacy, to: group)
        XCTAssertEqual(FiscalYearConfig.load(from: group).kind, .builtIn)
    }

    func testReadOnlySourceReadsTheGroupFileThenFallsBack() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("fq-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: file) }
        let (legacy, legacyName) = try scratchDefaults()
        defer { legacy.removePersistentDomain(forName: legacyName) }
        FiscalYearConfig(kind: .custom, startMonth: 4, startDay: 1).save(to: legacy)

        let fromLegacy = SharedSettings.readOnlySource(file: file, fallback: legacy)
        XCTAssertEqual(FiscalYearConfig.load(from: fromLegacy).startMonth, 4)

        // A group file the app has not migrated into yet still defers to the legacy suite.
        var values: [String: Any] = ["fiscalYearKind": "custom", "fiscalStartMonth": 10, "fiscalStartDay": 1]
        try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0).write(to: file)
        XCTAssertEqual(FiscalYearConfig.load(from: SharedSettings.readOnlySource(file: file, fallback: legacy)).startMonth, 4)

        values["migratedFromLegacySuite"] = true
        try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0).write(to: file)
        let fromGroup = SharedSettings.readOnlySource(file: file, fallback: legacy)
        XCTAssertEqual(FiscalYearConfig.load(from: fromGroup), FiscalYearConfig(kind: .custom, startMonth: 10, startDay: 1))
    }

    private func scratchDefaults() throws -> (UserDefaults, String) {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: name)), name)
    }

    // MARK: Appearance

    func testHexColorsRoundTrip() throws {
        let navy = try XCTUnwrap(RGBAColor(hex: "#1F3A5F"))
        XCTAssertEqual(navy.hex, "#1F3A5F")
        XCTAssertEqual(RGBAColor(hex: "1f3a5f"), navy)
        XCTAssertEqual(RGBAColor(hex: "#FF000080")?.hex, "#FF000080")
        XCTAssertNil(RGBAColor(hex: "#12345"))
        XCTAssertNil(RGBAColor(hex: "#GGGGGG"))
        XCTAssertEqual(RGBAColor(hex: "#FFFFFF")?.luminance ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(RGBAColor(hex: "#000000")?.luminance ?? 1, 0, accuracy: 0.0001)
    }

    func testAutomaticTextFollowsTheBackground() throws {
        XCTAssertNil(Appearance.standard.prefersLightText, "the system background follows the system")
        XCTAssertEqual(Appearance(background: .color(try XCTUnwrap(RGBAColor(hex: "#1F3A5F")))).prefersLightText, true)
        XCTAssertEqual(Appearance(background: .color(try XCTUnwrap(RGBAColor(hex: "#F5F0E6")))).prefersLightText, false)
        let mint = try XCTUnwrap(GradientSpec.presets.first { $0.name == "Mint" }).gradient
        XCTAssertEqual(Appearance(background: .gradient(mint)).prefersLightText, false)
        let dusk = try XCTUnwrap(GradientSpec.presets.first { $0.name == "Dusk" }).gradient
        XCTAssertEqual(Appearance(background: .gradient(dusk)).prefersLightText, true)
        XCTAssertEqual(Appearance(background: .image("photo.jpg")).prefersLightText, true)
        XCTAssertEqual(Appearance(background: .image("photo.jpg"), foreground: .dark).prefersLightText, false)
        XCTAssertEqual(Appearance(foreground: .light).prefersLightText, true)
    }

    func testAppearanceRoundTripsThroughDefaults() throws {
        let (defaults, name) = try scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(Appearance.load(from: defaults), .standard)

        var look = Appearance(background: .gradient(GradientSpec.presets[3].gradient), typeface: .futura, numberWeight: .black, textSize: .large)
        look.accent = RGBAColor(hex: "#FF4E88")
        look.display.progressBars = false
        look.display.centered = true
        look.save(to: defaults)
        XCTAssertEqual(Appearance.load(from: defaults), look)

        Appearance(background: .image("abc.jpg")).save(to: defaults)
        XCTAssertEqual(Appearance.load(from: defaults).imageFile, "abc.jpg")

        defaults.set(Data("not json".utf8), forKey: "appearance")
        XCTAssertEqual(Appearance.load(from: defaults), .standard, "a look that no longer decodes falls back")
    }

    func testStandardGreenGivesWayOnlyWhereItWouldBeFaint() throws {
        func gradient(_ name: String) throws -> Appearance {
            Appearance(background: .gradient(try XCTUnwrap(GradientSpec.presets.first { $0.name == name }).gradient))
        }
        XCTAssertTrue(try gradient("Ocean").standardAccentIsFaint, "green on teal")
        XCTAssertTrue(try gradient("Mint").standardAccentIsFaint, "green on pale green")
        XCTAssertFalse(try gradient("Graphite").standardAccentIsFaint, "green on dark gray")
        XCTAssertFalse(Appearance.standard.standardAccentIsFaint, "the system background keeps the green")
        XCTAssertFalse(Appearance(background: .image("a.jpg")).standardAccentIsFaint, "a picture cannot be measured")
        var chosen = try gradient("Ocean")
        chosen.accent = RGBAColor(hex: "#FFFFFF")
        XCTAssertFalse(chosen.standardAccentIsFaint, "a chosen accent is always used")
        XCTAssertEqual(RGBAColor.contrast(1, 0), 21, accuracy: 0.0001)
    }

    func testGradientAverageColor() throws {
        let gradient = GradientSpec(colors: [try XCTUnwrap(RGBAColor(hex: "#000000")), try XCTUnwrap(RGBAColor(hex: "#FFFFFF"))])
        XCTAssertEqual(gradient.averageColor.hex, "#808080")
    }

    func testEveryNamedTypefaceHasAFamily() {
        for face in Appearance.Typeface.allCases {
            let isSystem = [.system, .rounded, .serif, .monospaced].contains(face)
            XCTAssertEqual(face.familyName == nil, isSystem, face.title)
        }
    }

    // MARK: Countdowns

    func testOctober112026CountdownsAllEndOnDecember31() {
        let snapshot = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 11))
        let half = snapshot.countdown(to: .half)
        XCTAssertEqual(half.label, "FY26-H2")
        XCTAssertEqual(half.start, CalendarDate(year: 2026, month: 7, day: 1))
        let year = snapshot.countdown(to: .year)
        XCTAssertEqual(year.label, "FY26")
        XCTAssertEqual(year.start, CalendarDate(year: 2026, month: 1, day: 1))
        XCTAssertEqual(year.days, 82)
        XCTAssertEqual(snapshot.countdownGroups.map(\.label), ["FY26-Q4 · H2 · FY26"])
    }

    func testMidYearCountdownsSplitIntoTwoGroups() {
        let snapshot = QuarterSnapshot(on: CalendarDate(year: 2027, month: 5, day: 15))
        XCTAssertEqual(snapshot.countdownGroups.map(\.label), ["FY27-Q2 · H1", "FY27"])
        XCTAssertEqual(snapshot.countdownGroups.map(\.end.iso), ["2027-06-30", "2027-12-31"])
    }

    func testFebruaryCalendarHalvesFollowItsQuarters() {
        let snapshot = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 11), calendar: Self.february)
        XCTAssertEqual(snapshot.countdown(to: .half).start, CalendarDate(year: 2026, month: 8, day: 1))
        XCTAssertEqual(snapshot.countdownGroups.map(\.label), ["FY27-Q4 · H2 · FY27"])
    }

    func testCountdownPhrases() {
        // Sunday 11 October 2026 through Thursday 31 December 2026.
        let countdown = QuarterSnapshot(on: CalendarDate(year: 2026, month: 10, day: 11)).countdown(to: .quarter)
        XCTAssertEqual(countdown.phrase(in: .days), "82 days")
        XCTAssertEqual(countdown.phrase(in: .weeks), "11 weeks 5 days")
        XCTAssertEqual(countdown.phrase(in: .workdays), "59 workdays")
        XCTAssertEqual(countdown.phrase(in: .weekends), "12 weekends")
        XCTAssertEqual(countdown.short(in: .weeks), "11w 5d")
        let last = QuarterSnapshot(on: CalendarDate(year: 2026, month: 12, day: 31)).countdown(to: .quarter)
        XCTAssertEqual(last.phrase(in: .days), "1 day")
        XCTAssertEqual(last.phrase(in: .weekends), "0 weekends")
        XCTAssertEqual(last.fractionComplete, 1)
    }

    func testWorkdaysAndWeekendsMatchADayByDayCount() throws {
        let calendar = utcCalendar()
        var today = CalendarDate(year: 2026, month: 9, day: 1)
        for _ in 0..<60 {
            let countdown = QuarterSnapshot(on: today).countdown(to: .quarter)
            var workdays = 0
            var weekends = 0
            var cursor = today
            while cursor <= countdown.end {
                let weekday = FiscalCalendar.weekday(cursor)
                if weekday != 1 && weekday != 7 { workdays += 1 }
                if weekday == 7 || (weekday == 1 && cursor == today) { weekends += 1 }
                cursor = try dayAfter(cursor, calendar: calendar)
            }
            XCTAssertEqual(countdown.workdays, workdays, today.iso)
            XCTAssertEqual(countdown.weekends, weekends, today.iso)
            today = try dayAfter(today, calendar: calendar)
        }
    }

    private func calendarFile(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("calendars")
            .appendingPathComponent(name)
    }

    private func assertQuarter(
        _ id: String,
        _ startYear: Int,
        _ startMonth: Int,
        _ startDay: Int,
        _ endYear: Int,
        _ endMonth: Int,
        _ endDay: Int,
        on year: Int,
        _ month: Int,
        _ day: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let date = CalendarDate(year: year, month: month, day: day)
        let quarter = FiscalCalendar.quarter(containing: date, in: Self.february)
        XCTAssertEqual(quarter.id, id, file: file, line: line)
        XCTAssertEqual(
            quarter.start,
            CalendarDate(year: startYear, month: startMonth, day: startDay),
            file: file,
            line: line
        )
        XCTAssertEqual(
            quarter.end,
            CalendarDate(year: endYear, month: endMonth, day: endDay),
            file: file,
            line: line
        )
    }

    private func assertDays(
        _ expected: Int,
        on year: Int,
        _ month: Int,
        _ day: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let date = CalendarDate(year: year, month: month, day: day)
        let quarter = FiscalCalendar.quarter(containing: date, in: Self.february)
        XCTAssertEqual(quarter.daysRemaining(on: date), expected, date.iso, file: file, line: line)
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func components(_ date: CalendarDate) -> DateComponents {
        DateComponents(year: date.year, month: date.month, day: date.day)
    }

    private func dayAfter(_ date: CalendarDate, calendar: Calendar) throws -> CalendarDate {
        let base = try XCTUnwrap(calendar.date(from: components(date)))
        let next = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: base))
        return CalendarDate(next, calendar: calendar)
    }
}
