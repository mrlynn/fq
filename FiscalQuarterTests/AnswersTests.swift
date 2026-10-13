import Foundation
import XCTest

#if canImport(FiscalQuarterCore)
import FiscalQuarterCore
#endif

final class AnswersTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> CalendarDate {
        CalendarDate(year: year, month: month, day: day)
    }

    func testTheQuarter() {
        let snapshot = QuarterSnapshot(on: date(2026, 10, 13))
        XCTAssertEqual(Answers.quarter(snapshot), "It's FY26-Q4, day 13 of 92, with 80 days left.")
        let last = QuarterSnapshot(on: date(2026, 12, 31))
        XCTAssertEqual(Answers.quarter(last, name: "Acme"), "For Acme, it's FY26-Q4, day 92 of 92, with 1 day left.")
    }

    func testTimeLeft() {
        let snapshot = QuarterSnapshot(on: date(2026, 10, 13), workweek: Workweek(region: .unitedStates))
        XCTAssertEqual(Answers.timeLeft(snapshot.countdown(to: .quarter), unit: .days), "80 days left in FY26-Q4, through Thu 31 Dec.")
        XCTAssertEqual(Answers.timeLeft(snapshot.countdown(to: .year), unit: .workdays), "55 workdays left in FY26, through Thu 31 Dec.")
        XCTAssertEqual(Answers.timeLeft(snapshot.countdown(to: .half), unit: .weeks), "11 weeks 3 days left in FY26-H2, through Thu 31 Dec.")
        let last = QuarterSnapshot(on: date(2026, 12, 31)).countdown(to: .quarter)
        XCTAssertEqual(Answers.timeLeft(last, unit: .days), "FY26-Q4 ends today.")
    }

    func testTheQuarterOfADate() {
        XCTAssertEqual(
            Answers.quarter(of: date(2027, 3, 15), in: .builtIn, today: date(2026, 10, 13)),
            "Mon 15 Mar 2027 is in FY27-Q1, which runs Fri 1 Jan to Wed 31 Mar."
        )
        XCTAssertEqual(
            Answers.quarter(of: date(2026, 10, 13), in: .weeks(.retail), today: date(2026, 10, 13)),
            "Tue 13 Oct is in FY26-Q3, which runs Sun 2 Aug to Sat 31 Oct."
        )
    }

    func testAMilestone() {
        let forecast = Milestone(name: "Forecast due", offset: 5)
        let next = forecast.next(onOrAfter: date(2026, 10, 13), in: .builtIn)!
        XCTAssertEqual(Answers.milestone(next, today: date(2026, 10, 13)), "Forecast due is Thu 24 Dec, 72 days away.")
        XCTAssertEqual(Answers.milestone(next, today: date(2026, 12, 23)), "Forecast due is tomorrow, Thu 24 Dec.")
        XCTAssertEqual(Answers.milestone(next, today: date(2026, 12, 24)), "Forecast due is today.")
    }
}
