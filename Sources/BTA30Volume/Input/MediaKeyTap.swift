import AppKit
import Foundation
import os.log

/// Captures the keyboard volume keys (F10/F11/F12 or Touch Bar keys).
///
/// macOS emits system volume keys as NX_SYSDEFINED (14) events with
/// subtype 8. A CGEventTap intercepts and swallows them so they can be
/// routed to the BTA30. Requires Accessibility permission.
final class MediaKeyTap {
    enum Key {
        case volumeUp
        case volumeDown
        case mute
    }

    /// Called when a key is captured (on key-down only, not key-up).
    var onKey: ((Key) -> Void)?
    /// Return false to pass the event back to the system (e.g. device disconnected).
    var shouldCapture: (() -> Bool)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let logger = Logger(category: "mediakeys")

    private static let nxSysdefined: UInt32 = 14
    private static let keyVolumeUp: Int = 0    // NX_KEYTYPE_SOUND_UP
    private static let keyVolumeDown: Int = 1  // NX_KEYTYPE_SOUND_DOWN
    private static let keyMute: Int = 7        // NX_KEYTYPE_MUTE

    var isRunning: Bool { eventTap != nil }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        guard AXIsProcessTrusted() else {
            logger.info("start: AXIsProcessTrusted = false")
            return false
        }

        let mask = CGEventMask(1 << Self.nxSysdefined)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()
            return tap.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("start: CGEvent.tapCreate failed")
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.notice("Event tap installed")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type.rawValue == Self.nxSysdefined,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16

        let key: Key
        switch keyCode {
        case Self.keyVolumeUp: key = .volumeUp
        case Self.keyVolumeDown: key = .volumeDown
        case Self.keyMute: key = .mute
        default:
            return Unmanaged.passUnretained(event)
        }

        guard shouldCapture?() == true else {
            logger.info("Volume key seen but capture conditions not met; passed to system")
            return Unmanaged.passUnretained(event)
        }

        let keyFlags = data1 & 0x0000FFFF
        let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0x0A
        if isKeyDown {
            onKey?(key)
        }
        return nil // swallow both key-down and key-up
    }

    deinit {
        stop()
    }
}
