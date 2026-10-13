import Foundation

/// What Siri and Shortcuts say back, one sentence each, so they read the same on the Mac and iPhone.
public enum Answers {
    /// `It's FY26-Q4, day 13 of 92, with 80 days left.` With a calendar's name: `For Acme, it's …`.
    public static func quarter(_ snapshot: QuarterSnapshot, name: String? = nil) -> String {
        let left = snapshot.daysRemaining == 1 ? "1 day" : "\(snapshot.daysRemaining) days"
        let opening = name.map { "For \($0), it's" } ?? "It's"
        return "\(opening) \(snapshot.quarter.id), day \(snapshot.dayIndex) of \(snapshot.length), with \(left) left."
    }

    /// `80 days left in FY26-Q4, through Thu 31 Dec.` On the last day: `FY26-Q4 ends today.`
    public static func timeLeft(_ countdown: Countdown, unit: CountdownUnit) -> String {
        if countdown.days == 1 {
            return "\(countdown.label) ends today."
        }
        let through = DayWords.short(countdown.end, today: countdown.today)
        return "\(countdown.phrase(in: unit)) left in \(countdown.label), through \(through)."
    }

    /// `Mon 15 Mar 2027 is in FY27-Q1, which runs Fri 1 Jan to Wed 31 Mar.`
    public static func quarter(of date: CalendarDate, in calendar: FiscalCalendarDefinition, today: CalendarDate) -> String {
        let quarter = FiscalCalendar.quarter(containing: date, in: calendar)
        let day = DayWords.short(date, today: today)
        let start = DayWords.short(quarter.start, today: date)
        let end = DayWords.short(quarter.end, today: date)
        return "\(day) is in \(quarter.id), which runs \(start) to \(end)."
    }

    /// `Forecast due is Wed 23 Dec, 72 days away.` Or `… is today.` and `… is tomorrow.`
    public static func milestone(_ occurrence: MilestoneOccurrence, today: CalendarDate) -> String {
        let name = occurrence.milestone.name
        let away = occurrence.countdown(from: today).days - 1
        switch away {
        case 0: return "\(name) is today."
        case 1: return "\(name) is tomorrow, \(DayWords.short(occurrence.date, today: today))."
        default: return "\(name) is \(DayWords.short(occurrence.date, today: today)), \(away) days away."
        }
    }

    public static let noMilestones = "You have no milestones yet. Add them under Milestones in Fiscal Quarter."
}
