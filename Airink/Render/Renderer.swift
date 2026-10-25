import CoreGraphics
import CoreText
import Foundation

/// Draws annotations with Core Graphics. Shared by the on-screen canvas and the export,
/// so what you see is exactly what gets copied.
nonisolated enum Renderer {
    /// Composites `annotations` over `image` at full resolution.
    static func render(image: CGImage, annotations: [Annotation], pointScale: CGFloat) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: rgbColorSpace(for: image),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        draw(annotations, in: context, image: image, pointScale: pointScale)
        return context.makeImage()
    }

    /// The image's own color space when it's RGB (e.g. Display P3 screenshots), otherwise sRGB.
    /// Grayscale and indexed spaces can't back the RGBA bitmaps we draw into.
    static func rgbColorSpace(for image: CGImage) -> CGColorSpace {
        if let space = image.colorSpace, space.model == .rgb, space.supportsOutput { return space }
        return CGColorSpace(name: CGColorSpace.sRGB)!
    }

    /// Draws mosaic areas first, then everything else in order, so arrows or text drawn
    /// before a mosaic stay visible on top of it.
    static func draw(_ annotations: [Annotation], in context: CGContext, image: CGImage, pointScale: CGFloat) {
        for annotation in annotations where annotation.isPixelate {
            draw(annotation, in: context, image: image, pointScale: pointScale)
        }
        for annotation in annotations where !annotation.isPixelate {
            draw(annotation, in: context, image: image, pointScale: pointScale)
        }
    }

    /// `image` is the original image; pixelate areas sample it, never other annotations.
    static func draw(_ annotation: Annotation, in context: CGContext, image: CGImage, pointScale: CGFloat) {
        let lineWidth = annotation.width.points * pointScale
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(annotation.color.cgColor)
        context.setFillColor(annotation.color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.shape {
        case let .line(from, to):
            context.strokeLineSegments(between: [from, to])
        case let .rectangle(rect):
            context.stroke(rect)
        case let .arrow(from, to):
            drawArrow(from: from, to: to, lineWidth: lineWidth, in: context)
        case let .text(string, origin):
            drawText(string, at: origin, annotation: annotation, pointScale: pointScale, in: context)
        case let .pixelate(rect):
            drawMosaic(rect, blockSize: annotation.width.pixelBlockSize * pointScale, image: image, in: context)
        }
    }

    /// Bold system font used for text annotations, sized in image pixels.
    static func font(for width: StrokeWidth, pointScale: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, width.fontSize * pointScale, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, width.fontSize * pointScale, nil)
    }

    /// Baseline-to-baseline distance for multi-line text. The editor's text view uses the
    /// same value so typed text lines up exactly with the rendered result.
    static func lineHeight(for font: CTFont) -> CGFloat {
        CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    }

    /// Replaces `rect` with blocks of averaged color: the area is downsampled to one pixel per
    /// block, then scaled back up without interpolation. Blocks are always opaque (transparent
    /// areas are flattened onto white), so nothing underneath shows through — on the canvas
    /// the original image is a separate layer below the overlay.
    private static func drawMosaic(_ rect: CGRect, blockSize: CGFloat, image: CGImage, in context: CGContext) {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let area = rect.integral.intersection(bounds)
        guard !area.isEmpty, blockSize > 0,
              // CGImage cropping uses a top-left origin.
              let crop = image.cropping(to: CGRect(
                  x: area.minX, y: bounds.height - area.maxY, width: area.width, height: area.height
              ))
        else { return }

        let columns = max(1, Int((area.width / blockSize).rounded(.up)))
        let rows = max(1, Int((area.height / blockSize).rounded(.up)))
        guard let small = CGContext(
            data: nil, width: columns, height: rows, bitsPerComponent: 8, bytesPerRow: 0,
            space: rgbColorSpace(for: image), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return }
        let blockRect = CGRect(x: 0, y: 0, width: columns, height: rows)
        small.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        small.fill(blockRect)
        small.interpolationQuality = .high
        small.draw(crop, in: blockRect)
        guard let blocks = small.makeImage() else { return }

        context.saveGState()
        context.interpolationQuality = .none
        context.setBlendMode(.copy) // Replace, never blend with, the pixels underneath.
        context.draw(blocks, in: area)
        context.restoreGState()
    }

    private static func drawArrow(from: CGPoint, to: CGPoint, lineWidth: CGFloat, in context: CGContext) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let length = hypot(to.x - from.x, to.y - from.y)
        let headLength = min(max(lineWidth * 4, 10), length)
        let spread = CGFloat.pi / 7

        // Stop the shaft inside the head so the round cap doesn't poke through the tip.
        let shaftEnd = CGPoint(
            x: to.x - cos(angle) * headLength * 0.8,
            y: to.y - sin(angle) * headLength * 0.8
        )
        context.strokeLineSegments(between: [from, shaftEnd])

        context.move(to: to)
        context.addLine(to: CGPoint(
            x: to.x - cos(angle - spread) * headLength,
            y: to.y - sin(angle - spread) * headLength
        ))
        context.addLine(to: CGPoint(
            x: to.x - cos(angle + spread) * headLength,
            y: to.y - sin(angle + spread) * headLength
        ))
        context.closePath()
        context.drawPath(using: .fillStroke)
    }

    private static func drawText(
        _ string: String,
        at origin: CGPoint,
        annotation: Annotation,
        pointScale: CGFloat,
        in context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(for: annotation.width, pointScale: pointScale),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): annotation.color.cgColor,
        ]
        let font = font(for: annotation.width, pointScale: pointScale)
        let step = lineHeight(for: font)
        context.textMatrix = .identity
        // `origin` is the first line's baseline; following lines go downward.
        for (index, text) in string.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(text), attributes: attributes))
            context.textPosition = CGPoint(x: origin.x, y: origin.y - CGFloat(index) * step)
            CTLineDraw(line, context)
        }
    }
}

private extension Annotation {
    nonisolated var isPixelate: Bool {
        if case .pixelate = shape { true } else { false }
    }
}
