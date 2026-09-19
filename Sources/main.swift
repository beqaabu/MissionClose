import Cocoa
import ApplicationServices

// MissionClose: shows a close button on window thumbnails while Mission Control is open.
//   click         -> close that window (same as its red traffic-light button)
//   option+click  -> quit the whole app

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = Controller()
    private var statusItem: NSStatusItem!
    private let permissionItem = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "xmark.rectangle", accessibilityDescription: "MissionClose")

        let menu = NSMenu()
        menu.delegate = self
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Click ✕ in Mission Control to close a window", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Option-click ✕ to quit the app", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MissionClose", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        controller.start()
    }

    func menuWillOpen(_ menu: NSMenu) {
        permissionItem.title = AXIsProcessTrusted()
            ? "Accessibility: granted"
            : "Accessibility: NOT granted (click to open Settings)"
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
