import AppKit
import SwiftUI

@main
struct FiscalQuarterApp: App {
    @StateObject private var clock: QuarterClock
    @StateObject private var calendar: CalendarModel

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
            QuarterPanel(clock: clock, calendar: calendar)
        } label: {
            Text(snapshot.menuBarLabel)
                .accessibilityLabel("\(snapshot.quarter.id), \(snapshot.daysRemaining) days remaining")
        }
        .menuBarExtraStyle(.window)
    }
}
