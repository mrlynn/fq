import AppKit
import SwiftUI
import UserNotifications

/// Your milestones: the list, and a form to add one or change one.
struct MilestonesView: View {
    @ObservedObject var calendar: CalendarModel
    @ObservedObject var reminders: ReminderScheduler
    let today: CalendarDate
    let dismiss: () -> Void

    @AppStorage(MenuBarCountdown.targetKey) private var menuBarTarget = CountdownTarget.quarter.rawValue
    /// The milestone in the form, new or a copy of a saved one. Nil when the form is closed.
    @State private var draft: Milestone?
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: dismiss) {
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

            Text("Milestones")
                .font(.system(size: 18, weight: .semibold))

            if calendar.milestones.isEmpty && draft == nil {
                Text("A milestone is a date that comes around every quarter, such as a forecast due 5 workdays before quarter end. Each one counts down in the panel, and can go in the menu bar.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(calendar.milestones) { milestone in
                if draft?.id == milestone.id {
                    form
                } else {
                    row(milestone)
                }
            }

            if let draft, !calendar.milestones.contains(where: { $0.id == draft.id }) {
                form
            } else if draft == nil {
                Button("Add milestone…") {
                    problem = nil
                    draft = Milestone(name: "", offset: 5)
                }
                .buttonStyle(.link)
                .font(.system(size: 13))
            }

            if draft == nil {
                Divider()
                notifications
            }
        }
        .task { await reminders.refreshAuthorization() }
    }

    // MARK: Notifications

    private var notifications: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTIFICATIONS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            reminderToggle("Milestones", \.milestones)
            reminderToggle("Last two weeks of the quarter", \.lastTwoWeeks)
            reminderToggle("First day of a quarter", \.newQuarter)
            reminderToggle("30 days before the year ends", \.yearEnd)

            if calendar.reminders.anyOn {
                DatePicker("Send at", selection: sendTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field)
                    .fixedSize()
            }

            if calendar.reminders.anyOn && reminders.authorization == .denied {
                Text("Notifications are off for Fiscal Quarter in System Settings, so none will be sent.")
                    .font(.system(size: 12))
                    .foregroundStyle(MarkColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Notifications settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
        }
        .font(.system(size: 13))
    }

    /// Turning the first one on makes the scheduler ask macOS for permission.
    private func reminderToggle(_ title: String, _ path: WritableKeyPath<ReminderSettings, Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { calendar.reminders[keyPath: path] },
            set: { on in
                var next = calendar.reminders
                next[keyPath: path] = on
                calendar.setReminders(next)
            }
        ))
        .toggleStyle(.checkbox)
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

    // MARK: List

    private func row(_ milestone: Milestone) -> some View {
        let next = milestone.next(onOrAfter: today, in: calendar.config.definition)
        return HStack(alignment: .top, spacing: 8) {
            Button {
                problem = nil
                draft = milestone
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.name)
                    Text(next.map { "\(DayWords.short($0.date, today: today)) · \(milestone.summary)" } ?? milestone.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Change \(milestone.name)")
            .disabled(draft != nil)

            Button(action: { remove(milestone) }) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove \(milestone.name)")
            .accessibilityLabel("Remove \(milestone.name)")
            .disabled(draft != nil)
        }
        .font(.system(size: 13))
    }

    private func remove(_ milestone: Milestone) {
        if menuBarTarget == MenuBarCountdown.key(for: milestone) {
            menuBarTarget = CountdownTarget.quarter.rawValue
        }
        calendar.remove(milestone)
    }

    // MARK: Form

    @ViewBuilder
    private var form: some View {
        if let current = draft {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name, such as Forecast due", text: field(\.name))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)

                HStack(spacing: 8) {
                    TextField("Distance", value: field(\.offset), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 48)
                    Stepper("Distance", value: field(\.offset), in: 0...Milestone.maximumOffset)
                        .labelsHidden()
                    Picker("Unit", selection: field(\.unit)) {
                        ForEach(Milestone.Unit.allCases) { unit in
                            Text(current.offset == 1 ? String(unit.rawValue.dropLast()) : unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                HStack(spacing: 8) {
                    Picker("Direction", selection: field(\.direction)) {
                        ForEach(Milestone.Direction.allCases) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                    .disabled(current.offset == 0)
                    Picker("Anchor", selection: field(\.anchor)) {
                        ForEach(Milestone.Anchor.allCases) { anchor in
                            Text(anchor.title).tag(anchor)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                HStack(spacing: 6) {
                    ForEach(1...4, id: \.self) { number in
                        quarterButton(number, in: current)
                    }
                    Text(current.quartersSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }

                Toggle("Move a weekend day to the Friday before", isOn: Binding(
                    get: { current.weekend == .fridayBefore },
                    set: { draft?.weekend = $0 ? .fridayBefore : .keep }
                ))
                .toggleStyle(.checkbox)

                Picker("Remind", selection: field(\.reminderLead)) {
                    ForEach(Milestone.reminderLeads, id: \.self) { lead in
                        Text(lead == 0 ? "On the day" : lead == 1 ? "1 workday before" : "\(lead) workdays before").tag(lead)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help(calendar.reminders.milestones ? "When this milestone's notification is sent" : "Turn on Milestones under Notifications to be reminded")

                Text(preview(current))
                    .font(.system(size: 12))
                    .foregroundStyle(problem == nil ? .secondary : MarkColor.warning)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        draft = nil
                        problem = nil
                    }
                    Button(calendar.milestones.contains(where: { $0.id == current.id }) ? "Save" : "Add", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(current.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .font(.system(size: 13))
        }
    }

    /// No quarter chosen means every quarter, so choosing all four is the same as choosing none.
    private func quarterButton(_ number: Int, in current: Milestone) -> some View {
        let chosen = current.quarters.contains(number)
        return Button {
            var quarters = current.quarters
            if chosen { quarters.remove(number) } else { quarters.insert(number) }
            draft?.quarters = quarters.count == 4 ? [] : quarters
        } label: {
            Text("Q\(number)")
                .font(.system(size: 12, weight: chosen ? .semibold : .regular))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(chosen ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06)))
                .overlay(Capsule().strokeBorder(chosen ? Color.accentColor : Color.primary.opacity(0.15)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quarter \(number)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    /// The next date the form's rule gives, so it can be checked before it is saved.
    private func preview(_ milestone: Milestone) -> String {
        if let problem { return problem }
        if milestone.offset < 0 || milestone.offset > Milestone.maximumOffset {
            return "Use a distance from 0 to \(Milestone.maximumOffset)."
        }
        guard let next = milestone.next(onOrAfter: today, in: calendar.config.definition) else {
            return milestone.summary
        }
        // Countdowns count today, so the day itself is 1. Here it reads as days from today.
        let away = next.countdown(from: today).days - 1
        let when = away == 0 ? "today" : away == 1 ? "tomorrow" : "\(away) days from today"
        return "Next \(DayWords.short(next.date, today: today)) (\(next.quarter.id)), \(when)."
    }

    private func save() {
        guard let draft else { return }
        problem = calendar.save(draft)
        if problem == nil {
            self.draft = nil
        }
    }

    private func field<Value>(_ path: WritableKeyPath<Milestone, Value>) -> Binding<Value> {
        Binding(
            get: { draft![keyPath: path] },
            set: { value in
                draft?[keyPath: path] = value
                problem = nil
            }
        )
    }
}
