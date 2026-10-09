import Cocoa

enum MissionControl {
    /// The processes that may host the overview's accessibility tree: the Dock up to macOS 26,
    /// WindowManager on macOS 27.
    private static var hostPIDs: [pid_t] {
        ["com.apple.dock", "com.apple.WindowManager"].compactMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).first?.processIdentifier
        }
    }

    /// A host exposes one of these groups only while that overview is on screen: "mc" for Mission
    /// Control, "appexpose" for App Exposé (three-finger swipe down / ⌃↓). WindowManager names them
    /// "mc.display" / "appexpose.display". Both lay out window thumbnails the same way, so everything
    /// else treats them alike.
    private static let overviewIdentifiers = ["mc", "appexpose", "mc.display", "appexpose.display"]

    /// On macOS 27 the Dock still exposes an empty "mc" group while WindowManager holds the
    /// thumbnails, so a group only counts if it has children.
    static func root() -> AXUIElement? {
        for pid in hostPIDs {
            let host = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(host, 0.5) // polled on the main thread; don't let a hung host stall it
            if let group = host.children.first(where: {
                guard let identifier = $0.identifier, overviewIdentifiers.contains(identifier) else { return false }
                return !$0.children.isEmpty
            }) { return group }
        }
        return nil
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
