import Foundation
import XCTest

#if canImport(FiscalQuarterCore)
import FiscalQuarterCore
#endif

final class ReminderTests: XCTestCase {
    private let builtIn = FiscalCalendarDefinition.builtIn
    private let allOn = ReminderSettings(milestones: true, lastTwoWeeks: true, newQuarter: true, yearEnd: true)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: year, month: month, day: day)
    }

    private func plan(_ settings: ReminderSettings, _ milestones: [Milestone] = [], on today: CalendarDate) -> [PlannedReminder] {
        ReminderPlan.plan(settings: settings, milestones: milestones, calendar: builtIn, today: today)
    }

    func testNothingIsPlannedWhenEverythingIsOff() {
        XCTAssertEqual(plan(.off, [Milestone(name: "Forecast due", offset: 5)], on: date(2026, 12, 2)), [])
    }

    func testEveryKindInOneWindow() {
        // From Wednesday 2 December 2026 through Friday 1 January 2027.
        let forecast = Milestone(name: "Forecast due", offset: 5, reminderLead: 2)
        let reminders = plan(allOn, [forecast], on: date(2026, 12, 2))

        XCTAssertEqual(reminders.map(\.date.iso), ["2026-12-02", "2026-12-18", "2026-12-22", "2027-01-01"])
        XCTAssertEqual(reminders.map(\.title), [
            "30 days left in FY26",
            "Two weeks left in FY26-Q4",
            "Forecast due Thursday",
            "FY27-Q1 starts today",
        ])
        XCTAssertEqual(reminders.map(\.body), [
            "22 workdays to Thu 31 Dec.",
            "10 workdays to Thu 31 Dec.",
            "5 workdays before quarter end, every quarter · FY26-Q4",
            "90 days, through Wed 31 Mar.",
        ])
        XCTAssertTrue(reminders.allSatisfy { $0.id.hasPrefix(ReminderPlan.idPrefix) })
    }

    func testEachKindCanBeTurnedOffAlone() {
        let forecast = Milestone(name: "Forecast due", offset: 5)
        var settings = allOn
        settings.milestones = false
        XCTAssertFalse(plan(settings, [forecast], on: date(2026, 12, 2)).contains { $0.title.hasPrefix("Forecast") })
        settings = allOn
        settings.yearEnd = false
        XCTAssertFalse(plan(settings, on: date(2026, 12, 2)).contains { $0.title.hasPrefix("30 days") })
        settings = allOn
        settings.newQuarter = false
        XCTAssertFalse(plan(settings, on: date(2026, 12, 2)).contains { $0.title.hasSuffix("starts today") })
        settings = allOn
        settings.lastTwoWeeks = false
        XCTAssertFalse(plan(settings, on: date(2026, 12, 2)).contains { $0.title.hasPrefix("Two weeks") })
    }

    func testMilestoneTitlesByDistance() {
        let today = ReminderSettings(milestones: true)
        XCTAssertEqual(plan(today, [Milestone(name: "Forecast due", offset: 5)], on: date(2026, 12, 2)).first?.title, "Forecast due today")
        XCTAssertEqual(plan(today, [Milestone(name: "Forecast due", offset: 5, reminderLead: 1)], on: date(2026, 12, 2)).first?.title, "Forecast due tomorrow")
        // Five workdays ahead of Thursday 24 December is Thursday the 17th, a week before.
        XCTAssertEqual(plan(today, [Milestone(name: "Forecast due", offset: 5, reminderLead: 5)], on: date(2026, 12, 2)).first?.title, "Forecast due Thu 24 Dec")
    }

    func testAReminderDayThatHasPassedIsSkipped() {
        // The reminder for 24 December was on the 22nd. The next one, for 24 March, is outside the window.
        let forecast = Milestone(name: "Forecast due", offset: 5, reminderLead: 2)
        XCTAssertEqual(plan(ReminderSettings(milestones: true), [forecast], on: date(2026, 12, 23)), [])
    }

    func testALeadCanReachBackIntoTheWindow() {
        // From 1 March 2027 the window ends 31 March. The 24 March milestone's reminder is on the 17th.
        let forecast = Milestone(name: "Forecast due", offset: 5, reminderLead: 5)
        let reminders = plan(ReminderSettings(milestones: true), [forecast], on: date(2027, 3, 1))
        XCTAssertEqual(reminders.map(\.date.iso), ["2027-03-17"])
    }

    func testPlanningAgainGivesTheSameIdentifiers() {
        let forecast = Milestone(name: "Forecast due", offset: 5, reminderLead: 2)
        let first = plan(allOn, [forecast], on: date(2026, 12, 2)).map(\.id)
        let second = plan(allOn, [forecast], on: date(2026, 12, 2)).map(\.id)
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first).count, first.count)
    }

    func testAMilestoneSavedBeforeRemindersIsOnTheDay() throws {
        let json = #"{"id":"7D0D8B5E-0000-4000-8000-000000000001","name":"Forecast due","offset":5,"unit":"workdays","direction":"before","anchor":"quarterEnd","quarters":[],"weekend":"fridayBefore"}"#
        let milestone = try JSONDecoder().decode(Milestone.self, from: Data(json.utf8))
        XCTAssertEqual(milestone.reminderLead, 0)
    }

    func testWorkdaysBefore() {
        // Monday 28 December 2026: two workdays back skips the weekend to Thursday the 24th.
        XCTAssertEqual(Milestone.workdays(2, before: date(2026, 12, 28)), date(2026, 12, 24))
        XCTAssertEqual(Milestone.workdays(0, before: date(2026, 12, 26)), date(2026, 12, 26))
    }

    func testSettingsRoundTripThroughDefaults() throws {
        let name = "local.fiscalquarter.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(ReminderSettings.load(from: defaults), .off)
        let settings = ReminderSettings(milestones: true, yearEnd: true, hour: 8, minute: 30)
        settings.save(to: defaults)
        XCTAssertEqual(ReminderSettings.load(from: defaults), settings)
    }

    func testDayWords() {
        XCTAssertEqual(DayWords.weekday(date(2026, 12, 24)), "Thursday")
        XCTAssertEqual(DayWords.short(date(2026, 12, 24)), "Thu 24 Dec")
        XCTAssertEqual(DayWords.short(date(2027, 1, 4), today: date(2026, 12, 30)), "Mon 4 Jan 2027")
    }
}
