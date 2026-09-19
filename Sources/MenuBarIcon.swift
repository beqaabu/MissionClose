import Cocoa

/// Menu bar icon: a Mission Control spread of three windows with a close badge on the top one.
/// Drawn as a template image so macOS tints it for light, dark and colored menu bars.
enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            tile(NSRect(x: 4.5, y: 9, width: 12, height: 6))
            tile(NSRect(x: 1.5, y: 1.5, width: 7, height: 5.5))
            tile(NSRect(x: 9.5, y: 1.5, width: 7, height: 5.5))
            badge(center: NSPoint(x: 4.2, y: 15.2), radius: 2.8)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MissionClose"
        return image
    }

    private static func tile(_ rect: NSRect) {
        NSBezierPath(roundedRect: rect, xRadius: 1.6, yRadius: 1.6).fill()
    }

    /// A solid disc with a knocked-out ✕, separated from the window under it by a transparent ring.
    private static func badge(center c: NSPoint, radius r: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let gap: CGFloat = 1.2
        ctx.setBlendMode(.clear)
        NSBezierPath(ovalIn: NSRect(x: c.x - r - gap, y: c.y - r - gap, width: 2 * (r + gap), height: 2 * (r + gap))).fill()
        ctx.setBlendMode(.normal)
        NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)).fill()

        let d = r * 0.42
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: c.x - d, y: c.y - d))
        cross.line(to: NSPoint(x: c.x + d, y: c.y + d))
        cross.move(to: NSPoint(x: c.x - d, y: c.y + d))
        cross.line(to: NSPoint(x: c.x + d, y: c.y - d))
        cross.lineWidth = 1.3
        cross.lineCapStyle = .round
        ctx.setBlendMode(.clear)
        cross.stroke()
        ctx.setBlendMode(.normal)
    }
}
