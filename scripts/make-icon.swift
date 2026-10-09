import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent("AppIcon.iconset")
let destination = root.appendingPathComponent("FiscalQuarterApp/AppIcon.icns")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let files: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in files {
    let rep = render(pixels: pixels)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fputs("could not encode \(name)\n", stderr)
        exit(1)
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", destination.path]
try task.run()
task.waitUntilExit()
if task.terminationStatus != 0 {
    exit(task.terminationStatus)
}
try? FileManager.default.removeItem(at: iconset)
print(destination.path)

func render(pixels: Int) -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fputs("bitmap failed\n", stderr)
        exit(1)
    }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(pixels)
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor(srgbRed: 0.078, green: 0.071, blue: 0.043, alpha: 1).setFill()
    bounds.fill()

    let center = NSPoint(x: bounds.midX, y: bounds.midY)
    let radius = size * 0.29
    let lineWidth = max(1, size * 0.07)
    let gap: CGFloat = 18
    let muted = NSColor(srgbRed: 0.969, green: 0.969, blue: 0.957, alpha: 0.38)
    let green = NSColor(srgbRed: 0.063, green: 0.725, blue: 0.506, alpha: 1)

    for index in 0..<4 {
        let start = CGFloat(index) * 90 + gap / 2
        let end = CGFloat(index + 1) * 90 - gap / 2
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        (index == 3 ? green : muted).setStroke()
        arc.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}
