import Cocoa

enum MissionControl {
    static var dockPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    }

    /// The Dock exposes one of these groups only while that overview is on screen:
    /// "mc" for Mission Control, "appexpose" for App Exposé (three-finger swipe down / ⌃↓).
    /// Both lay out window thumbnails the same way, so everything else treats them alike.
    private static let overviewIdentifiers = ["mc", "appexpose"]

    static func root() -> AXUIElement? {
        guard let pid = dockPID else { return nil }
        return AXUIElementCreateApplication(pid).children.first {
            guard let identifier = $0.identifier else { return false }
            return overviewIdentifiers.contains(identifier)
        }
    }

    /// Window thumbnails: the buttons in the overview, skipping Mission Control's Spaces bar.
    static func thumbnails(in mc: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        func walk(_ e: AXUIElement, depth: Int) {
            guard depth < 8 else { return }
            if let id = e.identifier, id.hasPrefix("mc.spaces") { return }
            if e.role == kAXButtonRole as String, let f = e.frame, f.width > 40, f.height > 40 {
                result.append(e)
                return
            }
            e.children.forEach { walk($0, depth: depth + 1) }
        }
        walk(mc, depth: 0)
        return result
    }
}
