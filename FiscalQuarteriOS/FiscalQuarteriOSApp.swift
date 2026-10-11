import SwiftUI
import UIKit

@main
struct FiscalQuarteriOSApp: App {
    @StateObject private var clock = QuarterClock()
    @StateObject private var calendar = CalendarModel()

    var body: some Scene {
        WindowGroup {
            QuarterScreen(clock: clock, calendar: calendar)
        }
    }
}

/// The phone version of the menu bar panel: today's quarter, the countdowns, and the other calendars.
struct QuarterScreen: View {
    @ObservedObject var clock: QuarterClock
    @ObservedObject var calendar: CalendarModel
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("yearPicture") private var pictureKind = PictureKind.line.rawValue
    @AppStorage("countdownUnit") private var countdownUnit = CountdownUnit.days.rawValue
    @State private var adding = false
    @State private var copied: String?

    private var snapshot: QuarterSnapshot {
        QuarterSnapshot(on: CalendarDate(clock.today, calendar: .current), config: calendar.config)
    }

    var body: some View {
        let snapshot = snapshot
        let unit = CountdownUnit(rawValue: countdownUnit) ?? .days
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copied ?? "Fiscal quarter")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(snapshot.quarter.id)
                                .font(Theme(appearance: calendar.appearance).numberFont(34))
                        }
                        YearPicture(
                            snapshot: snapshot,
                            kind: PictureKind(rawValue: pictureKind) ?? .line,
                            select: { pictureKind = $0.rawValue }
                        )
                        HStack {
                            Text(snapshot.progressLine)
                            Spacer()
                            Text("\(snapshot.percent)%").monospacedDigit()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        if let pace = snapshot.paceNote {
                            Text(pace)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(MarkColor.warning)
                        }
                    }
                    .padding(.vertical, 6)
                    .photoLegibility(calendar.appearance)
                    .themed(calendar.appearance)
                    .fontDesign(Theme(appearance: calendar.appearance).fontDesign)
                    .listRowBackground(heroBackground)
                }

                Section {
                    Picker("Count in", selection: $countdownUnit) {
                        ForEach(CountdownUnit.allCases) { unit in
                            Text(unit.title).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    ForEach(snapshot.countdownGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(group.label)
                                Spacer()
                                Text(group.first.phrase(in: unit))
                                    .monospacedDigit()
                                    .foregroundStyle(group.first.days <= 14 ? MarkColor.warning : Color.primary)
                            }
                            Text("Ends \(group.end.iso)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Countdown")
                } footer: {
                    if unit == .workdays {
                        Text("Monday through Friday. Holidays are counted as workdays.")
                    }
                }

                Section("This quarter") {
                    row("Start", snapshot.quarter.start.iso)
                    row("End", snapshot.quarter.end.iso)
                    row("Next", "\(snapshot.next.id) · \(snapshot.next.start.iso)")
                    if let note = snapshot.transitionNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    ForEach(calendar.others) { other in
                        let theirs = QuarterSnapshot(on: snapshot.today, calendar: other.definition)
                        Button {
                            copy("\(other.name): \(theirs.statusLine)")
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(other.name).foregroundStyle(.primary)
                                    Text(other.definition.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(theirs.quarter.id).monospacedDigit().foregroundStyle(.primary)
                                Text("\(theirs.daysRemaining)d")
                                    .monospacedDigit()
                                    .foregroundStyle(theirs.paceNote != nil ? MarkColor.warning : Color.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { calendar.others[$0] }.forEach(calendar.remove)
                    }
                    Button("Add calendar") { adding = true }
                } header: {
                    Text("Other calendars")
                } footer: {
                    Text("Tap a calendar to copy its status line.")
                }

                Section {
                    NavigationLink("Your calendar") {
                        YourCalendarScreen(calendar: calendar, today: snapshot.today)
                    }
                    NavigationLink("Appearance") {
                        AppearanceEditor(calendar: calendar, today: snapshot.today)
                            .navigationTitle("Appearance")
                    }
                }
            }
            .navigationTitle("Fiscal Quarter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        copy(snapshot.quarter.id)
                    } label: {
                        Label("Copy quarter id", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: snapshot.statusLine) {
                        Label("Share status line", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $adding) {
                AddCalendarScreen(calendar: calendar, today: snapshot.today)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clock.refresh() }
        }
    }

    /// The top card wears the chosen background. The system look keeps the normal cell color.
    @ViewBuilder
    private var heroBackground: some View {
        if calendar.appearance.background == .system {
            Color(uiColor: .secondarySystemGroupedBackground)
        } else {
            ThemeBackground(appearance: calendar.appearance, image: calendar.backgroundImage)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        copied = "Copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copied = nil
        }
    }
}

struct AddCalendarScreen: View {
    @ObservedObject var calendar: CalendarModel
    let today: CalendarDate
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var month = 1
    @State private var day = 1
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, such as a customer", text: $name)
                }
                Section {
                    MonthDayPicker(month: $month, day: $day)
                } header: {
                    Text("The year starts")
                } footer: {
                    let quarter = FiscalCalendar.quarter(containing: today, in: .months(startMonth: month, startDay: day))
                    Text("Today would be \(quarter.id), \(quarter.start.iso) through \(quarter.end.iso).")
                }
                if let problem {
                    Text(problem).foregroundStyle(MarkColor.warning)
                }
            }
            .navigationTitle("Add calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        problem = calendar.add(.months(startMonth: month, startDay: day), named: name)
                        if problem == nil { dismiss() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct YourCalendarScreen: View {
    @ObservedObject var calendar: CalendarModel
    let today: CalendarDate

    var body: some View {
        Form {
            Section {
                Picker("Calendar", selection: kind) {
                    Text("Default").tag(FiscalYearConfig.Kind.builtIn)
                    Text("Custom start").tag(FiscalYearConfig.Kind.custom)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                if calendar.config.kind == .builtIn {
                    Text("The calendar year, numbered by that year, so \(String(today.year)) is FY\(String(format: "%02d", today.year % 100)).")
                } else {
                    Text("Four quarters of three months, numbered for the year the fiscal year ends.")
                }
            }
            if calendar.config.kind == .custom {
                Section("The year starts") {
                    MonthDayPicker(month: month, day: day)
                }
            }
            Section {
                let quarter = FiscalCalendar.quarter(containing: today, config: calendar.config)
                Text("Today is \(quarter.id), \(quarter.start.iso) through \(quarter.end.iso).")
            }
        }
        .navigationTitle("Your calendar")
    }

    private var kind: Binding<FiscalYearConfig.Kind> {
        Binding(
            get: { calendar.config.kind },
            set: { value in
                var next = calendar.config
                next.kind = value
                calendar.set(next)
            }
        )
    }

    private var month: Binding<Int> {
        Binding(
            get: { calendar.config.startMonth },
            set: { value in
                var next = calendar.config
                next.startMonth = value
                next.startDay = min(next.startDay, FiscalYearConfig.lastDay(of: value))
                calendar.set(next)
            }
        )
    }

    private var day: Binding<Int> {
        Binding(
            get: { calendar.config.startDay },
            set: { value in
                var next = calendar.config
                next.startDay = value
                calendar.set(next)
            }
        )
    }
}

struct MonthDayPicker: View {
    @Binding var month: Int
    @Binding var day: Int

    var body: some View {
        Picker("Month", selection: $month) {
            ForEach(1...12, id: \.self) { value in
                Text(Calendar(identifier: .gregorian).monthSymbols[value - 1]).tag(value)
            }
        }
        .onChange(of: month) { _, value in
            day = min(day, FiscalYearConfig.lastDay(of: value))
        }
        Picker("Day", selection: $day) {
            ForEach(1...FiscalYearConfig.lastDay(of: month), id: \.self) { value in
                Text("\(value)").tag(value)
            }
        }
    }
}
