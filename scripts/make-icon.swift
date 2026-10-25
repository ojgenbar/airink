// Draws Airink's app icon and writes every size the asset catalog needs.
// Usage: swift scripts/make-icon.swift Airink/Assets.xcassets/AppIcon.appiconset

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")

func makeIcon(size: Int) -> CGImage {
    let s = CGFloat(size) / 1024 // Design on a 1024 canvas.
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.displayP3)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.scaleBy(x: s, y: s)

    // macOS icon grid: 824pt rounded square centered on the 1024 canvas, with a soft shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(tilePath)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fillPath()
    context.restoreGState()

    // Background: deep indigo → blue gradient.
    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [
            CGColor(srgbRed: 0.16, green: 0.20, blue: 0.55, alpha: 1),
            CGColor(srgbRed: 0.18, green: 0.48, blue: 0.98, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(gradient, start: CGPoint(x: 200, y: 100), end: CGPoint(x: 824, y: 924), options: [])

    // A "screenshot" card.
    let card = CGRect(x: 230, y: 280, width: 564, height: 420)
    context.setFillColor(CGColor(gray: 1, alpha: 0.95))
    context.addPath(CGPath(roundedRect: card, cornerWidth: 36, cornerHeight: 36, transform: nil))
    context.fillPath()
    context.setFillColor(CGColor(srgbRed: 0.80, green: 0.84, blue: 0.92, alpha: 1))
    for (y, width) in [(600.0, 300.0), (540.0, 380.0), (480.0, 240.0)] {
        context.addPath(CGPath(
            roundedRect: CGRect(x: 280, y: y, width: width, height: 26),
            cornerWidth: 13, cornerHeight: 13, transform: nil
        ))
        context.fillPath()
    }

    // Red annotation rectangle and arrow, like Airink draws them.
    let red = CGColor(srgbRed: 1.0, green: 0.23, blue: 0.19, alpha: 1)
    context.setStrokeColor(red)
    context.setFillColor(red)
    context.setLineWidth(26)
    context.setLineJoin(.round)
    context.setLineCap(.round)
    context.stroke(CGRect(x: 262, y: 452, width: 290, height: 190))

    let tip = CGPoint(x: 560, y: 430)
    let tail = CGPoint(x: 790, y: 210)
    let angle = atan2(tip.y - tail.y, tip.x - tail.x)
    let head: CGFloat = 120
    let spread = CGFloat.pi / 7
    context.strokeLineSegments(between: [
        tail,
        CGPoint(x: tip.x - cos(angle) * head * 0.8, y: tip.y - sin(angle) * head * 0.8),
    ])
    context.move(to: tip)
    context.addLine(to: CGPoint(x: tip.x - cos(angle - spread) * head, y: tip.y - sin(angle - spread) * head))
    context.addLine(to: CGPoint(x: tip.x - cos(angle + spread) * head, y: tip.y - sin(angle + spread) * head))
    context.closePath()
    context.drawPath(using: .fillStroke)
    context.restoreGState()

    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        write(makeIcon(size: points * scale), to: outputDirectory.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDirectory.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(outputDirectory.path)")
