import AppKit
import SwiftUI

struct QuarterPanel: View {
    @ObservedObject var clock: QuarterClock
    @ObservedObject var calendar: CalendarModel
    @ObservedObject var commandLine: CommandLineToolController
    @ObservedObject var reminders: ReminderScheduler
    @StateObject private var login = LoginItemController()
    @AppStorage("yearPicture") private var pictureKind = PictureKind.line.rawValue
    @AppStorage(MenuBarCountdown.targetKey) private var menuBarTarget = CountdownTarget.quarter.rawValue
    @AppStorage(MenuBarCountdown.unitKey) private var countdownUnit = CountdownUnit.days.rawValue
    @State private var notice: String?
    @State private var copyGeneration = 0
    @State private var page = PanelPage.quarter

    private var snapshot: QuarterSnapshot {
        QuarterSnapshot(on: CalendarDate(clock.today, calendar: .current), config: calendar.config)
    }

    var body: some View {
        Group {
            switch page {
            case .quarter:
                quarterPage
                    .photoLegibility(calendar.appearance)
            case .about:
                AboutView(commandLine: commandLine, dismiss: { page = .quarter })
                    .photoLegibility(calendar.appearance)
            case .calendar:
                CalendarSettingsView(
                    calendar: calendar,
                    today: snapshot.today,
                    dismiss: { page = .quarter }
                )
                .photoLegibility(calendar.appearance)
            case .milestones:
                MilestonesView(calendar: calendar, reminders: reminders, today: snapshot.today, dismiss: { page = .quarter })
                    .photoLegibility(calendar.appearance)
            // No shadow here: the form draws its own cards, and shadowed text on them looks wrong.
            case .appearance:
                VStack(alignment: .leading, spacing: 12) {
                    backButton
                    Text("Appearance")
                        .font(.system(size: 18, weight: .semibold))
                    AppearanceEditor(calendar: calendar, today: snapshot.today)
                        .frame(height: 560)
                        .padding(.horizontal, -16)
                }
            }
        }
        .padding(16)
        .frame(width: 328)
        .themed(calendar.appearance)
        .fontDesign(Theme(appearance: calendar.appearance).fontDesign)
        .background(ThemeBackground(appearance: calendar.appearance, image: calendar.backgroundImage))
        .animation(.easeInOut(duration: 0.18), value: page)
        .onAppear { clock.refresh() }
    }

    private var quarterPage: some View {
        let snapshot = snapshot
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(notice ?? "Fiscal quarter")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button(action: { copy(snapshot.quarter.id) }) {
                    Text(snapshot.quarter.id)
                        .font(Theme(appearance: calendar.appearance).numberFont(22))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy \(snapshot.quarter.id)")
                .accessibilityAddTraits(.isHeader)
            }

            YearPicture(
                snapshot: snapshot,
                kind: PictureKind(rawValue: pictureKind) ?? .line,
                select: { pictureKind = $0.rawValue }
            )
            .animation(.easeInOut(duration: 0.18), value: pictureKind)

            HStack {
                Text(snapshot.progressLine)
                Spacer(minLength: 12)
                Text("\(snapshot.percent)%")
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(snapshot.progressLine), \(snapshot.percent) percent")

            if let pace = snapshot.paceNote {
                Text(pace)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MarkColor.warning)
            }

            VStack(alignment: .leading, spacing: 6) {
                row("Start", snapshot.quarter.start.iso)
                row("End", snapshot.quarter.end.iso)
                row("Days remaining", String(snapshot.daysRemaining), warning: snapshot.paceNote != nil)
                row("Today", snapshot.today.iso)
                row("Next", "\(snapshot.next.id) · \(snapshot.next.start.iso)")
            }

            if let note = snapshot.transitionNote {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            countdowns(snapshot)

            if !calendar.others.isEmpty {
                Divider()
                otherCalendars(on: snapshot.today)
            }

            Divider()

            actionButton("Copy quarter id", shortcut: "⌘C") {
                copy(snapshot.quarter.id)
            }
            .keyboardShortcut("c")

            actionButton("Copy status line", shortcut: "⇧⌘C") {
                copy(snapshot.statusLine)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Toggle(isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) })) {
                Text("Open at login")
            }
            .toggleStyle(.switch)
            .font(.system(size: 13))
            .accessibilityHint(login.message ?? "Launch Fiscal Quarter after you sign in")

            if let message = login.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            actionButton("Calendar") { page = .calendar }

            actionButton("Milestones") { page = .milestones }

            actionButton("Appearance") { page = .appearance }

            actionButton("About") { page = .about }

