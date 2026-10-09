import SwiftUI

final class CalendarModel: ObservableObject {
    @Published private(set) var config: FiscalYearConfig

    init() {
        config = FiscalYearConfig.load(from: FiscalYearConfig.store)
    }

    func set(_ config: FiscalYearConfig) {
        self.config = config
        config.save(to: FiscalYearConfig.store)
    }
}

struct CalendarSettingsView: View {
    @ObservedObject var calendar: CalendarModel
    let today: CalendarDate
    let dismiss: () -> Void

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

            option(
                "Default",
                "February start, the short FY27, then calendar years from 2027.",
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
        }
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
