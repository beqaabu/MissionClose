import Cocoa

// Mock document windows for the demo recording, drawn by the driver itself so the clip never
// shows real apps or private content. Shared by the driver and by the preview renderer.

let DEMO_WINDOW_PREFIX = "mcdemo-"

enum WindowKind: String {
    case checklist, release, photo, files
}

struct HelperSpec {
    let kind: WindowKind
    let titles: [String]
    var argument: String { "\(kind.rawValue):\(titles.joined(separator: "|"))" }

    static func parse(_ text: String) -> HelperSpec? {
        let parts = text.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let kind = WindowKind(rawValue: String(parts[0])) else { return nil }
        return HelperSpec(kind: kind, titles: parts[1].split(separator: "|").map(String.init))
    }
}

let helperSpecs: [HelperSpec] = [
    HelperSpec(kind: .checklist, titles: ["\(DEMO_WINDOW_PREFIX)Launch checklist", "\(DEMO_WINDOW_PREFIX)Release notes"]),
    HelperSpec(kind: .photo, titles: ["\(DEMO_WINDOW_PREFIX)Sunset.png"]),
    HelperSpec(kind: .files, titles: ["\(DEMO_WINDOW_PREFIX)Screenshots"]),
]

/// Mock window content, drawn so the thumbnails look like real documents.
final class MockView: NSView {
    let kind: WindowKind
    init(kind: WindowKind, frame: NSRect) {
        self.kind = kind
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        switch kind {
        case .checklist: drawChecklist(title: "Launch checklist", accent: NSColor(red: 0.85, green: 0.25, blue: 0.3, alpha: 1),
                                       items: ["Record the demo clip", "Post to r/macapps", "Show HN on Tuesday", "Update the Homebrew cask"])
        case .release: drawChecklist(title: "MissionClose 0.2.1", accent: NSColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1),
                                     items: ["Traffic lights on every thumbnail", "Keyboard: cmd-W, cmd-Q, cmd-M", "Hold option to quit an app", "Universal build, macOS 13+"])
        case .photo: drawPhoto()
        case .files: drawFiles()
        }
    }

    private func drawChecklist(title: String, accent: NSColor, items: [String]) {
        NSColor.white.setFill()
        bounds.fill()
        title.draw(at: NSPoint(x: 38, y: 34), withAttributes: [
            .font: NSFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: accent])
        for (index, item) in items.enumerated() {
            let y = 100.0 + Double(index) * 46
            let box = NSBezierPath(roundedRect: NSRect(x: 40, y: y, width: 22, height: 22), xRadius: 5, yRadius: 5)
            accent.withAlphaComponent(index < 2 ? 1 : 0.28).setFill()
            box.fill()
            item.draw(at: NSPoint(x: 78, y: y - 1), withAttributes: [
                .font: NSFont.systemFont(ofSize: 19), .foregroundColor: NSColor.black.withAlphaComponent(0.8)])
        }
    }

    private func drawPhoto() {
        NSColor(white: 0.1, alpha: 1).setFill()
        bounds.fill()
        let photo = bounds.insetBy(dx: 18, dy: 18)
        NSGradient(colors: [NSColor(red: 1.0, green: 0.64, blue: 0.29, alpha: 1),
                            NSColor(red: 0.93, green: 0.33, blue: 0.42, alpha: 1),
                            NSColor(red: 0.35, green: 0.22, blue: 0.55, alpha: 1)])?
            .draw(in: photo, angle: -90)
        NSColor(white: 1, alpha: 0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: photo.midX - 45, y: photo.minY + photo.height * 0.22, width: 90, height: 90)).fill()
        NSColor(red: 0.16, green: 0.12, blue: 0.24, alpha: 1).setFill()
        let hills = NSBezierPath()
        hills.move(to: NSPoint(x: photo.minX, y: photo.maxY))
        hills.line(to: NSPoint(x: photo.minX, y: photo.maxY - photo.height * 0.28))
        hills.curve(to: NSPoint(x: photo.midX, y: photo.maxY - photo.height * 0.16),
                    controlPoint1: NSPoint(x: photo.minX + photo.width * 0.2, y: photo.maxY - photo.height * 0.42),
                    controlPoint2: NSPoint(x: photo.midX - photo.width * 0.15, y: photo.maxY - photo.height * 0.1))
        hills.curve(to: NSPoint(x: photo.maxX, y: photo.maxY - photo.height * 0.34),
                    controlPoint1: NSPoint(x: photo.midX + photo.width * 0.2, y: photo.maxY - photo.height * 0.24),
                    controlPoint2: NSPoint(x: photo.maxX - photo.width * 0.15, y: photo.maxY - photo.height * 0.5))
        hills.line(to: NSPoint(x: photo.maxX, y: photo.maxY))
        hills.close()
        hills.fill()
    }

    private func drawFiles() {
        NSColor(white: 0.97, alpha: 1).setFill()
        bounds.fill()
        NSColor(white: 0.92, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 150, height: bounds.height).fill()
        let palettes: [[NSColor]] = [
            [NSColor(red: 0.3, green: 0.45, blue: 1, alpha: 1), NSColor(red: 0.78, green: 0.31, blue: 0.75, alpha: 1)],
            [NSColor(red: 1, green: 0.54, blue: 0.36, alpha: 1), NSColor(red: 0.98, green: 0.22, blue: 0.34, alpha: 1)],
            [NSColor(red: 0.2, green: 0.8, blue: 0.6, alpha: 1), NSColor(red: 0.1, green: 0.35, blue: 0.55, alpha: 1)],
            [NSColor(red: 0.98, green: 0.8, blue: 0.25, alpha: 1), NSColor(red: 0.9, green: 0.35, blue: 0.2, alpha: 1)],
            [NSColor(red: 0.45, green: 0.6, blue: 0.95, alpha: 1), NSColor(red: 0.2, green: 0.25, blue: 0.5, alpha: 1)],
            [NSColor(red: 0.95, green: 0.45, blue: 0.7, alpha: 1), NSColor(red: 0.55, green: 0.2, blue: 0.6, alpha: 1)],
        ]
        for (index, colors) in palettes.enumerated() {
            let column = index % 3, row = index / 3
            let tile = NSRect(x: 190 + Double(column) * 150, y: 40 + Double(row) * 150, width: 116, height: 116)
            NSGradient(colors: colors)?.draw(in: NSBezierPath(roundedRect: tile, xRadius: 10, yRadius: 10), angle: 40)
            NSColor(white: 0.55, alpha: 1).setFill()
            NSRect(x: tile.minX + 18, y: tile.maxY + 12, width: 80, height: 9).fill()
        }
    }
}

/// --helper: this process shows the mock windows and waits to be closed or quit.
func runHelper(_ spec: HelperSpec) -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular) // so the windows show up in Mission Control and the Dock
    var windows: [NSWindow] = []
    for (index, title) in spec.titles.enumerated() {
        let kind: WindowKind = (spec.kind == .checklist && index == 1) ? .release : spec.kind
        let size = NSSize(width: 720, height: 460)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = title
        window.contentView = MockView(kind: kind, frame: NSRect(origin: .zero, size: size))
        window.isReleasedWhenClosed = false
        window.center()
        windows.append(window)
        window.makeKeyAndOrderFront(nil)
    }
    app.activate(ignoringOtherApps: true)
    app.run()
    exit(0)
}

