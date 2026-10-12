import AppKit
import SwiftUI

@main
struct FiscalQuarterApp: App {
    @StateObject private var clock: QuarterClock
    @StateObject private var calendar: CalendarModel
    /// Created at launch so `fq` is linked before the panel is ever opened.
    @StateObject private var commandLine = CommandLineToolController()
    @AppStorage(MenuBarCountdown.targetKey) private var menuBarTarget = CountdownTarget.quarter.rawValue
    @AppStorage(MenuBarCountdown.unitKey) private var countdownUnit = CountdownUnit.days.rawValue

    init() {
        _clock = StateObject(wrappedValue: QuarterClock())
        _calendar = StateObject(wrappedValue: CalendarModel())
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    private var snapshot: QuarterSnapshot {
        QuarterSnapshot(on: CalendarDate(clock.today, calendar: .current), config: calendar.config)
    }

    var body: some Scene {
        MenuBarExtra {
            QuarterPanel(clock: clock, calendar: calendar, commandLine: commandLine)
        } label: {
            let countdown = snapshot.countdown(to: CountdownTarget(rawValue: menuBarTarget) ?? .quarter)
            let unit = CountdownUnit(rawValue: countdownUnit) ?? .days
            Text("\(countdown.label) · \(countdown.short(in: unit))")
                .accessibilityLabel("\(countdown.label), \(countdown.phrase(in: unit)) remaining")
        }
        .menuBarExtraStyle(.window)
    }
}
