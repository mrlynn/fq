import SwiftUI
import UIKit
import UserNotifications

/// Your milestones and the notifications, the phone version of the Mac's Milestones page.
struct MilestonesScreen: View {
    @ObservedObject var calendar: CalendarModel
    @ObservedObject var reminders: ReminderScheduler
    let today: CalendarDate

    /// The milestone in the sheet, new or a copy of a saved one.
    @State private var editing: Milestone?

    var body: some View {
        Form {
            Section {
                ForEach(calendar.milestones) { milestone in
                    Button {
                        editing = milestone
                    } label: {
                        // Concrete colors: inside a button, .primary and .secondary take the tint.
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.name).foregroundStyle(Color.primary)
                            Text(line(for: milestone))
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { calendar.milestones[$0] }.forEach(calendar.remove)
                }
                Button("Add milestone") {
                    editing = Milestone(name: "", offset: 5)
                }
            } footer: {
                if calendar.milestones.isEmpty {
                    Text("A milestone is a date that comes around every quarter, such as a forecast due 5 workdays before quarter end. Each one counts down beside the quarter.")
                }
            }

            Section {
                Toggle("Milestones", isOn: reminder(\.milestones))
                Toggle("Last two weeks of the quarter", isOn: reminder(\.lastTwoWeeks))
                Toggle("First day of a quarter", isOn: reminder(\.newQuarter))
                Toggle("30 days before the year ends", isOn: reminder(\.yearEnd))
                if calendar.reminders.anyOn {
                    DatePicker("Send at", selection: sendTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Notifications")
            } footer: {
                if calendar.reminders.anyOn && reminders.authorization == .denied {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notifications are off for Fiscal Quarter in Settings, so none will be sent.")
                            .foregroundStyle(MarkColor.warning)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                } else if calendar.reminders.anyOn {
                    Text("They're planned a month ahead each time the app opens, so open it now and then to keep them coming.")
                }
            }
        }
        .navigationTitle("Milestones")
        .sheet(item: $editing) { milestone in
            MilestoneEditor(calendar: calendar, today: today, draft: milestone)
        }
        .task { await reminders.refreshAuthorization() }
    }

    /// `Thu 24 Dec · 5 workdays before quarter end, every quarter`.
    private func line(for milestone: Milestone) -> String {
        guard let next = milestone.next(onOrAfter: today, in: calendar.config.definition, workweek: calendar.workweek) else { return milestone.summary }
        return "\(DayWords.short(next.date, today: today)) · \(milestone.summary)"
    }

    /// Turning the first one on makes the scheduler ask for permission.
    private func reminder(_ path: WritableKeyPath<ReminderSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { calendar.reminders[keyPath: path] },
            set: { on in
                var next = calendar.reminders
                next[keyPath: path] = on
                calendar.setReminders(next)
            }
        )
    }

    private var sendTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: calendar.reminders.hour, minute: calendar.reminders.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                var next = calendar.reminders
                next.hour = parts.hour ?? 9
                next.minute = parts.minute ?? 0
                calendar.setReminders(next)
            }
        )
    }
}

/// Adds a milestone or changes one, with its next date shown before it is saved.
struct MilestoneEditor: View {
    @ObservedObject var calendar: CalendarModel
    let today: CalendarDate
    @State var draft: Milestone
    @Environment(\.dismiss) private var dismiss
    @State private var problem: String?

    private var isNew: Bool {
        !calendar.milestones.contains { $0.id == draft.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, such as Forecast due", text: $draft.name)
                }

                Section {
                    Stepper(value: $draft.offset, in: 0...Milestone.maximumOffset) {
                        Text("\(draft.offset) \(unitWord(draft.unit))")
                            .monospacedDigit()
                    }
                    Picker("Count in", selection: $draft.unit) {
                        ForEach(Milestone.Unit.allCases) { unit in
                            Text(sentenceCase(unit.rawValue)).tag(unit)
                        }
                    }
                    Picker("Direction", selection: $draft.direction) {
                        ForEach(Milestone.Direction.allCases) { direction in
                            Text(sentenceCase(direction.rawValue)).tag(direction)
                        }
                    }
                    .disabled(draft.offset == 0)
                    Picker("From", selection: $draft.anchor) {
                        ForEach(Milestone.Anchor.allCases) { anchor in
                            Text(sentenceCase(anchor.title)).tag(anchor)
                        }
                    }
                } header: {
                    Text("When")
                } footer: {
                    Text(draft.summary)
                }

                Section {
                    ForEach(1...4, id: \.self) { number in
                        Toggle("Q\(number)", isOn: quarter(number))
                    }
                } header: {
                    Text("Quarters")
                } footer: {
                    Text("It runs in each quarter that is on.")
                }

                Section {
                    Toggle("Move a day off to the workday before", isOn: Binding(
                        get: { draft.weekend == .fridayBefore },
                        set: { draft.weekend = $0 ? .fridayBefore : .keep }
                    ))
                    Picker("Remind", selection: $draft.reminderLead) {
                        ForEach(Milestone.reminderLeads, id: \.self) { lead in
                            Text(lead == 0 ? "On the day" : lead == 1 ? "1 workday before" : "\(lead) workdays before").tag(lead)
                        }
                    }
                } footer: {
                    if let problem {
                        Text(problem).foregroundStyle(MarkColor.warning)
                    } else {
                        Text(preview)
                    }
                }
            }
            .navigationTitle(isNew ? "Add milestone" : "Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        problem = calendar.save(draft)
                        if problem == nil { dismiss() }
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: draft) { _, _ in problem = nil }
        }
    }

    /// `Quarter end`, not `Quarter End`.
    private func sentenceCase(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private func unitWord(_ unit: Milestone.Unit) -> String {
        draft.offset == 1 ? String(unit.rawValue.dropLast()) : unit.rawValue
    }

    /// Every quarter is stored as none chosen, and shows here as all four on.
    /// Turning the last one off turns them all back on, since a milestone must run somewhere.
    private func quarter(_ number: Int) -> Binding<Bool> {
        Binding(
            get: { draft.quarters.isEmpty || draft.quarters.contains(number) },
            set: { on in
                var chosen = draft.quarters.isEmpty ? Set(1...4) : draft.quarters
                if on { chosen.insert(number) } else { chosen.remove(number) }
                draft.quarters = chosen.count == 4 ? [] : chosen
            }
        )
    }

    private var preview: String {
        guard let next = draft.next(onOrAfter: today, in: calendar.config.definition, workweek: calendar.workweek) else { return draft.summary }
        let away = next.countdown(from: today).days - 1
        let when = away == 0 ? "today" : away == 1 ? "tomorrow" : "\(away) days from today"
        return "Next \(DayWords.short(next.date, today: today)) (\(next.quarter.id)), \(when)."
    }
}
