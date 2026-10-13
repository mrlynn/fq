import Foundation
#if canImport(FiscalQuarterCore)
import FiscalQuarterCore
#endif

@main
struct FQCommand {
    static func main() {
        do {
            try run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("fq: \(error)\n", stderr)
            exit(1)
        }
    }

    static func run(_ arguments: [String]) throws {
        var mode = Mode.human
        var date = CalendarDate(Date(), calendar: .current)
        var definition = FiscalYearConfig.load(from: settings).definition
        var all = false
        // Milestones belong to your calendar, so another calendar leaves them out.
        var yours = true
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                printUsage()
                return
            case "--id":
                mode = .id
            case "--status":
                mode = .status
            case "--json":
                mode = .json
            case "--copy":
                mode = .copy
            case "--countdown":
                mode = .countdown
            case "--milestones":
                mode = .milestones
            case "--date":
                index += 1
                guard index < arguments.count, let parsed = CalendarDate(iso: arguments[index]) else {
                    fputs("fq: --date needs YYYY-MM-DD\n", stderr)
                    exit(2)
                }
                date = parsed
            case "--calendar":
                index += 1
                guard index < arguments.count else {
                    fputs("fq: --calendar needs a saved calendar name or a calendar JSON file\n", stderr)
                    exit(2)
                }
                definition = try loadCalendar(arguments[index])
                yours = false
            case "--all":
                all = true
            default:
                fputs("fq: unknown option \(argument)\n", stderr)
                printUsage()
                exit(2)
            }
            index += 1
        }

        if all {
            printAll(on: date, mode: mode)
            return
        }

        let snapshot = QuarterSnapshot(on: date, calendar: definition)
        let upcoming = yours ? Milestones.upcoming(Milestones.load(from: settings), onOrAfter: date, in: definition) : []
        switch mode {
        case .human:
            print(snapshot.quarter.id)
            print("\(snapshot.quarter.start.iso) – \(snapshot.quarter.end.iso)")
            print(snapshot.progressLine)
            print(snapshot.daysRemaining == 1 ? "1 day left" : "\(snapshot.daysRemaining) days left")
            print("Next \(snapshot.next.id) on \(snapshot.next.start.iso)")
            if let pace = snapshot.paceNote {
                print(pace)
            }
            if let note = snapshot.transitionNote {
                print(note)
            }
        case .id:
            print(snapshot.quarter.id)
        case .status:
            print(snapshot.statusLine)
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            print(try json(snapshot, milestones: yours ? upcoming : nil, encoder: encoder))
        case .copy:
            try copyToPasteboard(snapshot.quarter.id)
            print(snapshot.quarter.id)
        case .countdown:
            for group in snapshot.countdownGroups {
                let countdown = group.first
                print("\(group.label) ends \(group.end.iso)")
                print("  \(countdown.phrase(in: .days)) · \(countdown.phrase(in: .workdays)) · \(countdown.phrase(in: .weekends))")
            }
            for occurrence in upcoming {
                let countdown = occurrence.countdown(from: date)
                print("\(occurrence.milestone.name) on \(occurrence.date.iso)")
                print("  \(countdown.phrase(in: .days)) · \(countdown.phrase(in: .workdays)) · \(countdown.phrase(in: .weekends))")
            }
        case .milestones:
            guard yours else {
                fputs("fq: milestones belong to your calendar, so --milestones does not take --calendar\n", stderr)
                exit(2)
            }
            printMilestones(upcoming, on: date)
        }
    }
}

enum Mode {
    case human
    case id
    case status
    case json
    case copy
    case countdown
    case milestones
}

/// Each milestone's next date, soonest first, with its rule underneath.
func printMilestones(_ upcoming: [MilestoneOccurrence], on date: CalendarDate) {
    guard !upcoming.isEmpty else {
        print("No milestones yet.")
        return
    }
    let width = upcoming.map(\.milestone.name.count).max() ?? 0
    let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    for occurrence in upcoming {
        let countdown = occurrence.countdown(from: date)
        let weekday = weekdays[FiscalCalendar.weekday(occurrence.date) - 1]
        let name = occurrence.milestone.name.padding(toLength: width, withPad: " ", startingAt: 0)
        print("\(name)  \(weekday) \(occurrence.date.iso)  \(countdown.phrase(in: .days)) · \(countdown.phrase(in: .workdays))")
        print("\(String(repeating: " ", count: width))  \(occurrence.milestone.summary)")
    }
}

