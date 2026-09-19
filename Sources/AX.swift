import Cocoa
import ApplicationServices

extension AXUIElement {
    func value(_ name: String) -> AnyObject? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &v) == .success else { return nil }
        return v
    }

    var children: [AXUIElement] { value(kAXChildrenAttribute) as? [AXUIElement] ?? [] }
    var identifier: String? { value(kAXIdentifierAttribute) as? String }
    var role: String? { value(kAXRoleAttribute) as? String }
    var subrole: String? { value(kAXSubroleAttribute) as? String }
    var title: String? { value(kAXTitleAttribute) as? String }
    var windows: [AXUIElement] { value(kAXWindowsAttribute) as? [AXUIElement] ?? [] }

    /// Frame in AX (top-left origin) global coordinates.
    var frame: CGRect? {
        guard let p = value(kAXPositionAttribute), let s = value(kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &point)
        AXValueGetValue(s as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    func press() -> Bool { AXUIElementPerformAction(self, kAXPressAction as CFString) == .success }

    /// Presses one of a window's title bar buttons, e.g. kAXCloseButtonAttribute.
    func pressButton(_ attribute: String) -> Bool {
        guard let button = value(attribute), CFGetTypeID(button) == AXUIElementGetTypeID() else { return false }
        return (button as! AXUIElement).press()
    }

    func set(_ attribute: String, _ flag: Bool) -> Bool {
        AXUIElementSetAttributeValue(self, attribute as CFString, (flag ? kCFBooleanTrue : kCFBooleanFalse)!) == .success
    }
}

/// Lets AXUIElement be used as a dictionary key (CFEqual/CFHash semantics).
struct ElementKey: Hashable {
    let element: AXUIElement
    static func == (a: ElementKey, b: ElementKey) -> Bool { CFEqual(a.element, b.element) }
    func hash(into h: inout Hasher) { h.combine(CFHash(element)) }
}

/// Converts an AX rect (top-left origin) to Cocoa screen coordinates (bottom-left origin).
func cocoaRect(_ r: CGRect) -> CGRect {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
}
