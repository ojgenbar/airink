import CoreGraphics
import Foundation

nonisolated enum Tool: String, CaseIterable, Sendable {
    case arrow, rectangle, line, text, pixelate
}

nonisolated enum AnnotationColor: String, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple, black, white

    var cgColor: CGColor {
        switch self {
        case .red: CGColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1)
        case .orange: CGColor(srgbRed: 1.00, green: 0.58, blue: 0.00, alpha: 1)
        case .yellow: CGColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1)
        case .green: CGColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        case .blue: CGColor(srgbRed: 0.00, green: 0.48, blue: 1.00, alpha: 1)
        case .purple: CGColor(srgbRed: 0.69, green: 0.32, blue: 0.87, alpha: 1)
        case .black: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        case .white: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        }
    }
}

nonisolated enum StrokeWidth: Int, CaseIterable, Sendable {
    case thin = 1, medium, thick

    /// Line width in points; multiplied by the image's point scale when drawing.
    var points: CGFloat {
        switch self {
        case .thin: 2
        case .medium: 4
        case .thick: 8
        }
    }

    /// Mosaic block size in points for the pixelate tool. Kept coarse so hidden text
    /// can't be recovered from the averaged blocks.
    var pixelBlockSize: CGFloat {
        switch self {
        case .thin: 8
        case .medium: 12
        case .thick: 20
        }
    }

    /// Font size in points for the text tool.
    var fontSize: CGFloat {
        switch self {
        case .thin: 16
        case .medium: 24
        case .thick: 36
        }
    }
}

/// One annotation. All geometry is in image pixel space, origin bottom-left.
nonisolated struct Annotation: Identifiable, Equatable, Sendable {
    enum Shape: Equatable, Sendable {
        case arrow(from: CGPoint, to: CGPoint)
        case rectangle(CGRect)
        case line(from: CGPoint, to: CGPoint)
        /// `origin` is the left end of the first line's baseline.
        case text(String, origin: CGPoint)
        /// Area of the original image to cover with a mosaic.
        case pixelate(CGRect)
    }

    let id: UUID
    var shape: Shape
    var color: AnnotationColor
    var width: StrokeWidth

    init(id: UUID = UUID(), shape: Shape, color: AnnotationColor, width: StrokeWidth) {
        self.id = id
        self.shape = shape
        self.color = color
        self.width = width
    }
}

extension Annotation.Shape {
    /// Builds a drag-based shape. With `constrained` (Shift held), lines snap to 45° steps and
    /// rectangles (and pixelate areas) become squares. Returns nil for drags shorter than `minimumLength`.
    nonisolated static func make(
        tool: Tool,
        from start: CGPoint,
        to end: CGPoint,
        constrained: Bool,
        minimumLength: CGFloat
    ) -> Self? {
        switch tool {
        case .arrow, .line:
            let end = constrained ? snapped(end, around: start) : end
            guard hypot(end.x - start.x, end.y - start.y) >= minimumLength else { return nil }
            return tool == .arrow ? .arrow(from: start, to: end) : .line(from: start, to: end)
        case .rectangle, .pixelate:
            var dx = end.x - start.x
            var dy = end.y - start.y
            if constrained {
                let side = max(abs(dx), abs(dy))
                dx = dx < 0 ? -side : side
                dy = dy < 0 ? -side : side
            }
            guard abs(dx) >= minimumLength, abs(dy) >= minimumLength else { return nil }
            let rect = CGRect(x: start.x, y: start.y, width: dx, height: dy).standardized
            return tool == .rectangle ? .rectangle(rect) : .pixelate(rect)
        case .text:
            return nil
        }
    }

    private nonisolated static func snapped(_ point: CGPoint, around origin: CGPoint) -> CGPoint {
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let step = CGFloat.pi / 4
        let angle = (atan2(dy, dx) / step).rounded() * step
        let length = hypot(dx, dy)
        return CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length)
    }
}
