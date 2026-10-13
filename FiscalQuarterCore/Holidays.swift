import Foundation

/// Which days are workdays: Monday through Friday, less a country's public holidays and your own days off.
///
/// Stored in the App Group beside the calendar settings, so the apps, the widgets, and `fq` count alike.
public struct Workweek: Equatable, Hashable, Codable {
    /// Whose public holidays to skip. Nil skips none.
    public var region: HolidayRegion?
    /// Days off of your own, such as a company shutdown. A weekend day here changes nothing.
    public var daysOff: Set<CalendarDate>

    public init(region: HolidayRegion? = nil, daysOff: Set<CalendarDate> = []) {
        self.region = region
        self.daysOff = daysOff
    }

    /// Monday through Friday, no holidays.
    public static let weekdays = Workweek()

    public func isWorkday(_ date: CalendarDate) -> Bool {
        !Self.isWeekend(date) && !isDayOff(date)
    }

    /// A public holiday or one of your days off, on any day of the week.
    public func isDayOff(_ date: CalendarDate) -> Bool {
        daysOff.contains(date) || region?.holiday(on: date) != nil
    }

    /// The next weekday off on or after `today`, with its name, within about a year.
    public func nextDayOff(onOrAfter today: CalendarDate) -> Holiday? {
        var day = today
        for _ in 0..<400 {
            if !Self.isWeekend(day) {
                if let holiday = region?.holiday(on: day) { return holiday }
                if daysOff.contains(day) { return Holiday(name: "Day off", date: day) }
            }
            guard let next = FiscalCalendar.shift(day, by: 1) else { break }
            day = next
        }
        return nil
    }

    /// `Monday through Friday`, or `Monday through Friday, less United States (federal) holidays and 2 days off`.
    public var summary: String {
        var less: [String] = []
        if let region { less.append("\(region.title) holidays") }
        if !daysOff.isEmpty { less.append(daysOff.count == 1 ? "1 day off" : "\(daysOff.count) days off") }
        return less.isEmpty ? "Monday through Friday" : "Monday through Friday, less " + less.joined(separator: " and ")
    }

    /// Weekdays that are not workdays from `start` through `end`, counting both.
    func weekdaysOff(from start: CalendarDate, through end: CalendarDate) -> Int {
        guard start <= end else { return 0 }
        var off = Set(daysOff.filter { $0 >= start && $0 <= end })
        if let region {
            for year in (start.year - 1)...(end.year + 1) {
                for holiday in region.holidays(in: year) where holiday.date >= start && holiday.date <= end {
                    off.insert(holiday.date)
                }
            }
        }
        return off.filter { !Self.isWeekend($0) }.count
    }

    static func isWeekend(_ date: CalendarDate) -> Bool {
        let weekday = FiscalCalendar.weekday(date)
        return weekday == 1 || weekday == 7
    }

    // MARK: Storage

    static let storedKey = "workweek"

    public static func load(from settings: SettingsSource) -> Workweek {
        guard let data = settings.object(forKey: storedKey) as? Data,
              let workweek = try? JSONDecoder().decode(Workweek.self, from: data)
        else {
            return .weekdays
        }
        return workweek
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.storedKey)
    }
}

/// One public holiday, on the day it is observed.
public struct Holiday: Equatable {
    public let name: String
    public let date: CalendarDate
}

