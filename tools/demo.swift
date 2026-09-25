import Cocoa

// Drives a scripted MissionClose demo for screen recordings.
//
// It opens its own throwaway windows (TextEdit documents and Preview images), arranges them,
// opens Mission Control, then moves the pointer and clicks the buttons on a fixed timeline.
// Only windows whose title starts with DEMO_PREFIX are ever touched.
//
// Needs Accessibility access. It ships as an app bundle launched with `open` on purpose:
// a command-line tool started from a terminal inherits the terminal's Accessibility grant
// instead of having its own, so granting the binary itself has no effect.

let DEMO_PREFIX = DEMO_WINDOW_PREFIX
let arguments = CommandLine.arguments

// MARK: - Input

func wait(_ seconds: TimeInterval) {
    let until = Date().addingTimeInterval(seconds)
    while Date() < until { RunLoop.current.run(mode: .default, before: until) }
}

func step(_ message: String) {
    print("· \(message)")
}

// MARK: - On-screen prompt

/// A panel that floats above everything (including Mission Control) to count down before the demo.
final class HUD {
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 92),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true

        let box = NSView(frame: panel.contentLayoutRect)
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.92).cgColor
        box.layer?.cornerRadius = 18
        label.frame = box.bounds.insetBy(dx: 24, dy: 24)
        label.alignment = .center
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.textColor = .white
        box.addSubview(label)
        panel.contentView = box

        if let screen = NSScreen.main?.frame {
            panel.setFrameOrigin(NSPoint(x: screen.midX - 310, y: screen.maxY - 220))
        }
    }

    func show(_ text: String) {
        label.stringValue = text
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil) }
}

// MARK: - Demo windows
//
// The driver draws its own windows by launching extra copies of itself ("helpers"), instead of
// opening documents in TextEdit or Preview. Those apps put new windows wherever they already have
// windows, which can be another desktop entirely, and their content isn't ours to show.

/// Launches one helper process per spec (a separate copy of this app, so quitting one is a real quit).
func openDemoWindows() {
    for spec in helperSpecs {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-n", Bundle.main.bundleURL.path, "--args", "--helper", spec.argument]
        try? open.run()
        open.waitUntilExit()
        wait(0.8)
    }
    wait(1.2)
}

func helperApps() -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
}

/// Spreads the demo windows out so Mission Control has something interesting to lay out.
func arrangeDemoWindows() {
    guard let screen = NSScreen.main?.frame else { return }
    let frames: [CGRect] = [
        CGRect(x: 0.04, y: 0.10, width: 0.42, height: 0.46),
        CGRect(x: 0.52, y: 0.07, width: 0.40, height: 0.44),
        CGRect(x: 0.26, y: 0.34, width: 0.40, height: 0.44),
        CGRect(x: 0.58, y: 0.42, width: 0.38, height: 0.42),
    ]
    var index = 0
    for app in helperApps() {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        for window in axApp.windows where index < frames.count {
            let f = frames[index]
            index += 1
            var point = CGPoint(x: screen.width * f.minX, y: 60 + screen.height * f.minY)
            var size = CGSize(width: screen.width * f.width, height: screen.height * f.height)
            if let p = AXValueCreate(.cgPoint, &point) { AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, p) }
            if let s = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s) }
        }
    }
}

func closeDemoWindows() {
    for app in helperApps() { app.terminate() }
    wait(0.6)
    for app in helperApps() where !app.isTerminated { app.forceTerminate() }
}

// MARK: - Mission Control

func toggleMissionControl() {
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
}

/// Waits until the thumbnails stop moving, then returns the demo ones, left to right.
func settledThumbnails(timeout: TimeInterval = 4) -> [(element: AXUIElement, frame: CGRect, title: String)] {
    var previous: [CGRect] = []
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        wait(0.1)
        guard let mc = MissionControl.root() else { continue }
        let thumbs = MissionControl.thumbnails(in: mc).compactMap { element -> (AXUIElement, CGRect, String)? in
            guard let frame = element.frame, let title = element.title else { return nil }
            return (element, frame, title)
        }
        let frames = thumbs.map(\.1)
        if !frames.isEmpty && frames == previous {
            return thumbs.filter { $0.2.hasPrefix(DEMO_PREFIX) }
                .sorted { $0.1.minX < $1.1.minX }
                .map { (element: $0.0, frame: $0.1, title: $0.2) }
        }
        previous = frames
    }
    return []
}

// MARK: - Pointer

var cursor = CGPoint(x: 400, y: 400)

