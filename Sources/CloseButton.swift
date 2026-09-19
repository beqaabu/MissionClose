import Cocoa

final class CloseButtonView: NSView {
    /// True while the pointer is over the button itself (set by the controller; the view never gets real mouse events).
    var hovering = false { didSet { if hovering != oldValue { needsDisplay = true } } }
    /// Option is held: a click quits the app, so show a power symbol instead of the ✕.
    var quitMode = false { didSet { if quitMode != oldValue { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        (hovering ? NSColor(red: 1.0, green: 0.37, blue: 0.34, alpha: 1) : NSColor(white: 0.12, alpha: 0.72)).setFill()
        circle.fill()
        NSColor.white.withAlphaComponent(hovering ? 0 : 0.25).setStroke()
        circle.lineWidth = 0.5
        circle.stroke()

        let glyph = quitMode ? powerGlyph() : crossGlyph()
        glyph.lineWidth = 1.5
        glyph.lineCapStyle = .round
        (hovering ? NSColor(red: 0.45, green: 0.05, blue: 0.03, alpha: 1) : NSColor.white.withAlphaComponent(0.85)).setStroke()
        glyph.stroke()
    }

    private func crossGlyph() -> NSBezierPath {
        let inset = bounds.width * 0.35
        let path = NSBezierPath()
        path.move(to: NSPoint(x: inset, y: inset))
        path.line(to: NSPoint(x: bounds.width - inset, y: bounds.height - inset))
        path.move(to: NSPoint(x: inset, y: bounds.height - inset))
        path.line(to: NSPoint(x: bounds.width - inset, y: inset))
        return path
    }

    /// ⏻: an open ring with a stroke through the gap at the top.
    private func powerGlyph() -> NSBezierPath {
        let center = NSPoint(x: bounds.midX, y: bounds.midY - bounds.height * 0.02)
        let radius = bounds.width * 0.2
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: 125, endAngle: 55, clockwise: false)
        path.move(to: center)
        path.line(to: NSPoint(x: center.x, y: center.y + radius * 1.25))
        return path
    }
}

final class CloseButtonPanel: NSPanel {
    static let size: CGFloat = 20
    let view = CloseButtonView(frame: NSRect(x: 0, y: 0, width: size, height: size))
    /// Button rect in AX / CGEvent coordinates (top-left origin), used for hit testing.
    private(set) var axFrame = CGRect.zero

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        ignoresMouseEvents = true // clicks are handled by the event tap
        // Above Mission Control, and .stationary so Mission Control doesn't shuffle it like a normal window.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Sits on the thumbnail's top-left corner, where the traffic lights would be.
    func place(on thumbAXFrame: CGRect) {
        let s = Self.size
        axFrame = CGRect(x: thumbAXFrame.minX - s / 3, y: thumbAXFrame.minY - s / 3, width: s, height: s)
        setFrame(cocoaRect(axFrame), display: false)
    }
}
