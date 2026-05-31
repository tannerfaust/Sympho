import AppKit

struct IconSpec {
    let filename: String
    let size: Int
}

let outputDirectory = URL(fileURLWithPath: "Sympho/Sympho/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let specs = [
    IconSpec(filename: "sympho-app-icon-16.png", size: 16),
    IconSpec(filename: "sympho-app-icon-16@2x.png", size: 32),
    IconSpec(filename: "sympho-app-icon-32.png", size: 32),
    IconSpec(filename: "sympho-app-icon-32@2x.png", size: 64),
    IconSpec(filename: "sympho-app-icon-128.png", size: 128),
    IconSpec(filename: "sympho-app-icon-128@2x.png", size: 256),
    IconSpec(filename: "sympho-app-icon-256.png", size: 256),
    IconSpec(filename: "sympho-app-icon-256@2x.png", size: 512),
    IconSpec(filename: "sympho-app-icon-512.png", size: 512),
    IconSpec(filename: "sympho-app-icon-512@2x.png", size: 1024),
    IconSpec(filename: "sympho-app-icon-1024.png", size: 1024),
]

func drawIcon(size: Int) -> NSBitmapImageRep {
    let canvas = CGFloat(size)
    let scale = canvas / 1024
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

    func s(_ value: CGFloat) -> CGFloat { value * scale }

    let tileRect = NSRect(x: s(58), y: s(58), width: s(908), height: s(908))
    let tile = NSBezierPath(roundedRect: tileRect, xRadius: s(205), yRadius: s(205))

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -s(20))
    shadow.shadowBlurRadius = s(56)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.26)
    shadow.set()
    let tileGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.155, green: 0.165, blue: 0.17, alpha: 1),
        NSColor(calibratedRed: 0.035, green: 0.04, blue: 0.045, alpha: 1)
    ])!
    tileGradient.draw(in: tile, angle: 90)
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    let highlight = NSBezierPath(roundedRect: tileRect.insetBy(dx: s(6), dy: s(6)), xRadius: s(198), yRadius: s(198))
    NSColor.white.withAlphaComponent(0.12).setStroke()
    highlight.lineWidth = max(1, s(3))
    highlight.stroke()

    let border = NSBezierPath(roundedRect: tileRect, xRadius: s(190), yRadius: s(190))
    NSColor.black.withAlphaComponent(0.42).setStroke()
    border.lineWidth = max(1, s(3))
    border.stroke()

    func capsulePath(from start: NSPoint, to end: NSPoint, width: CGFloat) -> NSBezierPath {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let rect = NSRect(x: -length / 2, y: -width / 2, width: length, height: width)
        let capsule = NSBezierPath(roundedRect: rect, xRadius: width / 2, yRadius: width / 2)
        let transform = NSAffineTransform()
        transform.translateX(by: (start.x + end.x) / 2, yBy: (start.y + end.y) / 2)
        transform.rotate(byRadians: angle)
        capsule.transform(using: transform as AffineTransform)
        return capsule
    }

    let markShadow = NSShadow()
    markShadow.shadowOffset = NSSize(width: 0, height: -s(12))
    markShadow.shadowBlurRadius = s(28)
    markShadow.shadowColor = NSColor.black.withAlphaComponent(0.38)

    NSGraphicsContext.saveGraphicsState()
    markShadow.set()
    let white = NSColor(calibratedWhite: 0.965, alpha: 1)
    white.setFill()

    let stroke = s(124)
    let top = capsulePath(
        from: NSPoint(x: s(332), y: s(700)),
        to: NSPoint(x: s(716), y: s(700)),
        width: stroke
    )
    let diagonal = capsulePath(
        from: NSPoint(x: s(690), y: s(684)),
        to: NSPoint(x: s(334), y: s(332)),
        width: stroke
    )
    let bottom = capsulePath(
        from: NSPoint(x: s(308), y: s(324)),
        to: NSPoint(x: s(692), y: s(324)),
        width: stroke
    )

    top.fill()
    diagonal.fill()
    bottom.fill()
    NSGraphicsContext.restoreGraphicsState()

    let cutColor = NSColor(calibratedRed: 0.055, green: 0.062, blue: 0.068, alpha: 1)
    cutColor.setFill()
    capsulePath(
        from: NSPoint(x: s(404), y: s(574)),
        to: NSPoint(x: s(584), y: s(574)),
        width: s(68)
    ).fill()
    capsulePath(
        from: NSPoint(x: s(430), y: s(452)),
        to: NSPoint(x: s(616), y: s(452)),
        width: s(68)
    ).fill()

    NSColor.white.withAlphaComponent(0.10).setFill()
    capsulePath(
        from: NSPoint(x: s(356), y: s(724)),
        to: NSPoint(x: s(614), y: s(724)),
        width: s(20)
    ).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let rep = drawIcon(size: spec.size)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: outputDirectory.appendingPathComponent(spec.filename))
}