/// The snapshot as JSON, with a `milestones` list when `milestones` is not nil.
func json(_ snapshot: QuarterSnapshot, milestones: [MilestoneOccurrence]?, encoder: JSONEncoder) throws -> String {
    let data = try encoder.encode(snapshot)
    guard let milestones, var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return String(decoding: data, as: UTF8.self)
    }
    object["milestones"] = milestones.map { occurrence -> [String: Any] in
        let countdown = occurrence.countdown(from: snapshot.today)
        return [
            "name": occurrence.milestone.name,
            "rule": occurrence.milestone.summary,
            "date": occurrence.date.iso,
            "quarter": occurrence.quarter.id,
            "days": countdown.days,
            "workdays": countdown.workdays,
            "weekends": countdown.weekends,
        ]
    }
    let merged = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    return String(decoding: merged, as: UTF8.self)
}

/// Your calendar, then each saved calendar, one line each.
func printAll(on date: CalendarDate, mode: Mode) {
    let yours = FiscalYearConfig.load(from: settings).definition
    let rows = [("Yours", yours)] + SavedCalendars.load(from: settings).map { ($0.name, $0.definition) }
    let width = rows.map(\.0.count).max() ?? 0
    for (name, definition) in rows {
        let snapshot = QuarterSnapshot(on: date, calendar: definition)
        let value = mode == .id ? snapshot.quarter.id : snapshot.statusLine
        print(name.padding(toLength: width, withPad: " ", startingAt: 0) + "  " + value)
    }
}

/// A saved calendar's name, or else a path to a calendar JSON file.
func loadCalendar(_ nameOrPath: String) throws -> FiscalCalendarDefinition {
    if let saved = SavedCalendars.named(nameOrPath, in: SavedCalendars.load(from: settings)) {
        return saved.definition
    }
    let path = nameOrPath
    guard FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath) else {
        throw CalendarFileError(path: path, reason: "no saved calendar has that name, and no file is there")
    }
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    do {
        return try FiscalCalendarDefinition(json: Data(contentsOf: url))
    } catch let error as DefinitionError {
        throw CalendarFileError(path: path, reason: error.description)
    } catch DecodingError.dataCorrupted(let context) {
        throw CalendarFileError(path: path, reason: context.debugDescription)
    } catch DecodingError.keyNotFound(let key, _) {
        throw CalendarFileError(path: path, reason: "missing \"\(key.stringValue)\"")
    } catch DecodingError.typeMismatch(_, let context) {
        throw CalendarFileError(path: path, reason: context.debugDescription)
    }
}

struct CalendarFileError: Error, CustomStringConvertible {
    let path: String
    let reason: String

    var description: String { "\(path): \(reason)" }
}

func copyToPasteboard(_ text: String) throws {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
    let input = Pipe()
    task.standardInput = input
    try task.run()
    input.fileHandleForWriting.write(Data(text.utf8))
    try input.fileHandleForWriting.close()
    task.waitUntilExit()
    if task.terminationStatus != 0 {
        throw CocoaError(.fileWriteUnknown)
    }
}

/// fq has no App Group entitlement, so it reads the group's preferences file instead of the suite.
let settings = SharedSettings.readOnlySource()

func printUsage() {
    print(
        """
        fq prints the fiscal quarter.

          fq                  today's quarter
          fq --id             FY26-Q4
          fq --status         one line, for Slack or a doc
          fq --json           one JSON object
          fq --copy           copy the quarter id
          fq --countdown      days, workdays, and weekends to the end of the quarter, half, and year, and to each milestone
          fq --milestones     your milestones' next dates, soonest first
          fq --date YYYY-MM-DD
          fq --calendar NAME  use a saved calendar, or a calendar JSON file, instead of yours
          fq --all            your calendar and every saved one, one line each
        """
    )
}
