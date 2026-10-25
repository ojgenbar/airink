import AppKit

/// Shows the clipboard image. The bitmap lives in a layer so the GPU composites it;
/// only the annotations above it are redrawn while the user drags.
final class ImageLayerView: NSView {
    init(image: CGImage) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resize
        layer?.minificationFilter = .trilinear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var mouseDownCanMoveWindow: Bool { false }
}

/// Transparent overlay that draws annotations and handles the mouse for every tool.
final class CanvasView: NSView, NSTextViewDelegate {
    let document: AnnotationDocument

    private var dragStart: CGPoint?
    private var draft: Annotation?
    private var textView: NSTextView?
    private var textOrigin: CGPoint = .zero

    init(document: AnnotationDocument) {
        self.document = document
        super.init(frame: .zero)
        document.onChange = { [weak self] in self?.documentDidChange() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var isEditingText: Bool { textView != nil }

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// View points per image pixel.
    private var scale: CGFloat {
        bounds.width > 0 ? bounds.width / document.imageSize.width : 1
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.scaleBy(x: scale, y: scale)
        Renderer.draw(document.annotations, in: context, pointScale: document.pointScale)
        if let draft {
            Renderer.draw(draft, in: context, pointScale: document.pointScale)
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: document.tool == .text ? .iBeam : .crosshair)
    }

    private func documentDidChange() {
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
        guard let textView else { return }
        if document.tool == .text {
            styleTextView(textView)
        } else {
            commitText()
        }
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        commitText()
        let point = imagePoint(for: event)
        if document.tool == .text {
            beginText(at: point)
        } else {
            dragStart = point
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let shape = Annotation.Shape.make(
            tool: document.tool,
            from: dragStart,
            to: imagePoint(for: event),
            constrained: event.modifierFlags.contains(.shift),
            minimumLength: 3 / scale
        )
        draft = shape.map { Annotation(shape: $0, color: document.color, width: document.width) }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        if let draft { document.add(draft) }
        draft = nil
        dragStart = nil
        needsDisplay = true
    }

    private func imagePoint(for event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        let clamped = CGPoint(
            x: min(max(point.x, 0), bounds.width),
            y: min(max(point.y, 0), bounds.height)
        )
        return CGPoint(x: clamped.x / scale, y: clamped.y / scale)
    }

    // MARK: Text

    private func beginText(at origin: CGPoint) {
        // A plain NSTextView (not an NSTextField) so we control its size and style while
        // typing: it grows to the right instead of scrolling, and uses the annotation color.
        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.delegate = self
        self.textView = textView
        textOrigin = origin
        addSubview(textView)
        styleTextView(textView)
        window?.makeFirstResponder(textView)
    }

    private func styleTextView(_ textView: NSTextView) {
        let font = Renderer.font(for: document.width, pointScale: document.pointScale * scale) as NSFont
        let color = NSColor(cgColor: document.color.cgColor) ?? .systemRed
        // Fix the line height so lines match the renderer's spacing exactly.
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = Renderer.lineHeight(for: font)
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
        ]
        textView.textStorage?.setAttributes(attributes, range: NSRange(location: 0, length: textView.string.utf16.count))
        textView.insertionPointColor = color
        textView.typingAttributes = attributes
        layoutTextView(textView)
    }

    /// Sizes the text view to fit its text and puts its first baseline where the text will render.
    private func layoutTextView(_ textView: NSTextView) {
        guard let font = textView.typingAttributes[.font] as? NSFont else { return }
        let lines = textView.string.split(separator: "\n", omittingEmptySubsequences: false)
        let textWidth = lines.map { (String($0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let lineHeight = Renderer.lineHeight(for: font)
        let height = ceil(lineHeight * CGFloat(max(lines.count, 1)))
        let baseline = CGPoint(x: textOrigin.x * scale, y: textOrigin.y * scale)
        textView.frame = CGRect(
            x: baseline.x,
            // NSTextView is flipped: its first baseline sits `ascender` below its top edge.
            y: baseline.y + font.ascender - height,
            width: ceil(textWidth) + font.pointSize, // Room for the caret and the next glyph.
            height: height
        )
    }

    /// Turns the text being edited into an annotation. Empty text is dropped.
    func commitText() {
        guard let textView else { return }
        self.textView = nil // Set first: removing the view re-enters via textDidEndEditing.
        let string = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        textView.removeFromSuperview()
        if window?.firstResponder == nil || window?.firstResponder === window {
            window?.makeFirstResponder(self)
        }
        guard !string.isEmpty else { return }
        document.add(Annotation(
            shape: .text(string, origin: textOrigin),
            color: document.color,
            width: document.width
        ))
    }

    func textDidChange(_ notification: Notification) {
        if let textView { layoutTextView(textView) }
    }

    func textDidEndEditing(_ notification: Notification) {
        commitText()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:))
            where NSApp.currentEvent?.modifierFlags.contains(.shift) == true:
            // ⇧↩ adds a line (⌥↩ already does, via insertNewlineIgnoringFieldEditor).
            textView.insertNewlineIgnoringFieldEditor(nil)
            return true
        case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.cancelOperation(_:)):
            window?.makeFirstResponder(self)
            return true
        default:
            return false
        }
    }
}
