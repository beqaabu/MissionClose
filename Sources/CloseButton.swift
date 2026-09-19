import Cocoa

final class CloseButtonView: NSView {
    /// True while the pointer is over the button itself (set by the controller; the view never gets real mouse events).
    var hovering = false { didSet { if hovering != oldValue { needsDisplay = true } } }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        (hovering ? NSColor(red: 1.0, green: 0.37, blue: 0.34, alpha: 1) : NSColor(white: 0.12, alpha: 0.72)).setFill()
        circle.fill()
        NSColor.white.withAlphaComponent(hovering ? 0 : 0.25).setStroke()
        circle.lineWidth = 0.5
        circle.stroke()

        let inset = bounds.width * 0.35
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: inset, y: inset))
        cross.line(to: NSPoint(x: bounds.width - inset, y: bounds.height - inset))
        cross.move(to: NSPoint(x: inset, y: bounds.height - inset))
        cross.line(to: NSPoint(x: bounds.width - inset, y: inset))
        cross.lineWidth = 1.5
        cross.lineCapStyle = .round
        (hovering ? NSColor(red: 0.45, green: 0.05, blue: 0.03, alpha: 1) : NSColor.white.withAlphaComponent(0.85)).setStroke()
        cross.stroke()
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
