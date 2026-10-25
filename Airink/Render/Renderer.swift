import CoreGraphics
import CoreText
import Foundation

/// Draws annotations with Core Graphics. Shared by the on-screen canvas and the export,
/// so what you see is exactly what gets copied.
nonisolated enum Renderer {
    /// Composites `annotations` over `image` at full resolution.
    static func render(image: CGImage, annotations: [Annotation], pointScale: CGFloat) -> CGImage? {
        let colorSpace = image.colorSpace.flatMap { $0.supportsOutput ? $0 : nil }
            ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        draw(annotations, in: context, pointScale: pointScale)
        return context.makeImage()
    }

    static func draw(_ annotations: [Annotation], in context: CGContext, pointScale: CGFloat) {
        for annotation in annotations {
            draw(annotation, in: context, pointScale: pointScale)
        }
    }

    static func draw(_ annotation: Annotation, in context: CGContext, pointScale: CGFloat) {
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
