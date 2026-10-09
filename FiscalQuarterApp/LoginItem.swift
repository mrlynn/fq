import ServiceManagement
import SwiftUI

/// Login item for the menu bar app. macOS only honors this once the app lives in a stable folder such as /Applications.
final class LoginItemController: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var message: String?

    init() {
        let status = SMAppService.mainApp.status
        enabled = status == .enabled
        message = Self.caption(for: status)
    }

    func setEnabled(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            let status = SMAppService.mainApp.status
            enabled = status == .enabled
            message = Self.caption(for: status)
        } catch {
            let status = SMAppService.mainApp.status
            enabled = status == .enabled
            message = "Move Fiscal Quarter to Applications, then try again."
        }
    }

    private static func caption(for status: SMAppService.Status) -> String? {
        if status == .requiresApproval {
            return "Allow Fiscal Quarter in System Settings, Login Items."
        }
        return nil
    }
}
