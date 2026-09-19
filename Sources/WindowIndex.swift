import Cocoa

struct WindowRef {
    let app: NSRunningApplication
    let window: AXUIElement
    let title: String
    let size: CGSize
}

enum WindowIndex {
    static func all() -> [WindowRef] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .flatMap { app -> [WindowRef] in
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(axApp, 0.5) // don't let one hung app stall everything
                return axApp.windows.compactMap { w in
                    guard w.subrole == kAXStandardWindowSubrole as String,
                          (w.value(kAXMinimizedAttribute) as? Bool) != true,
                          let f = w.frame else { return nil }
                    return WindowRef(app: app, window: w, title: w.title ?? "", size: f.size)
                }
            }
    }

    /// Mission Control labels thumbnails with the window title (or the app name when a
    /// window is untitled). Among equal names, the closest aspect ratio wins.
    /// Titles can change while Mission Control is open (e.g. a terminal spinner), so if the
    /// cached titles don't match, re-read the live ones before falling back to the app name.
    static func match(_ thumb: AXUIElement, in windows: [WindowRef]) -> WindowRef? {
        guard let label = thumb.title, let thumbFrame = thumb.frame else { return nil }
        var candidates = windows.filter { !label.isEmpty && $0.title == label }
        if candidates.isEmpty { candidates = windows.filter { !label.isEmpty && $0.window.title == label } }
        if candidates.isEmpty { candidates = windows.filter { $0.app.localizedName == label } }
        if candidates.isEmpty { candidates = windows.filter { !$0.title.isEmpty && label.contains($0.title) } }
        let ratio = thumbFrame.width / max(thumbFrame.height, 1)
        return candidates.min {
            abs($0.size.width / max($0.size.height, 1) - ratio) < abs($1.size.width / max($1.size.height, 1) - ratio)
        }
    }
}
