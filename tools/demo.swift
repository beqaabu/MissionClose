import Cocoa

// Drives a scripted MissionClose demo for screen recordings.
//
// It opens its own throwaway windows (TextEdit documents and Preview images), arranges them,
// opens Mission Control, then moves the pointer and clicks the buttons on a fixed timeline.
// Only windows whose title starts with DEMO_PREFIX are ever touched.
//
// Needs Accessibility access (to read Mission Control's thumbnails and to post clicks).

let DEMO_PREFIX = "mcdemo-"
let demoDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("missionclose-demo")

// MARK: - Input

func wait(_ seconds: TimeInterval) {
    let until = Date().addingTimeInterval(seconds)
    while Date() < until { RunLoop.current.run(mode: .default, before: until) }
}

func step(_ message: String) {
    print("· \(message)")
}

// MARK: - Demo content

let documents: [(name: String, body: String)] = [
    ("\(DEMO_PREFIX)notes.txt", """
    Launch checklist

    - Record the demo clip
    - Post to r/macapps
    - Show HN on Tuesday morning
    - Update the Homebrew cask
    """),
    ("\(DEMO_PREFIX)changelog.txt", """
    MissionClose 0.2.1

    Traffic-light buttons on every thumbnail.
    Keyboard: cmd-W, cmd-Q, cmd-M.
    Hold option to quit the whole app.
    """),
    ("\(DEMO_PREFIX)readme.txt", """
    MissionClose

    Close windows straight from Mission Control.
    Hover a window, click the X.
    """),
]

/// Colorful placeholder images, so the thumbnails aren't all walls of text.
func makeImages() -> [URL] {
    let palettes: [[NSColor]] = [
        [NSColor(red: 0.30, green: 0.45, blue: 1.0, alpha: 1), NSColor(red: 0.78, green: 0.31, blue: 0.75, alpha: 1)],
        [NSColor(red: 1.0, green: 0.54, blue: 0.36, alpha: 1), NSColor(red: 0.98, green: 0.22, blue: 0.34, alpha: 1)],
    ]
    return palettes.enumerated().map { index, colors in
        let size = NSSize(width: 1400, height: 900)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGradient(colors: colors)?.draw(in: NSRect(origin: .zero, size: size), angle: 35)
        image.unlockFocus()
        let url = demoDir.appendingPathComponent("\(DEMO_PREFIX)image\(index + 1).png")
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
        return url
    }
}

func openDemoWindows() -> [NSRunningApplication] {
    try? FileManager.default.createDirectory(at: demoDir, withIntermediateDirectories: true)
    var urls: [URL] = []
    for doc in documents {
        let url = demoDir.appendingPathComponent(doc.name)
        try? doc.body.write(to: url, atomically: true, encoding: .utf8)
        urls.append(url)
    }
    let images = makeImages()

    var apps: [NSRunningApplication] = []
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    let group = DispatchGroup()
    for (appPath, files) in [("/System/Applications/TextEdit.app", urls), ("/System/Applications/Preview.app", images)] {
        group.enter()
        NSWorkspace.shared.open(files, withApplicationAt: URL(fileURLWithPath: appPath), configuration: config) { app, _ in
            if let app { apps.append(app) }
            group.leave()
        }
        wait(1.2)
    }
    group.wait()
    return apps
}

/// Spreads the demo windows out so Mission Control has something interesting to lay out.
func arrangeDemoWindows() {
    guard let screen = NSScreen.main?.frame else { return }
    let frames: [CGRect] = [
        CGRect(x: 0.05, y: 0.10, width: 0.40, height: 0.46),
        CGRect(x: 0.53, y: 0.08, width: 0.38, height: 0.42),
        CGRect(x: 0.20, y: 0.32, width: 0.36, height: 0.40),
        CGRect(x: 0.42, y: 0.40, width: 0.44, height: 0.46),
        CGRect(x: 0.10, y: 0.05, width: 0.42, height: 0.44),
    ]
    var index = 0
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        for window in axApp.windows {
            guard let title = window.title, title.hasPrefix(DEMO_PREFIX), index < frames.count else { continue }
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
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        for window in axApp.windows where window.title?.hasPrefix(DEMO_PREFIX) == true {
            _ = window.pressButton(kAXCloseButtonAttribute)
        }
    }
    try? FileManager.default.removeItem(at: demoDir)
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

// MARK: - Script

guard AXIsProcessTrusted() else {
    print("""
    This tool needs Accessibility access.
    System Settings → Privacy & Security → Accessibility, then add the DemoDriver binary:
      \(URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path)
    """)
    exit(1)
}

print("Opening demo windows…")
_ = openDemoWindows()
wait(1.5)
arrangeDemoWindows()
wait(1.0)

print("""

Ready. Start your screen recording (⌘⇧5 → Record Selected Portion or Entire Screen),
then press Return here to run the demo.
""")
_ = readLine()

wait(1.2)
step("open Mission Control")
toggleMissionControl()

var thumbs = settledThumbnails()
guard thumbs.count >= 3 else {
    print("Couldn't find the demo thumbnails in Mission Control (found \(thumbs.count)).")
    closeDemoWindows()
    exit(1)
}

// 1. Hover a window so the buttons appear.
step("hover a window")
move(to: CGPoint(x: thumbs[1].frame.midX, y: thumbs[1].frame.midY), duration: 0.8)
wait(0.7)

// 2. Close it.
step("click close")
move(to: buttonPoint(thumbs[1].frame, index: 0), duration: 0.45)
wait(0.5)
click()
wait(1.3)

// 3. Minimize the next one.
thumbs = settledThumbnails()
if thumbs.count >= 2 {
    step("minimize another window")
    move(to: CGPoint(x: thumbs[0].frame.midX, y: thumbs[0].frame.midY), duration: 0.6)
    wait(0.5)
    move(to: buttonPoint(thumbs[0].frame, index: 1), duration: 0.4)
    wait(0.5)
    click()
    wait(1.4)
}

// 4. Hold Option: the ✕ becomes ⏻, and the click quits the whole app.
thumbs = settledThumbnails()
if let target = thumbs.first {
    step("hold option, quit the app")
    move(to: CGPoint(x: target.frame.midX, y: target.frame.midY), duration: 0.6)
    wait(0.4)
    move(to: buttonPoint(target.frame, index: 0), duration: 0.4)
    wait(0.4)
    setOption(true)
    wait(1.0)
    click(flags: .maskAlternate)
    wait(0.3)
    setOption(false)
    wait(1.5)
}

step("leave Mission Control")
toggleMissionControl()
wait(1.5)

print("\nDone. Stop the recording.")
closeDemoWindows()
