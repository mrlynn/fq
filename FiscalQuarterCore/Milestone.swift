import Foundation

/// A date that comes around every quarter, such as "Forecast due, 5 workdays before quarter end".
///
/// A milestone is a rule, not a date. Each quarter it resolves against that quarter's own start
/// and end, so it stays right in short quarters and transition years. Milestones belong to your
/// calendar, not to the other saved calendars.
public struct Milestone: Equatable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    /// How far from the anchor, in `unit`. Zero is the anchor day itself.
    public var offset: Int
    public var unit: Unit
    public var direction: Direction
    public var anchor: Anchor
    /// Quarter numbers it applies to, by position in the fiscal year. Empty means every quarter.
    public var quarters: Set<Int>
    public var weekend: WeekendRule
    /// Workdays ahead to send its notification, when milestone notifications are on. Zero is on the day.
    public var reminderLead: Int

    public init(
        id: UUID = UUID(),
        name: String,
        offset: Int,
        unit: Unit = .workdays,
        direction: Direction = .before,
        anchor: Anchor = .quarterEnd,
        quarters: Set<Int> = [],
        weekend: WeekendRule = .fridayBefore,
        reminderLead: Int = 0
    ) {
        self.id = id
        self.name = name
        self.offset = offset
        self.unit = unit
        self.direction = direction
        self.anchor = anchor
        self.quarters = quarters
        self.weekend = weekend
        self.reminderLead = reminderLead
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, offset, unit, direction, anchor, quarters, weekend, reminderLead
    }

    /// Milestones saved before reminders existed have no lead, and get "on the day".
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        offset = try container.decode(Int.self, forKey: .offset)
        unit = try container.decode(Unit.self, forKey: .unit)
        direction = try container.decode(Direction.self, forKey: .direction)
        anchor = try container.decode(Anchor.self, forKey: .anchor)
        quarters = try container.decode(Set<Int>.self, forKey: .quarters)
        weekend = try container.decode(WeekendRule.self, forKey: .weekend)
        reminderLead = try container.decodeIfPresent(Int.self, forKey: .reminderLead) ?? 0
    }

    /// The leads the editor offers, in workdays.
    public static let reminderLeads = [0, 1, 2, 5]

    public enum Unit: String, CaseIterable, Codable, Identifiable {
        case days, workdays, weeks
        public var id: String { rawValue }
    }

    public enum Direction: String, CaseIterable, Codable, Identifiable {
        case before, after
        public var id: String { rawValue }
    }

    public enum Anchor: String, CaseIterable, Codable, Identifiable {
        case quarterStart, quarterEnd
        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .quarterStart: return "quarter start"
            case .quarterEnd: return "quarter end"
            }
        }
    }

    /// What to do when a date lands on a Saturday or Sunday.
    public enum WeekendRule: String, CaseIterable, Codable, Identifiable {
        case keep, fridayBefore
        public var id: String { rawValue }
    }

    /// The longest offset the editor and the file accept, about a year of days.
    public static let maximumOffset = 366

    /// Why this milestone cannot be saved, or nil when it can.
    public var problem: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Give the milestone a name."
        }
        if !(0...Self.maximumOffset).contains(offset) {
            return "Use a distance from 0 to \(Self.maximumOffset)."
        }
        if quarters.contains(where: { !(1...4).contains($0) }) {
            return "Quarters are numbered 1 to 4."
        }
        if !(0...20).contains(reminderLead) {
            return "Remind from 0 to 20 workdays ahead."
        }
        return nil
    }

    // MARK: Dates

    /// Whether the rule runs in `quarter`.
    public func applies(to quarter: FiscalQuarter) -> Bool {
        quarters.isEmpty || quarters.contains(quarter.quarter)
    }

    /// The day the rule lands on for `quarter`, whether or not it applies there.
    public func date(in quarter: FiscalQuarter) -> CalendarDate {
        let base = anchor == .quarterStart ? quarter.start : quarter.end
        let step = direction == .before ? -1 : 1
        var date = base
        switch unit {
        case .days:
            date = FiscalCalendar.shift(base, by: step * offset) ?? base
        case .weeks:
            date = FiscalCalendar.shift(base, by: step * offset * 7) ?? base
        case .workdays:
            // Counts weekdays away from the anchor, not counting the anchor itself.
            var counted = 0
            while counted < offset, let next = FiscalCalendar.shift(date, by: step) {
                date = next
                if !Self.isWeekend(date) { counted += 1 }
            }
        }
        if weekend == .fridayBefore {
            while Self.isWeekend(date), let previous = FiscalCalendar.day(before: date) {
                date = previous
            }
        }
        return date
    }

    /// The first time the rule lands on or after `today`.
    ///
    /// A rule's dates only move forward from one quarter to the next, so the first one on or after
    /// today is the answer. An offset can reach up to a year away from its own quarter, so the
    /// search starts five quarters back and looks about two years ahead.
    public func next(onOrAfter today: CalendarDate, in calendar: FiscalCalendarDefinition) -> MilestoneOccurrence? {
        var quarter = FiscalCalendar.quarter(containing: today, in: calendar)
        for _ in 0..<5 {
            quarter = FiscalCalendar.quarter(before: quarter, in: calendar)
        }
        for _ in 0..<14 {
            if applies(to: quarter) {
                let date = date(in: quarter)
                if date >= today {
                    return MilestoneOccurrence(milestone: self, quarter: quarter, date: date)
                }
            }
            quarter = FiscalCalendar.quarter(after: quarter, in: calendar)
        }
        return nil
    }

    // MARK: Words

    /// `5 workdays before quarter end, every quarter`, or `On quarter end, Q4 only`.
    public var summary: String {
        let when: String
        if offset == 0 {
            when = "On \(anchor.title)"
        } else {
            let noun = offset == 1 ? String(unit.rawValue.dropLast()) : unit.rawValue
            when = "\(offset) \(noun) \(direction.rawValue) \(anchor.title)"
        }
        return "\(when), \(quartersSummary)"
    }

    /// `every quarter`, `Q4 only`, or `Q2 and Q4`.
    public var quartersSummary: String {
        let names = quarters.sorted().map { "Q\($0)" }
        switch names.count {
        case 0, 4: return "every quarter"
        case 1: return "\(names[0]) only"
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }

    /// `count` weekdays before `date`, not counting `date`. Zero is `date` itself.
    public static func workdays(_ count: Int, before date: CalendarDate) -> CalendarDate {
        var day = date
        var counted = 0
        while counted < count, let previous = FiscalCalendar.day(before: day) {
            day = previous
            if !isWeekend(day) { counted += 1 }
        }
        return day
    }

    static func isWeekend(_ date: CalendarDate) -> Bool {
        let weekday = FiscalCalendar.weekday(date)
        return weekday == 1 || weekday == 7
    }
}

