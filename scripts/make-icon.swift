// Fits a source icon to the macOS app-icon grid and writes every size the asset catalog needs.
// Usage: swift scripts/make-icon.swift design/icon-source.png Airink/Assets.xcassets/AppIcon.appiconset
//
// The source is cropped to its visible tile (alpha ≥ 8; fainter stray pixels are dropped),
// then scaled without distortion to fit the standard 824 px tile centered on a 1024 px canvas.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 2 else {
    print("Usage: swift scripts/make-icon.swift <source.png> <AppIcon.appiconset>")
    exit(1)
}
let sourceURL = URL(fileURLWithPath: arguments.first!)
let outputDirectory = URL(fileURLWithPath: arguments.last!)

let canvasSize = 1024
let tileSize: CGFloat = 824
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func makeContext(size: Int) -> CGContext {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    return context
}

/// Bounding box (top-left origin, as `cropping(to:)` expects) of pixels with alpha ≥ threshold.
func visibleBounds(of image: CGImage, threshold: UInt8 = 8) -> CGRect {
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    var minX = width, minY = height, maxX = -1, maxY = -1
    for row in 0..<height { // Bitmap memory rows run top to bottom.
        for column in 0..<width where pixels[(row * width + column) * 4 + 3] >= threshold {
            minX = min(minX, column); maxX = max(maxX, column)
            minY = min(minY, row); maxY = max(maxY, row)
        }
    }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let original = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    print("Can't read \(sourceURL.path)")
    exit(1)
}
let bounds = visibleBounds(of: original)
let tile = original.cropping(to: bounds)!

// Master: tile fitted into the 824 px grid square, centered on the 1024 canvas.
let scale = tileSize / max(bounds.width, bounds.height)
let fitted = CGSize(width: bounds.width * scale, height: bounds.height * scale)
let master = makeContext(size: canvasSize)
master.draw(tile, in: CGRect(
    x: (CGFloat(canvasSize) - fitted.width) / 2,
    y: (CGFloat(canvasSize) - fitted.height) / 2,
    width: fitted.width,
    height: fitted.height
))
let masterImage = master.makeImage()!

func write(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

// Remove previously generated PNGs so renamed sizes don't linger.
for file in (try? FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil)) ?? []
where file.pathExtension == "png" {
    try FileManager.default.removeItem(at: file)
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for pixelScale in [1, 2] {
        let pixels = points * pixelScale
        let name = "icon_\(points)x\(points)\(pixelScale == 2 ? "@2x" : "").png"
        let context = makeContext(size: pixels)
        context.draw(masterImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        write(context.makeImage()!, to: outputDirectory.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(pixelScale)x", "size": "\(points)x\(points)", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDirectory.appendingPathComponent("Contents.json"))
print("Source tile \(Int(bounds.width))×\(Int(bounds.height)) px → \(Int(fitted.width.rounded()))×\(Int(fitted.height.rounded())) on \(canvasSize) canvas")
print("Wrote \(images.count) icons to \(outputDirectory.path)")
