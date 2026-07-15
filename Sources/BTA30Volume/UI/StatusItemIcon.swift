import AppKit

/// Menu bar speaker icons: symbol choice by level and fixed-width rendering.
final class StatusItemIcon {
    /// SF Symbol name matching the volume level (muted/low/medium/high).
    static func symbol(for volume: Int) -> String {
        switch volume {
        case 0: return "speaker.slash.fill"
        case 1...20: return "speaker.wave.1.fill"
        case 21...40: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    private var cache: [String: NSImage] = [:]

    /// Speaker symbols with different wave counts have different widths; to
    /// keep the menu bar item from shifting, the symbol is drawn onto a
    /// fixed-width canvas with the speaker body left-aligned.
    func fixedWidthImage(for symbol: String) -> NSImage {
        if let cached = cache[symbol] { return cached }
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: L("BTA30 volume"))?
            .withSymbolConfiguration(configuration) else { return NSImage() }
        let canvas = NSSize(width: 26, height: 17)
        let baseSize = base.size
        let image = NSImage(size: canvas, flipped: false) { rect in
            base.draw(
                at: NSPoint(x: 0, y: (rect.height - baseSize.height) / 2),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
        image.isTemplate = true
        cache[symbol] = image
        return image
    }
}