func post(_ type: CGEventType, at point: CGPoint, flags: CGEventFlags = []) {
    guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left) else { return }
    event.flags = flags
    event.post(tap: .cghidEventTap)
}

/// Eased pointer movement, so the recording doesn't look like teleporting.
func move(to target: CGPoint, duration: TimeInterval = 0.55, flags: CGEventFlags = []) {
    let steps = max(Int(duration * 90), 2)
    let from = cursor
    for i in 1...steps {
        let t = Double(i) / Double(steps)
        let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        post(.mouseMoved, at: CGPoint(x: from.x + (target.x - from.x) * eased,
                                      y: from.y + (target.y - from.y) * eased), flags: flags)
        wait(duration / Double(steps))
    }
    cursor = target
}

func click(flags: CGEventFlags = []) {
    post(.leftMouseDown, at: cursor, flags: flags)
    wait(0.09)
    post(.leftMouseUp, at: cursor, flags: flags)
}

func setOption(_ down: Bool) {
    guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x3A, keyDown: down) else { return }
    event.flags = down ? .maskAlternate : []
    event.type = .flagsChanged
    event.post(tap: .cghidEventTap)
}

/// MissionClose puts its buttons just outside the thumbnail's top-left corner.
func buttonPoint(_ frame: CGRect, index: Int, size: CGFloat = 20) -> CGPoint {
    let spacing = (size * 0.3).rounded()
    return CGPoint(x: frame.minX - size / 3 + size / 2 + CGFloat(index) * (size + spacing),
                   y: frame.minY - size / 3 + size / 2)
}

// MARK: - Diagnostics

/// --diagnose: try each window action on every demo thumbnail and log what macOS returns,
/// so failures (e.g. an app refusing to minimize while Mission Control is open) are visible.
func diagnose(_ hud: HUD) {
    var report = ["MissionClose action diagnostics \(Date())"]
    func attempt(_ label: String, _ body: () -> AXError) {
        let error = body()
        report.append("    \(label): \(error == .success ? "ok" : "FAILED (\(error.rawValue))")")
    }

    toggleMissionControl()
    let thumbs = settledThumbnails()
    report.append("thumbnails: \(thumbs.count) demo windows")
    var windows = WindowIndex.all()

    // Exact titles and subroles, to see why a thumbnail fails to match a window.
    report.append("\nWindowIndex sees \(windows.count) windows:")
    for w in windows {
        report.append("  [\(w.app.localizedName ?? "?")] \"\(w.title)\" size=\(Int(w.size.width))x\(Int(w.size.height))")
    }
    report.append("\nRaw AX windows of the demo apps:")
    for app in NSWorkspace.shared.runningApplications
    where ["TextEdit", "Preview"].contains(app.localizedName ?? "") {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        report.append("  \(app.localizedName ?? "?"): \(axApp.windows.count) windows")
        for window in axApp.windows {
            let minimized = window.value(kAXMinimizedAttribute) as? Bool ?? false
            report.append("    subrole=\(window.subrole ?? "nil") minimized=\(minimized) title=\"\(window.title ?? "nil")\"")
        }
    }
    report.append("\nThumbnail titles: " + thumbs.map { "\"\($0.title)\"" }.joined(separator: ", "))
    // Mission Control rebuilds its thumbnails after every action, so re-read them each round
    // instead of reusing stale elements.
    for index in thumbs.indices {
        let current = settledThumbnails()
        guard index < current.count else { break }
        let thumb = current[index]
        windows = WindowIndex.all()
        report.append("\n  \(thumb.title)")
        guard let target = WindowIndex.match(thumb.element, in: windows) else {
            report.append("    no matching window")
            continue
        }
        report.append("    app: \(target.app.localizedName ?? "?")  window: \(target.title)")
        let window = target.window
        for attribute in [kAXMinimizedAttribute, "AXFullScreen", kAXCloseButtonAttribute, kAXMinimizeButtonAttribute, kAXFullScreenButtonAttribute] {
            var settable: DarwinBoolean = false
            AXUIElementIsAttributeSettable(window, attribute as CFString, &settable)
            report.append("    \(attribute): present=\(window.value(attribute) != nil) settable=\(settable.boolValue)")
        }
        attempt("set AXMinimized true") {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }
        wait(1.2)
        report.append("    minimized now: \(window.value(kAXMinimizedAttribute) as? Bool ?? false)")
        attempt("press minimize button") {
            guard let button = window.value(kAXMinimizeButtonAttribute), CFGetTypeID(button) == AXUIElementGetTypeID() else { return .attributeUnsupported }
            return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
        }
        wait(1.2)
        report.append("    minimized after press: \(window.value(kAXMinimizedAttribute) as? Bool ?? false)")
        attempt("set AXMinimized false") {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        wait(0.8)
    }
    toggleMissionControl()
    wait(1.0)

    let log = report.joined(separator: "\n")
    let url = URL(fileURLWithPath: "/tmp/missionclose-diagnostics.txt")
    try? log.write(to: url, atomically: true, encoding: .utf8)
    print(log)
    hud.show("Diagnostics written to \(url.path)")
    wait(4)
    hud.hide()
    closeDemoWindows()
}

// MARK: - Script

if let index = arguments.firstIndex(of: "--helper"), arguments.indices.contains(index + 1),
   let spec = HelperSpec.parse(arguments[index + 1]) {
    runHelper(spec)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let hud = HUD()

let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
guard trusted else {
    hud.show("Grant DemoDriver Accessibility access, then run it again")
    print("""
    DemoDriver needs Accessibility access.
    Approve the prompt, or add it in System Settings → Privacy & Security → Accessibility:
      \(Bundle.main.bundleURL.path)
    """)
    wait(8)
    exit(1)
}

print("Opening demo windows…")
hud.show("Opening demo windows…")
openDemoWindows()
wait(1.2)
arrangeDemoWindows()
wait(1.0)

if arguments.contains("--diagnose") {
    hud.show("Running diagnostics…")
    diagnose(hud)
    exit(0)
}

// Counts down so there's time to start the screen recording (⌘⇧5).
let countdownIndex = arguments.firstIndex(of: "--countdown").map { $0 + 1 }
let lead = countdownIndex.flatMap { arguments.indices.contains($0) ? Int(arguments[$0]) : nil } ?? 12
for remaining in stride(from: lead, through: 1, by: -1) {
    hud.show(remaining > 3
        ? "Start recording now  (⌘⇧5)          Demo starts in \(remaining)s"
        : "Starting in \(remaining)…")
    wait(1)
}
hud.hide()
wait(0.6)
step("open Mission Control")
toggleMissionControl()

let thumbs = settledThumbnails()
guard thumbs.count >= 3 else {
    print("Couldn't find the demo thumbnails in Mission Control (found \(thumbs.count)).")
    closeDemoWindows()
    exit(1)
}

/// Picks a demo thumbnail by a fragment of its title, so each step acts on the app we mean.
func thumbnail(_ fragment: String) -> (element: AXUIElement, frame: CGRect, title: String)? {
    settledThumbnails().first { $0.title.contains(fragment) }
}

/// Waits until no thumbnail matches, so pacing follows what's on screen instead of a fixed guess.
func waitUntilGone(_ fragment: String, timeout: TimeInterval = 5) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if !settledThumbnails().contains(where: { $0.title.contains(fragment) }) { return }
        wait(0.15)
    }
}

