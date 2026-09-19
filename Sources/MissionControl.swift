import Cocoa

enum MissionControl {
    static var dockPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    }

    /// The Dock exposes an "mc" group only while Mission Control is on screen.
    static func root() -> AXUIElement? {
        guard let pid = dockPID else { return nil }
        return AXUIElementCreateApplication(pid).children.first { $0.identifier == "mc" }
    }

    /// Window thumbnails: buttons under "mc", skipping the Spaces bar at the top.
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
