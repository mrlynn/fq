import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CalendarSettingsView: View {
    @ObservedObject var calendar: CalendarModel
    let today: CalendarDate
    let dismiss: () -> Void

    @State private var adding = false
    @State private var newName = ""
    @State private var newMonth = 1
    @State private var newDay = 1
    @State private var problem: String?

    private var preview: QuarterSnapshot {
        QuarterSnapshot(on: today, config: calendar.config)
    }

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

            Text("Calendar")
                .font(.system(size: 18, weight: .semibold))

            sectionTitle("Yours")

            option(
                "Default",
                builtInDetail,
                selected: calendar.config.kind == .builtIn
            ) {
                var next = calendar.config
                next.kind = .builtIn
                calendar.set(next)
            }

            option(
                "Custom start",
                "Four quarters of three months, numbered for the year the fiscal year ends.",
                selected: calendar.config.kind == .custom
            ) {
                var next = calendar.config
                next.kind = .custom
                calendar.set(next)
            }

            if calendar.config.kind == .custom {
                HStack(spacing: 12) {
                    Picker("Month", selection: month) {
                        ForEach(1...12, id: \.self) { value in
                            Text(monthName(value)).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Day", selection: day) {
                        ForEach(1...FiscalYearConfig.lastDay(of: calendar.config.startMonth), id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 88, alignment: .leading)
                }
                .font(.system(size: 13))

                Text(namingLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Today is \(preview.quarter.id), \(preview.quarter.start.iso) through \(preview.quarter.end.iso).")
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            otherSection
        }
    }

    /// Calendars kept alongside yours, such as a customer's. They show in the panel but never in the menu bar.
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Others")

            if calendar.others.isEmpty && !adding {
                Text("Add a customer's or partner's calendar to see their quarter next to yours.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(calendar.others) { other in
                savedRow(other)
            }

            if adding {
                addForm
            } else {
                HStack(spacing: 16) {
                    Button("Add calendar…") {
                        newName = ""
                        newMonth = 1
                        newDay = 1
                        problem = nil
                        adding = true
                    }
                    Button("Import file…", action: importFile)
                }
                .buttonStyle(.link)
                .font(.system(size: 13))
            }

            if let problem, !adding {
                problemText(problem)
            }
        }
    }

    private func savedRow(_ other: SavedCalendar) -> some View {
        let quarter = FiscalCalendar.quarter(containing: today, in: other.definition)
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(other.name)
                Text("\(quarter.id) today · \(other.definition.summary)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(action: { calendar.remove(other) }) {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove \(other.name)")
            .accessibilityLabel("Remove \(other.name)")
        }
        .font(.system(size: 13))
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name, such as a customer", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addCalendar)

            HStack(spacing: 12) {
                Picker("Starts", selection: $newMonth) {
                    ForEach(1...12, id: \.self) { value in
                        Text(monthName(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: newMonth) { value in
                    newDay = min(newDay, FiscalYearConfig.lastDay(of: value))
                }

                Picker("Day", selection: $newDay) {
                    ForEach(1...FiscalYearConfig.lastDay(of: newMonth), id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 64, alignment: .leading)
            }

            Text(newPreview)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let problem {
                problemText(problem)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    adding = false
                    problem = nil
                }
                Button("Add", action: addCalendar)
                    .keyboardShortcut(.defaultAction)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .font(.system(size: 13))
    }

    /// What the new calendar says about today, so the start can be checked before it is saved.
    private var newPreview: String {
        let quarter = FiscalCalendar.quarter(containing: today, in: .months(startMonth: newMonth, startDay: newDay))
        return "Today would be \(quarter.id), \(quarter.start.iso) through \(quarter.end.iso)."
    }

    private func addCalendar() {
        problem = calendar.add(.months(startMonth: newMonth, startDay: newDay), named: newName)
        if problem == nil {
            adding = false
        }
    }

    /// Reads a calendar JSON file, the same format `fq --calendar` takes. The name comes from the file.
    private func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a calendar file"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let definition = try FiscalCalendarDefinition(json: Data(contentsOf: url))
            let name = definition.name == "Custom" ? url.deletingPathExtension().lastPathComponent : definition.name
            problem = calendar.add(definition, named: name)
        } catch let error as DefinitionError {
            problem = "\(url.lastPathComponent): \(error.description)"
        } catch {
            problem = "\(url.lastPathComponent) is not a calendar file."
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func problemText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(MarkColor.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var month: Binding<Int> {
        Binding(
            get: { calendar.config.startMonth },
            set: { value in
                var next = calendar.config
                next.kind = .custom
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
                next.kind = .custom
                next.startDay = value
                calendar.set(next)
            }
        )
    }

    /// Describes the built-in calendar in the same terms as the quarter on screen.
    /// FY27 began 1 February, but the current quarter starts 1 October.
    private var builtInDetail: String {
        let quarter = FiscalCalendar.quarter(containing: today)
        let start = "\(quarter.start.day) \(monthName(quarter.start.month))"
        if quarter.fiscalYear == 27 {
            return "This quarter starts \(start). FY27 began 1 February 2026 and ends 31 December. From 2027 the year starts in January."
        }
        if quarter.fiscalYear >= 28 {
            return "This quarter starts \(start). The year starts 1 January."
        }
        return "This quarter starts \(start). The year starts 1 February."
    }

    /// A year that contains 15 Jun 2025, so the sentence shows which calendar year the label comes from.
    private var namingLine: String {
        let probe = CalendarDate(year: 2025, month: 6, day: 15)
        let sample = FiscalCalendar.quarter(containing: probe, config: calendar.config)
        let map = FiscalYearMap.containing(probe, config: calendar.config)
        return "FY\(sample.fiscalYear) runs \(map.start.iso) through \(map.end.iso). The number is the year it ends."
    }

    private func option(_ title: String, _ detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? MarkColor.green : Color.secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func monthName(_ month: Int) -> String {
        let names = [
            "", "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        guard month >= 1, month <= 12 else { return "" }
        return names[month]
    }
}
