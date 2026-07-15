import Foundation
import ServiceManagement
import os.log

/// Manages the "Launch at login" setting via SMAppService.
final class LoginItemManager: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled, !isReverting else { return }
            apply()
        }
    }
    @Published var hint: String?

    private var isReverting = false
    private let logger = Logger(category: "loginitem")

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func apply() {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            hint = nil
        } catch {
            logger.error("Login item error: \(error.localizedDescription, privacy: .public)")
            hint = L("Could not set login item: \(error.localizedDescription)")
            isReverting = true
            isEnabled = SMAppService.mainApp.status == .enabled
            isReverting = false
        }
    }
}
