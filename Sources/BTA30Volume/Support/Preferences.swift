import Foundation

/// The single list of UserDefaults keys.
///
/// Key names must not change: they must stay compatible with settings saved
/// by released versions.
enum Preferences {
    static let mediaKeysEnabled = "bta30.mediaKeys.enabled"
    static let keyStep = "bta30.mediaKeys.step"
    static let hotKeysEnabled = "bta30.hotKeys.enabled"
    static let hotKeyBindings = "bta30.hotKeys.bindings"
    static let presets = "bta30.presets"
    static let volumeLimit = "bta30.volume.limit"
    static let scrollEnabled = "bta30.scroll.enabled"
    static let peripheralIdentifier = "bta30.peripheral.identifier"
}
