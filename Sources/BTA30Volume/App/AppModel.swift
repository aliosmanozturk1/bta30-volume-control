import AppKit
import Foundation
import os.log

/// Composition root: creates the subsystems, wires them together and executes
/// user actions that span more than one subsystem.
final class AppModel: ObservableObject {
    let bta = BTA30Manager()
    let audio = AudioOutputWatcher()
    let keyboard = KeyboardCoordinator()
    let presetStore = PresetStore()
    let loginItem = LoginItemManager()
    let hud = HUDController()

    /// Scroll-to-adjust volume on the menu bar icon. Off by default because
    /// accidentally maxing the volume is too easy.
    @Published var scrollAdjustsVolume: Bool {
        didSet { UserDefaults.standard.set(scrollAdjustsVolume, forKey: Preferences.scrollEnabled) }
    }

    private let logger = Logger(category: "app")

    init() {
        scrollAdjustsVolume = UserDefaults.standard.bool(forKey: Preferences.scrollEnabled)
        // Capture keys only while FiiO is both connected and macOS's active
        // audio output; otherwise let system volume work as usual
        keyboard.shouldCaptureMediaKeys = { [weak self] in
            guard let self else { return false }
            return self.bta.isConnected && self.audio.isFiiODefaultOutput
        }
        keyboard.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .volumeUp: self.userAdjustVolume(self.keyboard.keyStep)
            case .volumeDown: self.userAdjustVolume(-self.keyboard.keyStep)
            case .mute: self.userToggleMute()
            }
        }
    }

    // MARK: - User-initiated volume changes (show the HUD)

    func userAdjustVolume(_ delta: Int) {
        guard bta.isConnected else { return }
        bta.stepVolume(delta)
        showHUD()
    }

    func userToggleMute() {
        guard bta.isConnected else { return }
        bta.toggleMute()
        showHUD()
    }

    private func showHUD() {
        hud.show(volume: bta.volume, maxVolume: bta.volumeLimit, deviceName: bta.deviceName)
    }

    // MARK: - Presets

    /// Saves the current device settings under the given name; overwrites on name match.
    func saveCurrentAsPreset(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, bta.isConnected else { return }
        presetStore.saveOrUpdate(Preset(
            name: name,
            volume: bta.volume,
            filter: bta.filter,
            ledOff: bta.ledOff,
            balance: bta.balance,
            upsampling: bta.upsampling
        ))
    }

    func apply(_ preset: Preset) {
        guard bta.isConnected else { return }
        bta.setVolume(preset.volume)
        bta.setFilter(preset.filter)
        bta.setLedOff(preset.ledOff)
        bta.setBalance(preset.balance)
        bta.setUpsampling(preset.upsampling)
        showHUD()
    }
}
