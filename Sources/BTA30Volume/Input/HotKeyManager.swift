import AppKit
import Carbon
import Foundation

/// Manages the Carbon registration of global keyboard shortcuts.
///
/// Uses RegisterEventHotKey — unlike media keys this needs no Accessibility
/// permission and works regardless of which app is frontmost. Shortcut
/// definitions live in `HotKeySpec`; deciding which combinations to register
/// is the caller's responsibility.
final class HotKeyManager {
    var onAction: ((HotKeyAction) -> Void)?

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?
    private static let signature: OSType = 0x4254_4133 // 'BTA3'

    func start(bindings: [HotKeyAction: HotKeySpec]) {
        stop()
        installHandler()
        for (action, spec) in bindings {
            register(spec: spec, action: action)
        }
    }

    func stop() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        handlerRef = nil
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard hotKeyID.signature == HotKeyManager.signature,
                  let action = HotKeyAction.from(carbonID: hotKeyID.id) else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onAction?(action)
            return noErr
        }
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    private func register(spec: HotKeySpec, action: HotKeyAction) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: action.carbonID)
        RegisterEventHotKey(
            spec.keyCode,
            Self.carbonModifiers(from: NSEvent.ModifierFlags(rawValue: spec.modifierFlags)),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        if let ref {
            hotKeyRefs.append(ref)
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    deinit {
        stop()
    }
}
