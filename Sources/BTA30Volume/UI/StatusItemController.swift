import AppKit
import Combine
import SwiftUI

/// The menu bar item: button state, click/scroll interactions, the right-click
/// menu and popover presentation. Icon rendering lives in `StatusItemIcon`.
final class StatusItemController: NSObject {
    /// Tolerance before force-correcting a drifted popover position.
    private static let popoverPositionTolerance: CGFloat = 2

    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let icon = StatusItemIcon()
    private var cancellables = Set<AnyCancellable>()

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


    // MARK: - Clicks and menu

    @objc private func statusItemClicked() {
            togglePopover()
    }


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
