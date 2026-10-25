import CoreGraphics
import Foundation
import Observation

/// The editing session for one clipboard image. Discarded when the editor closes.
@Observable
final class AnnotationDocument {
    let image: CGImage
    let pointScale: CGFloat

    private(set) var annotations: [Annotation] = [] {
        didSet { onChange?() }
    }

    /// Mirrors `undoManager` (which isn't observable) for the toolbar buttons.
    private(set) var canUndo = false
    private(set) var canRedo = false

    var tool: Tool { didSet { onChange?() } }
    var color: AnnotationColor { didSet { onChange?() } }
    var width: StrokeWidth { didSet { onChange?() } }

    @ObservationIgnored let undoManager = UndoManager()
    /// Called after any change; the canvas uses it to redraw.
    @ObservationIgnored var onChange: (() -> Void)?

    init(
        image: CGImage,
        pointScale: CGFloat,
        tool: Tool = .arrow,
        color: AnnotationColor = .red,
        width: StrokeWidth = .medium
    ) {
        self.image = image
        self.pointScale = pointScale
        self.tool = tool
        self.color = color
        self.width = width
        // Explicit grouping keeps one undo step per annotation, independent of the run loop.
        undoManager.groupsByEvent = false
    }

    var imageSize: CGSize { CGSize(width: image.width, height: image.height) }

    func add(_ annotation: Annotation) {
        insert(annotation, at: annotations.count)
        refreshUndoState()
    }

    func undo() {
        if undoManager.canUndo { undoManager.undo() }
        refreshUndoState()
    }

    func redo() {
        if undoManager.canRedo { undoManager.redo() }
        refreshUndoState()
    }

    private func refreshUndoState() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
    }

    private func insert(_ annotation: Annotation, at index: Int) {
        annotations.insert(annotation, at: index)
        registerUndo { $0.remove(id: annotation.id) }
    }

    private func remove(id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let removed = annotations.remove(at: index)
        registerUndo { $0.insert(removed, at: index) }
    }

    private func registerUndo(_ handler: @escaping (AnnotationDocument) -> Void) {
        let isReplaying = undoManager.isUndoing || undoManager.isRedoing
        if !isReplaying { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self, handler: handler)
        if !isReplaying { undoManager.endUndoGrouping() }
    }
}
