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
    @State private var newDayOff = Date()

    private var preview: QuarterSnapshot {
        calendar.snapshot(on: today)
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

            option(
                "Weeks (4-4-5)",
                "52 or 53 weeks, ending on the same weekday every year, as retailers keep.",
                selected: calendar.config.kind == .weeks
            ) {
                var next = calendar.config
                next.kind = .weeks
                calendar.set(next)
            }

            if calendar.config.kind == .weeks {
                weeksControls
            }

            Text("Today is \(preview.quarter.id), \(preview.quarter.start.iso) through \(preview.quarter.end.iso).")
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            workdaysSection

            Divider()

            otherSection
        }
    }

    /// The rule of a 52/53-week year: the weekday and month it ends on, its pattern, where a 53rd
    /// week goes, and whether the FY number is the year it ends or starts.
    private var weeksControls: some View {
        let rule = calendar.config.weekRule
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Ends the")
                    .fixedSize()
                Picker("Method", selection: weekField(\.method)) {
                    Text("last").tag(WeekRule.Method.last)
                    Text("nearest").tag(WeekRule.Method.nearest)
                }
                .labelsHidden()
                .fixedSize()
                Picker("Weekday", selection: weekField(\.endWeekday)) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(WeekRule.weekdayName(weekday)).tag(weekday)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack(spacing: 6) {
                Text(rule.method == .last ? "of" : "to the end of")
                    .fixedSize()
                Picker("Month", selection: weekField(\.endMonth)) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthName(month)).tag(month)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack(spacing: 6) {
                Picker("Pattern", selection: weekField(\.pattern)) {
                    ForEach(WeekRule.Pattern.allCases) { pattern in
                        Text(pattern.rawValue).tag(pattern)
                    }
                }
                .fixedSize()
                Picker("53rd week", selection: weekField(\.extraWeek)) {
                    Text("in Q4").tag(WeekRule.ExtraWeek.q4)
                    Text("in Q1").tag(WeekRule.ExtraWeek.q1)
                }
                .fixedSize()
            }
            Picker("FY number is", selection: weekField(\.yearOffset)) {
                Text("the year it ends").tag(0)
                Text("the year it starts").tag(-1)
            }
            .fixedSize()
            HStack(spacing: 4) {
                Text(weeksNamingLine)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12))
            if rule != .retail {
                Button("Use the retail calendar (NRF 4-5-4)") {
                    var next = calendar.config
                    next.weekRule = .retail
                    calendar.set(next)
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
        }
        .pickerStyle(.menu)
        .font(.system(size: 13))
    }

    /// `FY26 runs 2026-02-01 through 2027-01-30, 52 weeks.`
    private var weeksNamingLine: String {
        let map = FiscalYearMap.containing(today, config: calendar.config)
        let weeks = map.length / 7
        return "FY\(map.fiscalYear) runs \(map.start.iso) through \(map.end.iso), \(weeks) weeks."
    }

    private func weekField<Value>(_ path: WritableKeyPath<WeekRule, Value>) -> Binding<Value> {
        Binding(
            get: { calendar.config.weekRule[keyPath: path] },
            set: { value in
                var next = calendar.config
                next.kind = .weeks
                next.weekRule[keyPath: path] = value
                calendar.set(next)
            }
        )
    }

    /// Which weekdays the workday counts skip: a country's public holidays, and days off of your own.
    private var workdaysSection: some View {
        let workweek = calendar.workweek
        let upcoming = workweek.daysOff.filter { $0 >= today }.sorted()
        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Workdays")

            Picker("Holidays", selection: region) {
                Text("None").tag(HolidayRegion?.none)
                ForEach(HolidayRegion.allCases) { region in
                    Text(region.title).tag(HolidayRegion?.some(region))
                }
            }
            .pickerStyle(.menu)

            Text(nextDayOffLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(upcoming, id: \.self) { day in
                HStack {
                    Text(DayWords.short(day, today: today))
                    Spacer(minLength: 8)
                    Button {
                        var next = workweek
                        next.daysOff.remove(day)
                        calendar.setWorkweek(next)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this day off")
                    .accessibilityLabel("Remove the day off on \(DayWords.short(day, today: today))")
                }
            }

            HStack(spacing: 8) {
                DatePicker("Day off", selection: $newDayOff, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .labelsHidden()
                Button("Add day off") {
                    // Days off that have passed no longer change any count, so adding one clears them.
                    var next = workweek
                    next.daysOff = next.daysOff.filter { $0 >= today }
                    next.daysOff.insert(CalendarDate(newDayOff, calendar: .current))
                    calendar.setWorkweek(next)
                }
                .buttonStyle(.link)
            }
        }
        .font(.system(size: 13))
    }

    /// `Next day off: Wed 11 Nov, Veterans Day.` or what workdays are without any.
    private var nextDayOffLine: String {
        let workweek = calendar.workweek
        guard let next = workweek.nextDayOff(onOrAfter: today) else {
            return "Workdays are Monday through Friday. Choose a country to skip its public holidays, or add your own days off."
        }
        return "Next day off: \(DayWords.short(next.date, today: today)), \(next.name)."
    }

    private var region: Binding<HolidayRegion?> {
        Binding(
            get: { calendar.workweek.region },
            set: { value in
                var next = calendar.workweek
                next.region = value
                calendar.setWorkweek(next)
            }
        )
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
    private var builtInDetail: String {
        let quarter = FiscalCalendar.quarter(containing: today)
        let start = "\(quarter.start.day) \(monthName(quarter.start.month))"
        return "The calendar year, numbered by that year, so \(today.year) is FY\(String(format: "%02d", quarter.fiscalYear)). This quarter starts \(start)."
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
