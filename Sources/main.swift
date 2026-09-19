import Cocoa
import ApplicationServices
import ServiceManagement

// MissionClose: shows a close button on window thumbnails while Mission Control is open.
//   click         -> close that window (same as its red traffic-light button)
//   option+click  -> quit the whole app

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = Controller()
    private var statusItem: NSStatusItem!
    private let permissionItem = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private var cornerItems: [NSMenuItem] = []
    private var sizeItems: [NSMenuItem] = []
    private var showItems: [NSMenuItem] = []
    private let confirmQuitItem = NSMenuItem(title: "Confirm Before Quitting Apps", action: #selector(toggleConfirmQuit), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()

        let menu = NSMenu()
        menu.delegate = self
        permissionItem.target = self
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hover a thumbnail in Mission Control to close, minimize or full-screen it", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Option-click ✕ to quit the app", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Or press ⌘W / ⌘Q / ⌘M while hovering", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        cornerItems = Settings.Corner.allCases.map { item($0.title, #selector(setCorner(_:)), $0.rawValue) }
        sizeItems = Settings.ButtonSize.allCases.map { item($0.title, #selector(setButtonSize(_:)), $0.rawValue) }
        showItems = [item("On Hover", #selector(setAlwaysShow(_:)), false), item("Always", #selector(setAlwaysShow(_:)), true)]
        menu.addItem(submenu("Button Corner", cornerItems))
        menu.addItem(submenu("Button Size", sizeItems))
        menu.addItem(submenu("Show Buttons", showItems))
        confirmQuitItem.target = self
        menu.addItem(confirmQuitItem)
        menu.addItem(.separator())
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(withTitle: "Quit MissionClose", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        // Turn launch-at-login on the first time the app runs; the menu toggle controls it after that.
        if !UserDefaults.standard.bool(forKey: "didSetUpLoginItem") {
            UserDefaults.standard.set(true, forKey: "didSetUpLoginItem")
            try? SMAppService.mainApp.register()
        }

        controller.start()
    }

    func menuWillOpen(_ menu: NSMenu) {
        permissionItem.title = AXIsProcessTrusted()
            ? "Accessibility: granted"
            : "Accessibility: NOT granted (click to open Settings)"
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        cornerItems.forEach { $0.state = $0.representedObject as? String == Settings.corner.rawValue ? .on : .off }
        sizeItems.forEach { $0.state = $0.representedObject as? Int == Settings.buttonSize.rawValue ? .on : .off }
        showItems.forEach { $0.state = $0.representedObject as? Bool == Settings.alwaysShow ? .on : .off }
        confirmQuitItem.state = Settings.confirmQuit ? .on : .off
    }

    private func item(_ title: String, _ action: Selector, _ value: Any) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = value
        return item
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        items.forEach(menu.addItem)
        item.submenu = menu
        return item
    }

    @objc private func setCorner(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let corner = Settings.Corner(rawValue: raw) { Settings.corner = corner }
    }

    @objc private func setButtonSize(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? Int, let size = Settings.ButtonSize(rawValue: raw) { Settings.buttonSize = size }
    }

    @objc private func setAlwaysShow(_ sender: NSMenuItem) {
        if let always = sender.representedObject as? Bool { Settings.alwaysShow = always }
    }

    @objc private func toggleConfirmQuit() {
        Settings.confirmQuit.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
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
