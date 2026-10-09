import Combine
import Foundation

/// Publishes the current instant so the menu bar can follow the local date past midnight.
final class QuarterClock: ObservableObject {
    @Published private(set) var today: Date
    private var timer: Timer?

    init() {
        today = Date()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.today = Date()
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        today = Date()
    }

    deinit {
        timer?.invalidate()
    }
}
