import AppKit
import SwiftUI

/// The level indicator shown below the menu bar icon when the volume changes
/// via keyboard or scroll, styled after the system volume popup. We suppress
/// the system's own HUD, so visual feedback is our job.
struct HUDView: View {
    let volume: Int
    let maxVolume: Int
    let deviceName: String

    private var fraction: CGFloat {
        CGFloat(volume) / CGFloat(max(maxVolume, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(deviceName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(volume)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    let width = geometry.size.width
                    let knobSize: CGFloat = 15
                    let knobX = (width - knobSize) * fraction
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.primary.opacity(0.25))
                            .frame(height: 5)
                        Capsule()
                            .fill(.white)
                            .frame(width: knobX + knobSize / 2, height: 5)
                        Circle()
                            .fill(.white)
                            .frame(width: knobSize, height: knobSize)
                            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
                            .offset(x: knobX)
                    }
                    .frame(height: knobSize, alignment: .center)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 15)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(width: 280)
    }
}

final class HUDController {
    /// How long the HUD stays fully visible before fading out.
    private static let visibleDuration: TimeInterval = 1.4
    private static let fadeInDuration: TimeInterval = 0.08
    private static let fadeOutDuration: TimeInterval = 0.4
    /// Gap between the menu bar icon and the HUD.
    private static let anchorGap: CGFloat = 6
    /// Minimum distance kept to the screen edges.
    private static let screenEdgeInset: CGFloat = 8
    private static let cornerRadius: CGFloat = 18

    /// Returns the menu bar icon's screen rect; the HUD aligns below it.
    var anchorProvider: (() -> NSRect?)?
    /// Return true to skip showing the HUD (e.g. while the popover is open).
    var suppressProvider: (() -> Bool)?

    private var panel: NSPanel?
    private var hosting: NSHostingView<HUDView>?
    private var generation = 0

    func show(volume: Int, maxVolume: Int, deviceName: String) {
        if suppressProvider?() == true { return }
        if panel == nil {
            makePanel()
        }
        guard let panel, let hosting else { return }

        generation += 1
        let shownGeneration = generation

        hosting.rootView = HUDView(volume: volume, maxVolume: maxVolume, deviceName: deviceName)
        let size = hosting.fittingSize
        panel.setContentSize(size)
        position(panel, size: size)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1
        }
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleDuration) { [weak self] in
            guard let self, self.generation == shownGeneration, let panel = self.panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Self.fadeOutDuration
                panel.animator().alphaValue = 0
            }, completionHandler: {
                if self.generation == shownGeneration {
                    panel.orderOut(nil)
                }
            })
        }
    }

    private func position(_ panel: NSPanel, size: NSSize) {
        if let anchor = anchorProvider?() {
            let screen = NSScreen.screens.first {
                $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY))
            } ?? NSScreen.main
            var x = anchor.midX - size.width / 2
            if let visible = screen?.visibleFrame {
                x = min(max(x, visible.minX + Self.screenEdgeInset), visible.maxX - size.width - Self.screenEdgeInset)
            }
            panel.setFrameOrigin(NSPoint(x: x, y: anchor.minY - size.height - Self.anchorGap))
            return
        }
        // No anchor: fall back to the top-right of the screen
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.maxX - size.width - 20,
                y: frame.maxY - size.height - 12
            ))
        }
    }

    private func makePanel() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = Self.cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: HUDView(volume: 0, maxVolume: BTA30Manager.maxVolume, deviceName: ""))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
        ])

        panel.contentView = effect
        self.panel = panel
        self.hosting = hosting
    }
}
