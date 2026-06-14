import AppKit

struct IconSpec {
    let filename: String
    let size: Int
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fatalError("Usage: swift tools/install_generated_app_icon.swift <source-png>")
}

let sourceURL = URL(fileURLWithPath: arguments[1])
let outputDirectory = URL(fileURLWithPath: "Sympho/Sympho/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let previewDirectory = URL(fileURLWithPath: "Sympho/Design", isDirectory: true)

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

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Could not load source image at \(sourceURL.path)")
}

func renderIcon(size: Int) -> NSBitmapImageRep {
    let canvas = CGFloat(size)
    let radius = canvas * 0.222
    let sourceSize = sourceImage.size
    let sourceInset = min(sourceSize.width, sourceSize.height) * 0.045
    let sourceCrop = NSRect(
        x: sourceInset,
        y: sourceInset,
        width: sourceSize.width - sourceInset * 2,
        height: sourceSize.height - sourceInset * 2
    )
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

    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

    let rect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    let clipPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    clipPath.addClip()
    sourceImage.draw(in: rect, from: sourceCrop, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)

for spec in specs {
    let rep = renderIcon(size: spec.size)
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: outputDirectory.appendingPathComponent(spec.filename))
}

let preview = renderIcon(size: 1024)
let previewData = preview.representation(using: .png, properties: [:])!
try previewData.write(to: previewDirectory.appendingPathComponent("sympho-app-icon-ios26-roadmap.png"))