/// Countries whose national public holidays the app knows, worked out by rule for any year.
///
/// Only holidays kept across the whole country are included. Regional ones, and one-off days
/// such as a coronation, can be added as days off.
public enum HolidayRegion: String, CaseIterable, Codable, Identifiable {
    case unitedStates, canada, unitedKingdom, ireland, australia, germany, france

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .unitedStates: return "United States (federal)"
        case .canada: return "Canada (federal)"
        case .unitedKingdom: return "United Kingdom (England and Wales)"
        case .ireland: return "Ireland"
        case .australia: return "Australia (national)"
        case .germany: return "Germany (national)"
        case .france: return "France"
        }
    }

    /// The holiday observed on `date`, if any.
    public func holiday(on date: CalendarDate) -> Holiday? {
        // A holiday can be observed in the year before or after its own, such as New Year's Day
        // on a Saturday, kept on the Friday before.
        for year in [date.year, date.year + 1, date.year - 1] {
            if let match = holidays(in: year).first(where: { $0.date == date }) {
                return match
            }
        }
        return nil
    }

    /// The holidays of `year`'s rules, on the days they are observed. Those can fall just outside the year.
    /// Each year is worked out once and kept, since workday counts ask about the same few years again and again.
    public func holidays(in year: Int) -> [Holiday] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        let key = "\(rawValue).\(year)"
        if let known = Self.cache[key] { return known }
        let worked = rules(for: year)
        Self.cache[key] = worked
        return worked
    }

    private static let lock = NSLock()
    private static var cache: [String: [Holiday]] = [:]

    private func rules(for year: Int) -> [Holiday] {
        let easter = Self.easter(year)
        func day(_ month: Int, _ day: Int) -> CalendarDate { CalendarDate(year: year, month: month, day: day) }
        func fromEaster(_ days: Int) -> CalendarDate { FiscalCalendar.shift(easter, by: days) ?? easter }
        func nth(_ n: Int, _ weekday: Int, of month: Int) -> CalendarDate { Self.nth(n, weekday, of: month, in: year) }
        func last(_ weekday: Int, of month: Int) -> CalendarDate { Self.last(weekday, of: month, in: year) }
        let monday = 2, thursday = 5

        switch self {
        case .unitedStates:
            // A Saturday holiday is kept on the Friday before, a Sunday one on the Monday after.
            return [
                Holiday(name: "New Year's Day", date: Self.nearestWeekday(day(1, 1))),
                Holiday(name: "Martin Luther King Jr. Day", date: nth(3, monday, of: 1)),
                Holiday(name: "Washington's Birthday", date: nth(3, monday, of: 2)),
                Holiday(name: "Memorial Day", date: last(monday, of: 5)),
                Holiday(name: "Juneteenth", date: Self.nearestWeekday(day(6, 19))),
                Holiday(name: "Independence Day", date: Self.nearestWeekday(day(7, 4))),
                Holiday(name: "Labor Day", date: nth(1, monday, of: 9)),
                Holiday(name: "Columbus Day", date: nth(2, monday, of: 10)),
                Holiday(name: "Veterans Day", date: Self.nearestWeekday(day(11, 11))),
                Holiday(name: "Thanksgiving", date: nth(4, thursday, of: 11)),
                Holiday(name: "Christmas Day", date: Self.nearestWeekday(day(12, 25))),
            ]
        case .canada:
            return Self.substitutedForward([
                Holiday(name: "New Year's Day", date: day(1, 1)),
                Holiday(name: "Good Friday", date: fromEaster(-2)),
                Holiday(name: "Victoria Day", date: Self.mondayBefore(day(5, 25))),
                Holiday(name: "Canada Day", date: day(7, 1)),
                Holiday(name: "Labour Day", date: nth(1, monday, of: 9)),
                Holiday(name: "National Day for Truth and Reconciliation", date: day(9, 30)),
                Holiday(name: "Thanksgiving", date: nth(2, monday, of: 10)),
                Holiday(name: "Remembrance Day", date: day(11, 11)),
                Holiday(name: "Christmas Day", date: day(12, 25)),
                Holiday(name: "Boxing Day", date: day(12, 26)),
            ])
        case .unitedKingdom:
            return Self.substitutedForward([
                Holiday(name: "New Year's Day", date: day(1, 1)),
                Holiday(name: "Good Friday", date: fromEaster(-2)),
                Holiday(name: "Easter Monday", date: fromEaster(1)),
                Holiday(name: "Early May bank holiday", date: nth(1, monday, of: 5)),
                Holiday(name: "Spring bank holiday", date: last(monday, of: 5)),
                Holiday(name: "Summer bank holiday", date: last(monday, of: 8)),
                Holiday(name: "Christmas Day", date: day(12, 25)),
                Holiday(name: "Boxing Day", date: day(12, 26)),
            ])
        case .ireland:
            var holidays = [Holiday(name: "New Year's Day", date: day(1, 1))]
            if year >= 2023 {
                // The first Monday in February, or 1 February when that is a Friday.
                let first = day(2, 1)
                holidays.append(Holiday(name: "St Brigid's Day", date: FiscalCalendar.weekday(first) == 6 ? first : nth(1, monday, of: 2)))
            }
            holidays += [
                Holiday(name: "St Patrick's Day", date: day(3, 17)),
                Holiday(name: "Easter Monday", date: fromEaster(1)),
                Holiday(name: "May bank holiday", date: nth(1, monday, of: 5)),
                Holiday(name: "June bank holiday", date: nth(1, monday, of: 6)),
                Holiday(name: "August bank holiday", date: nth(1, monday, of: 8)),
                Holiday(name: "October bank holiday", date: last(monday, of: 10)),
                Holiday(name: "Christmas Day", date: day(12, 25)),
                Holiday(name: "St Stephen's Day", date: day(12, 26)),
            ]
            return Self.substitutedForward(holidays)
        case .australia:
            // Anzac Day has no substitute in most states, so it stays on its day.
            let anzac = Holiday(name: "Anzac Day", date: day(4, 25))
            let others = Self.substitutedForward([
                Holiday(name: "New Year's Day", date: day(1, 1)),
                Holiday(name: "Australia Day", date: day(1, 26)),
                Holiday(name: "Good Friday", date: fromEaster(-2)),
                Holiday(name: "Easter Monday", date: fromEaster(1)),
                Holiday(name: "Christmas Day", date: day(12, 25)),
                Holiday(name: "Boxing Day", date: day(12, 26)),
            ])
            return (others + [anzac]).sorted { $0.date < $1.date }
        case .germany:
            return [
                Holiday(name: "New Year's Day", date: day(1, 1)),
                Holiday(name: "Good Friday", date: fromEaster(-2)),
                Holiday(name: "Easter Monday", date: fromEaster(1)),
                Holiday(name: "Labour Day", date: day(5, 1)),
                Holiday(name: "Ascension Day", date: fromEaster(39)),
                Holiday(name: "Whit Monday", date: fromEaster(50)),
                Holiday(name: "German Unity Day", date: day(10, 3)),
                Holiday(name: "Christmas Day", date: day(12, 25)),
                Holiday(name: "Second Day of Christmas", date: day(12, 26)),
            ]
        case .france:
            return [
                Holiday(name: "New Year's Day", date: day(1, 1)),
                Holiday(name: "Easter Monday", date: fromEaster(1)),
                Holiday(name: "Labour Day", date: day(5, 1)),
                Holiday(name: "Victory in Europe Day", date: day(5, 8)),
                Holiday(name: "Ascension Day", date: fromEaster(39)),
                Holiday(name: "Whit Monday", date: fromEaster(50)),
                Holiday(name: "Bastille Day", date: day(7, 14)),
                Holiday(name: "Assumption", date: day(8, 15)),
                Holiday(name: "All Saints' Day", date: day(11, 1)),
                Holiday(name: "Armistice Day", date: day(11, 11)),
                Holiday(name: "Christmas Day", date: day(12, 25)),
            ]
        }
    }

    // MARK: Rules

    /// Easter Sunday in the Gregorian calendar, by the anonymous Gregorian algorithm.
    public static func easter(_ year: Int) -> CalendarDate {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return CalendarDate(year: year, month: month, day: day)
    }

    /// The `n`th `weekday` (Sunday is 1) of `month`.
    static func nth(_ n: Int, _ weekday: Int, of month: Int, in year: Int) -> CalendarDate {
        let first = CalendarDate(year: year, month: month, day: 1)
        let ahead = (weekday - FiscalCalendar.weekday(first) + 7) % 7
        return FiscalCalendar.shift(first, by: ahead + (n - 1) * 7) ?? first
    }

    /// The last `weekday` (Sunday is 1) of `month`.
    static func last(_ weekday: Int, of month: Int, in year: Int) -> CalendarDate {
        let end = FiscalCalendar.endOfMonth(CalendarDate(year: year, month: month, day: 1)) ?? CalendarDate(year: year, month: month, day: 28)
        let back = (FiscalCalendar.weekday(end) - weekday + 7) % 7
        return FiscalCalendar.shift(end, by: -back) ?? end
    }

    /// The last Monday strictly before `date`.
    static func mondayBefore(_ date: CalendarDate) -> CalendarDate {
        let back = (FiscalCalendar.weekday(date) - 2 + 7) % 7
        return FiscalCalendar.shift(date, by: -(back == 0 ? 7 : back)) ?? date
    }

    /// Saturday to the Friday before, Sunday to the Monday after.
    static func nearestWeekday(_ date: CalendarDate) -> CalendarDate {
        switch FiscalCalendar.weekday(date) {
        case 7: return FiscalCalendar.shift(date, by: -1) ?? date
        case 1: return FiscalCalendar.shift(date, by: 1) ?? date
        default: return date
        }
    }

    /// A holiday on a weekend moves to the next weekday that is not already a holiday, in date order,
    /// so Christmas and Boxing Day on a weekend become Monday and Tuesday.
    static func substitutedForward(_ holidays: [Holiday]) -> [Holiday] {
        var taken = Set<CalendarDate>()
        var result: [Holiday] = []
        for holiday in holidays.sorted(by: { $0.date < $1.date }) {
            var date = holiday.date
            if Workweek.isWeekend(date) {
                while Workweek.isWeekend(date) || taken.contains(date) {
                    date = FiscalCalendar.shift(date, by: 1) ?? date
                }
            }
            taken.insert(date)
            result.append(Holiday(name: holiday.name, date: date))
        }
        return result
    }
}
