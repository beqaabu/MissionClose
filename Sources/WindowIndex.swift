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

    /// Finds the window a Mission Control thumbnail stands for. The rules live in WindowMatching
    /// so they can be tested without a live Mission Control.
    static func match(_ thumb: AXUIElement, in windows: [WindowRef]) -> WindowRef? {
        guard let label = thumb.title, let thumbFrame = thumb.frame else { return nil }
        let candidates = windows.map {
            WindowCandidate(title: $0.title, liveTitle: $0.window.title ?? $0.title,
                            appName: $0.app.localizedName ?? "", size: $0.size)
        }
        let aspect = thumbFrame.width / max(thumbFrame.height, 1)
        guard let index = WindowMatching.bestMatch(label: label, thumbnailAspect: aspect, in: candidates) else { return nil }
        return windows[index]
    }
}
