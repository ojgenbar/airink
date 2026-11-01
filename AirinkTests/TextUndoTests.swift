import AppKit
import Testing
@testable import Airink

@MainActor
struct TextUndoTests {
    private func click(_ canvas: CanvasView, in window: NSWindow) throws {
        let event = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: CGPoint(x: 50, y: 50), modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        canvas.mouseDown(with: event)
    }

    private func textView(in canvas: CanvasView) throws -> NSTextView {
        try #require(canvas.subviews.compactMap { $0 as? NSTextView }.first)
    }

    /// Typing history lives on the window's undo manager and points at the text view,
    /// so it must not outlive it: ⌘Z in the next text field would call a freed object.
    @Test func committedTextLeavesNoTypingHistoryBehind() throws {
        let context = try #require(CGContext(
            data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let document = AnnotationDocument(image: try #require(context.makeImage()), pointScale: 1, tool: .text)
        let window = EditorWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300))
        let canvas = CanvasView(document: document)
        canvas.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        window.contentView = canvas
        defer { window.close() }

        try autoreleasepool {
            try click(canvas, in: window)
            let first = try textView(in: canvas)
            first.insertText("hello", replacementRange: NSRange(location: 0, length: 0))
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            #expect(first.undoManager?.canUndo == true) // Undo works while typing.
            try click(canvas, in: window) // Commits the first text, starts a second one.
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        #expect(document.annotations.count == 1)
        let second = try textView(in: canvas)
        #expect(second.undoManager?.canUndo == false)
        if second.undoManager?.canUndo == true { second.undoManager?.undo() } // Crashed here.
    }
}
