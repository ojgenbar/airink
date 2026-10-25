import AppKit
import SwiftUI

/// Owns the editor window for one annotation session. Everything image-related is
/// released when the window closes, so nothing large stays in memory while idle.
final class EditorController: NSObject, NSWindowDelegate {
    private static let toolbarHeight: CGFloat = 52
    /// Space around the image, so it isn't clipped by the window's rounded corners.
    private static let padding: CGFloat = 12
    private static let minimumWidth: CGFloat = 760

    private var window: EditorWindow?
    private var canvas: CanvasView?
    private var document: AnnotationDocument?

    var isOpen: Bool { window != nil }

    func open(_ clipboardImage: ClipboardImage) {
        let style = Style.load()
        let document = AnnotationDocument(
            image: clipboardImage.cgImage,
            pointScale: clipboardImage.pointScale,
            tool: style.tool,
            color: style.color,
            width: style.width
        )
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let canvasSize = Self.canvasSize(
            imagePoints: CGSize(
                width: document.imageSize.width / document.pointScale,
                height: document.imageSize.height / document.pointScale
            ),
            fitting: CGSize(
                width: visibleFrame.width * 0.9 - Self.padding * 2,
                height: visibleFrame.height * 0.9 - Self.toolbarHeight - Self.padding
            )
        )
        let contentSize = CGSize(
            width: max(canvasSize.width + Self.padding * 2, Self.minimumWidth),
            height: Self.toolbarHeight + canvasSize.height + Self.padding
        )

        let window = EditorWindow(contentRect: CGRect(origin: .zero, size: contentSize))
        let canvas = CanvasView(document: document)
        window.contentView = makeContentView(size: contentSize, canvasSize: canvasSize, document: document, canvas: canvas)
        window.delegate = self
        window.onCommand = { [weak self] in self?.perform($0) }
        window.isEditingText = { [weak canvas] in canvas?.isEditingText ?? false }
        window.setFrameOrigin(CGPoint(
            x: visibleFrame.midX - contentSize.width / 2,
            y: visibleFrame.midY - contentSize.height / 2
        ))

        self.window = window
        self.canvas = canvas
        self.document = document

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
    }

    func bringToFront() {
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Image size in points, scaled down (never up) to fit `bounds`.
    nonisolated static func canvasSize(imagePoints: CGSize, fitting bounds: CGSize) -> CGSize {
        guard imagePoints.width > 0, imagePoints.height > 0 else { return .zero }
        let factor = min(1, bounds.width / imagePoints.width, bounds.height / imagePoints.height)
        return CGSize(
            width: (imagePoints.width * factor).rounded(),
            height: (imagePoints.height * factor).rounded()
        )
    }

    private func makeContentView(
        size: CGSize,
        canvasSize: CGSize,
        document: AnnotationDocument,
        canvas: CanvasView
    ) -> NSView {
        let container = NSView(frame: CGRect(origin: .zero, size: size))

        let canvasFrame = CGRect(
            x: ((size.width - canvasSize.width) / 2).rounded(),
            y: Self.padding,
            width: canvasSize.width,
            height: canvasSize.height
        )
        let imageView = ImageLayerView(image: document.image)
        imageView.frame = canvasFrame
        canvas.frame = canvasFrame
        container.addSubview(imageView)
        container.addSubview(canvas)

        let toolbar = NSHostingView(rootView: EditorToolbar(
            document: document,
            onUndo: { [weak self] in self?.perform(.undo) },
            onRedo: { [weak self] in self?.perform(.redo) },
            onCancel: { [weak self] in self?.close() },
            onCopy: { [weak self] in self?.copyAndClose() }
        ))
        toolbar.sizingOptions = []
        // The title bar is hidden; don't let SwiftUI inset the toolbar for it.
        toolbar.safeAreaRegions = []
        toolbar.frame = CGRect(
            x: 0,
            y: size.height - Self.toolbarHeight,
            width: size.width,
            height: Self.toolbarHeight
        )
        container.addSubview(toolbar)
        return container
    }

    private func perform(_ command: EditorCommand) {
        guard let document else { return }
        switch command {
        case .copy: copyAndClose()
        case .cancel: close()
        case .undo:
            // Finish any text being typed first, so Undo removes it as one step.
            canvas?.commitText()
            document.undo()
        case .redo:
            canvas?.commitText()
            document.redo()
        case let .tool(tool): document.tool = tool
        case let .width(width): document.width = width
        }
    }

    func copyAndClose() {
        guard let document else { return }
        canvas?.commitText()
        guard let output = Renderer.render(
            image: document.image,
            annotations: document.annotations,
            pointScale: document.pointScale
        ), Clipboard.write(output, pointScale: document.pointScale) else {
            NSSound.beep()
            return
        }
        close()
    }

    /// Closes without touching the clipboard and returns focus to the previous app.
    func close() {
        window?.close() // Cleanup happens in windowWillClose.
    }

    func windowWillClose(_ notification: Notification) {
        if let document {
            Style(tool: document.tool, color: document.color, width: document.width).save()
            document.undoManager.removeAllActions()
            document.onChange = nil
        }
        window?.delegate = nil
        window = nil
        canvas = nil
        document = nil
        NSApp.hide(nil)
    }
}

// MARK: - Remembered tool style

private extension EditorController {
    /// The last-used tool, color and width, restored for the next session.
    struct Style {
        var tool: Tool
        var color: AnnotationColor
        var width: StrokeWidth

        static func load(from defaults: UserDefaults = .standard) -> Style {
            Style(
                tool: defaults.string(forKey: "tool").flatMap(Tool.init(rawValue:)) ?? .arrow,
                color: defaults.string(forKey: "color").flatMap(AnnotationColor.init(rawValue:)) ?? .red,
                width: StrokeWidth(rawValue: defaults.integer(forKey: "width")) ?? .medium
            )
        }

        func save(to defaults: UserDefaults = .standard) {
            defaults.set(tool.rawValue, forKey: "tool")
            defaults.set(color.rawValue, forKey: "color")
            defaults.set(width.rawValue, forKey: "width")
        }
    }
}
