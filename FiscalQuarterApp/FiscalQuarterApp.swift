import AppKit
import SwiftUI

@main
struct FiscalQuarterApp: App {
    @StateObject private var clock: QuarterClock
    @StateObject private var calendar: CalendarModel
    /// Created at launch so `fq` is linked before the panel is ever opened.
    @StateObject private var commandLine = CommandLineToolController()
    @StateObject private var reminders: ReminderScheduler
    @AppStorage(MenuBarCountdown.targetKey) private var menuBarTarget = CountdownTarget.quarter.rawValue
    @AppStorage(MenuBarCountdown.unitKey) private var countdownUnit = CountdownUnit.days.rawValue

    init() {
        let clock = QuarterClock()
        let calendar = CalendarModel()
        _clock = StateObject(wrappedValue: clock)
        _calendar = StateObject(wrappedValue: calendar)
        // Built here, not on first use, so reminders are planned at launch.
        let reminders = ReminderScheduler(calendar: calendar, clock: clock)
        _reminders = StateObject(wrappedValue: reminders)
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private var snapshot: QuarterSnapshot {
        QuarterSnapshot(on: CalendarDate(clock.today, calendar: .current), config: calendar.config)
    }

    var body: some Scene {
        MenuBarExtra {
            QuarterPanel(clock: clock, calendar: calendar, commandLine: commandLine, reminders: reminders)
        } label: {
            let countdown = MenuBarCountdown.countdown(
                for: menuBarTarget,
                snapshot: snapshot,
                upcoming: calendar.upcoming(on: snapshot.today)
            )
            let unit = CountdownUnit(rawValue: countdownUnit) ?? .days
            Text("\(countdown.label) · \(countdown.short(in: unit))")
                .accessibilityLabel("\(countdown.label), \(countdown.phrase(in: unit)) remaining")
        }
        .menuBarExtraStyle(.window)
    }
}
