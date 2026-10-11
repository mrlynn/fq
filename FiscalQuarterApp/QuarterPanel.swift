import AppKit
import SwiftUI

struct QuarterPanel: View {
    @ObservedObject var clock: QuarterClock
    @ObservedObject var calendar: CalendarModel
    @StateObject private var login = LoginItemController()
    @AppStorage("yearPicture") private var pictureKind = PictureKind.line.rawValue
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
            case .about:
                AboutView(dismiss: { page = .quarter })
            case .calendar:
                CalendarSettingsView(
                    calendar: calendar,
                    today: snapshot.today,
                    dismiss: { page = .quarter }
                )
            }
        }
        .padding(16)
        .frame(width: 328)
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
                        .font(.system(size: 22, weight: .semibold))
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

            actionButton("About") { page = .about }

            actionButton("Quit", shortcut: "⌘Q", action: quit)
                .keyboardShortcut("q")
        }
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
}
