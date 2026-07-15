import AppKit
import Combine
import SwiftUI

/// The menu bar item: button state, click/scroll interactions, the right-click
/// menu and popover presentation. Icon rendering lives in `StatusItemIcon`.
final class StatusItemController: NSObject {
    /// One volume step per this much accumulated scroll delta.
    private static let scrollStepThreshold: CGFloat = 5
    /// Tolerance before force-correcting a drifted popover position.
    private static let popoverPositionTolerance: CGFloat = 2

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let icon = StatusItemIcon()
    private var cancellables = Set<AnyCancellable>()
    private var scrollMonitor: Any?
    private var scrollAccumulator: CGFloat = 0

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        popover.contentViewController = NSHostingController(rootView: ContentView(model: model))
        popover.behavior = .transient
        popover.animates = false

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }

        // The HUD anchors below the menu bar icon
        model.hud.anchorProvider = { [weak self] in
            guard let self, let button = self.statusItem.button, let window = button.window else { return nil }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        // The slider is already visible while the popover is open; no HUD needed
        model.hud.suppressProvider = { [weak self] in
            self?.popover.isShown == true
        }

        model.bta.$state
            .combineLatest(model.bta.$volume)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, volume in
                self?.updateButton(state: state, volume: volume)
            }
            .store(in: &cancellables)

        installScrollMonitor()
    }

    deinit {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
        }
    }

    // MARK: - Button appearance

    private func updateButton(state: BTA30Manager.ConnectionState, volume: Int) {
        guard let button = statusItem.button else { return }
        switch state {
        case .connected:
            button.image = icon.fixedWidthImage(for: StatusItemIcon.symbol(for: volume))
            // Pad to 2 digits with U+2007 (figure space) so the width stays constant
            button.title = volume < 10 ? "\u{2007}\(volume)" : "\(volume)"
            button.appearsDisabled = false
        default:
            button.image = icon.fixedWidthImage(for: "speaker.slash")
            button.title = ""
            button.appearsDisabled = true
        }
    }

    // MARK: - Scroll-to-adjust volume

    private func installScrollMonitor() {
        // Scrolling over the menu bar icon adjusts the volume (±1 per notch)
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.model.scrollAdjustsVolume,
                  let button = self.statusItem.button,
                  event.window === button.window else { return event }
            var delta = event.scrollingDeltaY
            if event.isDirectionInvertedFromDevice { delta = -delta }
            self.scrollAccumulator += delta
            var steps = 0
            while self.scrollAccumulator >= Self.scrollStepThreshold {
                steps += 1
                self.scrollAccumulator -= Self.scrollStepThreshold
            }
            while self.scrollAccumulator <= -Self.scrollStepThreshold {
                steps -= 1
                self.scrollAccumulator += Self.scrollStepThreshold
            }
            if steps != 0 {
                self.model.userAdjustVolume(steps)
            }
            return event
        }
    }

    // MARK: - Clicks and menu

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let connected = model.bta.isConnected
        let menu = NSMenu()
        menu.autoenablesItems = false

        let muteTitle = model.bta.volume == 0 ? L("Unmute") : L("Mute")
        let muteItem = NSMenuItem(title: muteTitle, action: #selector(menuMute), keyEquivalent: "")
        muteItem.target = self
        muteItem.isEnabled = connected
        menu.addItem(muteItem)
        menu.addItem(.separator())

        if !model.presetStore.presets.isEmpty {
            for preset in model.presetStore.presets {
                let item = NSMenuItem(title: preset.name, action: #selector(menuApplyPreset(_:)), keyEquivalent: "")
                item.target = self
                item.isEnabled = connected
                item.representedObject = preset.id.uuidString
                item.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: nil)
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }
        let powerItem = NSMenuItem(title: L("Power Off Device"), action: #selector(menuPowerOff), keyEquivalent: "")
        powerItem.target = self
        powerItem.isEnabled = connected
        menu.addItem(powerItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L("Quit"), action: #selector(menuQuit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 6), in: button)
        }
    }

    @objc private func menuMute() { model.userToggleMute() }
    @objc private func menuApplyPreset(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let preset = model.presetStore.find(id: id) else { return }
        model.apply(preset)
    }
    @objc private func menuPowerOff() { model.bta.powerOff() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: - Popover

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.audio.refreshFormat()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            // macOS sometimes anchors the popover incorrectly (fullscreen /
            // auto-hidden menu bar); verify the position and fix if it drifted
            fixPopoverPositionIfNeeded()
            DispatchQueue.main.async { [weak self] in
                self?.fixPopoverPositionIfNeeded()
            }
        }
    }

    private func fixPopoverPositionIfNeeded() {
        guard popover.isShown,
              let button = statusItem.button,
              let buttonWindow = button.window,
              let popoverWindow = popover.contentViewController?.view.window else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var frame = popoverWindow.frame
        let expectedX = anchor.midX - frame.width / 2
        if abs(frame.maxY - anchor.minY) > Self.popoverPositionTolerance
            || abs(frame.origin.x - expectedX) > Self.popoverPositionTolerance {
            frame.origin = NSPoint(x: expectedX, y: anchor.minY - frame.height)
            popoverWindow.setFrame(frame, display: true)
        }
    }
}
