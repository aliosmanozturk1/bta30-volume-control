import AppKit
import Carbon
import Foundation

/// Actions that can be triggered by a global shortcut.
enum HotKeyAction: String, CaseIterable, Codable {
    case volumeUp
    case volumeDown
    case mute

    var title: String {
        switch self {
        case .volumeUp: return L("Increase volume")
        case .volumeDown: return L("Decrease volume")
        case .mute: return L("Mute")
        }
    }

    var carbonID: UInt32 {
        switch self {
        case .volumeUp: return 1
        case .volumeDown: return 2
        case .mute: return 3
        }
    }

    static func from(carbonID: UInt32) -> HotKeyAction? {
        allCases.first { $0.carbonID == carbonID }
    }

    var defaultSpec: HotKeySpec {
        let optionCommand = NSEvent.ModifierFlags([.option, .command]).rawValue
        switch self {
        case .volumeUp: return HotKeySpec(keyCode: UInt32(kVK_UpArrow), modifierFlags: optionCommand)
        case .volumeDown: return HotKeySpec(keyCode: UInt32(kVK_DownArrow), modifierFlags: optionCommand)
        case .mute: return HotKeySpec(keyCode: UInt32(kVK_ANSI_0), modifierFlags: optionCommand)
        }
    }

    static var defaultBindings: [HotKeyAction: HotKeySpec] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.defaultSpec) })
    }
}

/// A shortcut definition: key code + modifier keys (NSEvent.ModifierFlags).
struct HotKeySpec: Codable, Equatable {
    var keyCode: UInt32
    var modifierFlags: UInt

    var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    private static let specialNames: [UInt32: String] = [
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_Space): L("Space"), UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥", UInt32(kVK_Escape): "⎋",
        UInt32(kVK_Delete): "⌫", UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
    ]

    static func keyName(for keyCode: UInt32) -> String {
        if let name = specialNames[keyCode] { return name }
        if let character = translateKeyCode(keyCode) { return character }
        return "#\(keyCode)"
    }

    /// Translates a key code to a character using the current keyboard layout.
    private static func translateKeyCode(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let rawLayoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(rawLayoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = layoutData.withUnsafeBytes { pointer -> OSStatus in
            guard let layout = pointer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, characters.count, &length, &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
}
