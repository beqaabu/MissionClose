import Cocoa

// Draws the app icon and writes Resources/AppIcon.icns (plus a 1024px PNG for previews).
// Run through tools/make-icon.sh, which calls iconutil.

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

/// The icon: a dark squircle with the Mission Control spread of windows and a red close badge.
func drawIcon(size S: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    let unit = S / 1024

    // macOS icons leave a margin inside their canvas.
    let plate = NSRect(x: 100 * unit, y: 100 * unit, width: S - 200 * unit, height: S - 200 * unit)
    let squircle = NSBezierPath(roundedRect: plate, xRadius: 185 * unit, yRadius: 185 * unit)

    ctx.saveGState()
    squircle.addClip()
    NSGradient(colors: [NSColor(red: 0.29, green: 0.32, blue: 0.38, alpha: 1),
                        NSColor(red: 0.13, green: 0.14, blue: 0.18, alpha: 1)])?
        .draw(in: plate, angle: -90)
    // A soft highlight across the top, like Apple's utility icons.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.16), NSColor.white.withAlphaComponent(0)])?
        .draw(in: NSRect(x: plate.minX, y: plate.midY, width: plate.width, height: plate.height / 2), angle: -90)
    ctx.restoreGState()

    NSColor.black.withAlphaComponent(0.25).setStroke()
    squircle.lineWidth = 2 * unit
    squircle.stroke()

    // Three window tiles: one wide on top, two below.
    func tile(_ rect: NSRect, alpha: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 26 * unit, yRadius: 26 * unit)
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
    }
    tile(NSRect(x: 320 * unit, y: 520 * unit, width: 430 * unit, height: 225 * unit), alpha: 0.95)
    tile(NSRect(x: 265 * unit, y: 268 * unit, width: 235 * unit, height: 195 * unit), alpha: 0.76)
    tile(NSRect(x: 528 * unit, y: 268 * unit, width: 235 * unit, height: 195 * unit), alpha: 0.76)

    // The close badge on the corner of the top window, with a gap punched around it.
    let center = NSPoint(x: 330 * unit, y: 722 * unit)
    let radius = 104 * unit
    ctx.saveGState()
    ctx.setBlendMode(.clear)
    NSBezierPath(ovalIn: NSRect(x: center.x - radius - 24 * unit, y: center.y - radius - 24 * unit,
                                width: (radius + 24 * unit) * 2, height: (radius + 24 * unit) * 2)).fill()
    ctx.restoreGState()

    let badge = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    NSGradient(colors: [NSColor(red: 1.0, green: 0.45, blue: 0.42, alpha: 1),
                        NSColor(red: 0.93, green: 0.25, blue: 0.22, alpha: 1)])?
        .draw(in: NSBezierPath(ovalIn: badge), angle: -90)

    let arm = radius * 0.42
    let cross = NSBezierPath()
    cross.move(to: NSPoint(x: center.x - arm, y: center.y - arm))
    cross.line(to: NSPoint(x: center.x + arm, y: center.y + arm))
    cross.move(to: NSPoint(x: center.x - arm, y: center.y + arm))
    cross.line(to: NSPoint(x: center.x + arm, y: center.y - arm))
    cross.lineWidth = 34 * unit
    cross.lineCapStyle = .round
    NSColor.white.setStroke()
    cross.stroke()
}

func render(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: size)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to path: String) {
    try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

// iconset layout expected by iconutil
let iconset = "\(outputDirectory)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    write(render(size: CGFloat(base)), to: "\(iconset)/icon_\(base)x\(base).png")
    write(render(size: CGFloat(base * 2)), to: "\(iconset)/icon_\(base)x\(base)@2x.png")
}
write(render(size: 1024), to: "\(outputDirectory)/icon-preview.png")
print("wrote \(iconset)")