/// One milestone on one date, with the quarter it was worked out from.
public struct MilestoneOccurrence: Equatable {
    public let milestone: Milestone
    public let quarter: FiscalQuarter
    public let date: CalendarDate

    /// Time left from `today` through the milestone's day, counted like the period countdowns.
    public func countdown(from today: CalendarDate) -> Countdown {
        Countdown(target: nil, label: milestone.name, start: min(quarter.start, date), end: date, today: today)
    }
}

/// Your milestones, kept in the same defaults suite as `FiscalYearConfig` so `fq` sees them too.
///
/// Each milestone is stored as its own JSON blob. One that no longer decodes is skipped rather
/// than taking the rest of the list with it.
public enum Milestones {
    static let storedKey = "milestones"

    public static func load(from defaults: SettingsSource) -> [Milestone] {
        let blobs = defaults.object(forKey: storedKey) as? [Data] ?? []
        return blobs.compactMap { try? JSONDecoder().decode(Milestone.self, from: $0) }
    }

    public static func save(_ milestones: [Milestone], to defaults: UserDefaults) {
        let encoder = JSONEncoder()
        defaults.set(milestones.compactMap { try? encoder.encode($0) }, forKey: storedKey)
    }

    /// The next date of each milestone on or after `today`, soonest first. Ties keep list order.
    public static func upcoming(_ milestones: [Milestone], onOrAfter today: CalendarDate, in calendar: FiscalCalendarDefinition) -> [MilestoneOccurrence] {
        milestones
            .compactMap { $0.next(onOrAfter: today, in: calendar) }
            .enumerated()
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)
    }
}