            actionButton("Quit", shortcut: "⌘Q", action: quit)
                .keyboardShortcut("q")
        }
    }

    /// The end of the quarter, half, and year, merged when they fall on the same day.
    /// Clicking a line puts that countdown in the menu bar.
    private func countdowns(_ snapshot: QuarterSnapshot) -> some View {
        let unit = CountdownUnit(rawValue: countdownUnit) ?? .days
        let selected = CountdownTarget(rawValue: menuBarTarget) ?? .quarter
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Countdown")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Count in", selection: $countdownUnit) {
                    ForEach(CountdownUnit.allCases) { unit in
                        Text(unit.title).tag(unit.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .font(.system(size: 12))
            }
            ForEach(snapshot.countdownGroups) { group in
                let inMenuBar = group.countdowns.contains { $0.target == selected }
                Button(action: { menuBarTarget = group.first.target?.rawValue ?? menuBarTarget }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(group.label)
                            .lineLimit(1)
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .opacity(inMenuBar ? 1 : 0)
                        Spacer(minLength: 12)
                        Text(group.first.phrase(in: unit))
                            .monospacedDigit()
                            .foregroundStyle(group.first.isSoon ? MarkColor.warning : Color.primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .help(inMenuBar ? "Shown in the menu bar" : "Show in the menu bar")
                .accessibilityLabel("\(group.label) ends \(group.end.iso), \(group.first.phrase(in: unit))")
                .accessibilityAddTraits(inMenuBar ? .isSelected : [])
            }
            ForEach(calendar.upcoming(on: snapshot.today), id: \.milestone.id) { occurrence in
                milestoneRow(occurrence, today: snapshot.today, unit: unit)
            }
        }
    }

    /// A milestone's next date, counted like the periods above it. Amber in its last week.
    private func milestoneRow(_ occurrence: MilestoneOccurrence, today: CalendarDate, unit: CountdownUnit) -> some View {
        let countdown = occurrence.countdown(from: today)
        let key = MenuBarCountdown.key(for: occurrence.milestone)
        let inMenuBar = menuBarTarget == key
        return Button(action: { menuBarTarget = key }) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(occurrence.milestone.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "menubar.rectangle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .opacity(inMenuBar ? 1 : 0)
                Spacer(minLength: 12)
                Text(countdown.phrase(in: unit))
                    .monospacedDigit()
                    .foregroundStyle(countdown.isSoon ? MarkColor.warning : Color.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
        .help("\(MilestoneWords.day(occurrence.date)) · \(occurrence.milestone.summary)")
        .accessibilityLabel("\(occurrence.milestone.name) on \(MilestoneWords.day(occurrence.date)), \(countdown.phrase(in: unit))")
        .accessibilityHint(inMenuBar ? "Shown in the menu bar" : "Shows it in the menu bar")
        .accessibilityAddTraits(inMenuBar ? .isSelected : [])
    }

    /// One line per saved calendar. Clicking a line copies that calendar's status line, prefixed with its name.
    private func otherCalendars(on today: CalendarDate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Other calendars")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            ForEach(calendar.others) { other in
                let theirs = QuarterSnapshot(on: today, calendar: other.definition)
                Button(action: { copy("\(other.name): \(theirs.statusLine)") }) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(other.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 16)
                        Text(theirs.quarter.id)
                            .monospacedDigit()
                        Text("\(theirs.daysRemaining)d")
                            .monospacedDigit()
                            .foregroundStyle(theirs.paceNote != nil ? MarkColor.warning : Color.secondary)
                            .frame(minWidth: 34, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .help("Copy \(other.name)'s status line")
                .accessibilityLabel("\(other.name), \(theirs.quarter.id), \(theirs.daysRemaining) days remaining")
                .accessibilityHint("Copies the status line")
            }
        }
    }

    private var backButton: some View {
        Button(action: { page = .quarter }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text("Quarter")
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Back to the quarter")
    }

    private func row(_ title: String, _ value: String, warning: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(warning ? MarkColor.warning : Color.primary)
        }
        .font(.system(size: 13))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private func actionButton(_ title: String, shortcut: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if !shortcut.isEmpty {
                    Text(shortcut)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
    }

    private func copy(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        copyGeneration += 1
        let generation = copyGeneration
        notice = "COPIED"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copyGeneration == generation {
                notice = nil
            }
        }
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private enum PanelPage: Equatable {
    case quarter
    case about
    case calendar
    case milestones
    case appearance
}

/// Which countdown the menu bar shows, and in what unit. The default reads `FY26-Q4 · 82d`.
///
/// The stored choice is a period's raw value, such as `quarter`, or `milestone:` and a milestone's id.
enum MenuBarCountdown {
    static let targetKey = "menuBarCountdown"
    static let unitKey = "countdownUnit"

    static func key(for milestone: Milestone) -> String {
        "milestone:\(milestone.id.uuidString)"
    }

    /// The countdown for a stored choice. A milestone that has since been removed falls back to the quarter.
    static func countdown(for key: String, snapshot: QuarterSnapshot, upcoming: [MilestoneOccurrence]) -> Countdown {
        if let occurrence = upcoming.first(where: { Self.key(for: $0.milestone) == key }) {
            return occurrence.countdown(from: snapshot.today)
        }
        return snapshot.countdown(to: CountdownTarget(rawValue: key) ?? .quarter)
    }
}
