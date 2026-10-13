import Combine
import Foundation
import UserNotifications

/// Turns the reminder plan into local notifications, and keeps them current.
///
/// It plans `ReminderPlan.horizon` days ahead and plans again whenever the milestones, the
/// calendar, the reminder settings, or the date change. Each pass clears this app's pending
/// notifications and schedules the plan afresh, so a changed rule never leaves a stale one behind.
@MainActor
final class ReminderScheduler: NSObject, ObservableObject {
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let calendar: CalendarModel
    private let center = UNUserNotificationCenter.current()
    private var watching: AnyCancellable?
    /// The pass in progress. Each new one waits for it, so two never interleave.
    private var running: Task<Void, Never>?

    init(calendar: CalendarModel, clock: QuarterClock) {
        self.calendar = calendar
        super.init()
        center.delegate = self
        let today = clock.$today
            .map { CalendarDate($0, calendar: .current) }
            .removeDuplicates()
        let rules = Publishers.CombineLatest(calendar.$config, calendar.$workweek)
        watching = Publishers.CombineLatest4(calendar.$reminders, calendar.$milestones, rules, today)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                self?.rescheduleSoon()
            }
    }

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    private func rescheduleSoon() {
        let previous = running
        running = Task {
            await previous?.value
            await reschedule()
        }
    }

    private func reschedule() async {
        await refreshAuthorization()
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlan.idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let settings = calendar.reminders
        guard settings.anyOn else { return }
        // The first pass with a reminder on asks macOS once. After that the answer stands.
        if authorization == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorization()
        }
        guard authorization == .authorized || authorization == .provisional else { return }

        let now = Date()
        let plan = ReminderPlan.plan(
            settings: settings,
            milestones: calendar.milestones,
            calendar: calendar.config.definition,
            today: CalendarDate(now, calendar: .current),
            workweek: calendar.workweek
        )
        for reminder in plan {
            var when = DateComponents()
            when.year = reminder.date.year
            when.month = reminder.date.month
            when.day = reminder.date.day
            when.hour = settings.hour
            when.minute = settings.minute
            // Today's reminder after its time has passed would never fire, so it is left out.
            guard let fire = Calendar.current.date(from: when), fire > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}

extension ReminderScheduler: UNUserNotificationCenterDelegate {
    /// Shows a reminder even while the panel is open, when the app counts as in front.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
