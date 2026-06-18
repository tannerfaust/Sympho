import AppKit

struct MenuBarIconSpec {
    let filename: String
    let size: Int
}

let outputDirectory = URL(fileURLWithPath: "Sympho/Sympho/Assets.xcassets/SymphoMenuBarIcon.imageset", isDirectory: true)
let specs = [
    MenuBarIconSpec(filename: "sympho-menu-bar-icon.png", size: 18),
    MenuBarIconSpec(filename: "sympho-menu-bar-icon@2x.png", size: 36),
    MenuBarIconSpec(filename: "sympho-menu-bar-icon@3x.png", size: 54)
]

func drawIcon(size: Int) -> NSBitmapImageRep {
    let canvas = CGFloat(size)
    let scale = canvas / 18
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

    NSColor.black.setFill()

    let stroke = s(2.7)
    capsulePath(from: NSPoint(x: s(4.2), y: s(12.4)), to: NSPoint(x: s(13.8), y: s(12.4)), width: stroke).fill()
    capsulePath(from: NSPoint(x: s(13.2), y: s(12.0)), to: NSPoint(x: s(4.4), y: s(5.7)), width: stroke).fill()
    capsulePath(from: NSPoint(x: s(4.0), y: s(5.4)), to: NSPoint(x: s(13.6), y: s(5.4)), width: stroke).fill()

    NSColor.clear.setFill()
    NSGraphicsContext.current?.compositingOperation = .clear
    capsulePath(from: NSPoint(x: s(6.3), y: s(10.2)), to: NSPoint(x: s(10.6), y: s(10.2)), width: s(1.45)).fill()
    capsulePath(from: NSPoint(x: s(6.9), y: s(7.8)), to: NSPoint(x: s(11.5), y: s(7.8)), width: s(1.45)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for spec in specs {
    let rep = drawIcon(size: spec.size)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: outputDirectory.appendingPathComponent(spec.filename))
}
