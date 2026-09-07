// Renders the app icon into an .iconset directory.
// Usage: swift Tools/MakeIcon.swift <output.iconset>

import AppKit

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: MakeIcon.swift <output.iconset>\n".utf8))
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: arguments[1])
try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: Int(size),
                                     pixelsHigh: Int(size),
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0,
                                     bitsPerPixel: 0) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS app icons sit inside a margin.
    let inset = size * 0.085
    let square = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let corner = square.width * 0.2237

    let background = NSBezierPath(roundedRect: square, xRadius: corner, yRadius: corner)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.09, green: 0.24, blue: 0.27, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.11, blue: 0.14, alpha: 1),
    ])?.draw(in: background, angle: -90)

    // Three rings: an eye, and the rule's three twenties.
    let center = NSPoint(x: square.midX, y: square.midY)
    let radii: [CGFloat] = [0.34, 0.24, 0.14]
    let alphas: [CGFloat] = [0.30, 0.55, 0.85]
    for (radius, alpha) in zip(radii, alphas) {
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: square.width * radius, startAngle: 0, endAngle: 360)
        path.lineWidth = max(1, square.width * 0.032)
        NSColor(calibratedWhite: 1, alpha: alpha).setStroke()
        path.stroke()
    }

    let pupil = NSBezierPath()
    pupil.appendArc(withCenter: center, radius: square.width * 0.055, startAngle: 0, endAngle: 360)
    NSColor(calibratedWhite: 1, alpha: 0.95).setFill()
    pupil.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    guard let rep = drawIcon(size: variant.pixels),
          let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to render \(variant.name)\n".utf8))
        exit(1)
    }
    try data.write(to: outputDirectory.appendingPathComponent(variant.name))
}