// 1. Hover a window, then close it: the photo.
if let target = thumbnail("Sunset") {
    step("hover a window")
    move(to: CGPoint(x: target.frame.midX, y: target.frame.midY), duration: 0.8)
    wait(0.7)
    step("close it")
    move(to: buttonPoint(target.frame, index: 0), duration: 0.45)
    wait(0.5)
    click()
    waitUntilGone("Sunset")
    wait(0.7)
}

// 2. Minimize a different app's window: the file browser.
if let target = thumbnail("Screenshots") {
    step("minimize a window from another app")
    move(to: CGPoint(x: target.frame.midX, y: target.frame.midY), duration: 0.7)
    wait(0.5)
    move(to: buttonPoint(target.frame, index: 1), duration: 0.4)
    wait(0.5)
    click()
    waitUntilGone("Screenshots")
    wait(0.7)
}

// 3. Hold Option: ✕ becomes ⏻, and one click quits that app, taking both of its windows.
if let target = thumbnail("Launch checklist") {
    step("hold option, quit the app and both its windows")
    move(to: CGPoint(x: target.frame.midX, y: target.frame.midY), duration: 0.7)
    wait(0.4)
    move(to: buttonPoint(target.frame, index: 0), duration: 0.4)
    wait(0.4)
    setOption(true)
    wait(1.1)
    click(flags: .maskAlternate)
    wait(0.25)
    setOption(false)
    waitUntilGone("Release notes")
    wait(0.9)
}

step("leave Mission Control")
toggleMissionControl()
wait(1.5)

wait(0.8)
hud.show("Done. Stop the recording (⌘⇧5).")
print("\nDone. Stop the recording.")
closeDemoWindows()
wait(3)
hud.hide()
