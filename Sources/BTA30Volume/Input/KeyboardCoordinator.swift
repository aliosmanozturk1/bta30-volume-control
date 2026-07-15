import AppKit
import Foundation
import os.log

/// Coordinates all keyboard input: media key capture (including the
/// Accessibility permission flow), global shortcuts and shortcut recording.
///
/// Exposes two connection points: `shouldCaptureMediaKeys` (when media keys
/// get swallowed) and `onAction` (the triggered action).
final class KeyboardCoordinator: ObservableObject {
    /// Decides whether media keys get captured (e.g. is FiiO the active output).
    var shouldCaptureMediaKeys: (() -> Bool)?
    /// Action triggered by a media key or global shortcut.
    var onAction: ((HotKeyAction) -> Void)?

    /// Holds the user's wish; stays on even without permission, and key
    /// capture starts automatically the moment permission is granted.
    @Published var mediaKeysEnabled: Bool {
        didSet {
            guard oldValue != mediaKeysEnabled else { return }
            defaults.set(mediaKeysEnabled, forKey: Preferences.mediaKeysEnabled)
            applyMediaKeySetting()
        }
    }
    @Published var keyStep: Int {
        didSet { defaults.set(keyStep, forKey: Preferences.keyStep) }
    }
    /// The action whose shortcut is being recorded (nil = not recording)
    @Published var permissionHint: String?

    /// Valid media key step sizes.
    private static let keyStepRange = 1...3
    /// Polling cadence while waiting for the Accessibility grant.
    private static let trustPollInterval: TimeInterval = 1.5

    private let mediaKeyTap = MediaKeyTap()
    private let defaults: UserDefaults
    private let logger = Logger(category: "keyboard")

    private var trustPollTimer: Timer?
    private var didPromptForAccessibility = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mediaKeysEnabled = defaults.bool(forKey: Preferences.mediaKeysEnabled)
        let savedStep = defaults.integer(forKey: Preferences.keyStep)
        keyStep = Self.keyStepRange.contains(savedStep) ? savedStep : 2

        mediaKeyTap.shouldCapture = { [weak self] in
            self?.shouldCaptureMediaKeys?() == true
        }
        mediaKeyTap.onKey = { [weak self] key in
            guard let self else { return }
            switch key {
            case .volumeUp: self.onAction?(.volumeUp)
            case .volumeDown: self.onAction?(.volumeDown)
            case .mute: self.onAction?(.mute)
            }
        }

        if mediaKeysEnabled {
            applyMediaKeySetting()
        }
    }






    // MARK: - Media keys

    private func applyMediaKeySetting() {
        trustPollTimer?.invalidate()
        trustPollTimer = nil

        guard mediaKeysEnabled else {
            mediaKeyTap.stop()
            permissionHint = nil
            return
        }

        if mediaKeyTap.start() {
            logger.notice("Media key capture enabled")
            permissionHint = nil
            return
        }

        if AXIsProcessTrusted() {
            // Permission exists but the tap failed — usually fixed by an app restart
            logger.error("Accessibility permission present but event tap could not be created")
            permissionHint = L("Permission appears granted but key capture could not start. Quit and reopen the app.")
            return
        }

        logger.notice("No Accessibility permission; waiting for grant")
        if !didPromptForAccessibility {
            didPromptForAccessibility = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
        permissionHint = L("Allow \"BTA30 Volume\" in System Settings → Privacy & Security → Accessibility. Keys will activate automatically once permission is granted.")

        // Poll for the permission; start the tap the moment it is granted
        trustPollTimer = Timer.scheduledTimer(withTimeInterval: Self.trustPollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.mediaKeysEnabled else {
                self.trustPollTimer?.invalidate()
                self.trustPollTimer = nil
                return
            }
            if self.mediaKeyTap.start() {
                self.logger.notice("Permission detected, media key capture enabled")
                self.permissionHint = nil
                self.trustPollTimer?.invalidate()
                self.trustPollTimer = nil
            }
        }
    }
}
