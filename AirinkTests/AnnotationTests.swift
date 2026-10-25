import CoreGraphics
import Testing
@testable import Airink

struct AnnotationShapeTests {
    @Test func shortDragsAreIgnored() {
        let shape = Annotation.Shape.make(
            tool: .line, from: .zero, to: CGPoint(x: 1, y: 1), constrained: false, minimumLength: 3
        )
        #expect(shape == nil)
    }

    @Test func constrainedLineSnapsTo45Degrees() throws {
        let shape = try #require(Annotation.Shape.make(
            tool: .line, from: .zero, to: CGPoint(x: 100, y: 90), constrained: true, minimumLength: 3
        ))
        guard case let .line(_, end) = shape else { Issue.record("expected line"); return }
        #expect(abs(end.x - end.y) < 0.001)
    }

    @Test func constrainedLineSnapsToHorizontal() throws {
        let shape = try #require(Annotation.Shape.make(
            tool: .arrow, from: .zero, to: CGPoint(x: 100, y: 8), constrained: true, minimumLength: 3
        ))
        guard case let .arrow(_, end) = shape else { Issue.record("expected arrow"); return }
        #expect(abs(end.y) < 0.001)
    }

    @Test func rectangleIsStandardizedForAnyDragDirection() {
        let shape = Annotation.Shape.make(
            tool: .rectangle, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 10, y: 20),
            constrained: false, minimumLength: 3
        )
        #expect(shape == .rectangle(CGRect(x: 10, y: 20, width: 40, height: 30)))
    }

    @Test func constrainedRectangleIsSquare() {
        let shape = Annotation.Shape.make(
            tool: .rectangle, from: .zero, to: CGPoint(x: 40, y: -10), constrained: true, minimumLength: 3
        )
        #expect(shape == .rectangle(CGRect(x: 0, y: -40, width: 40, height: 40)))
    }

    @Test func textToolDoesNotDrag() {
        let shape = Annotation.Shape.make(
            tool: .text, from: .zero, to: CGPoint(x: 50, y: 50), constrained: false, minimumLength: 3
        )
        #expect(shape == nil)
    }
}

@MainActor
struct AnnotationDocumentTests {
    private func makeDocument() throws -> AnnotationDocument {
        AnnotationDocument(image: try TestImages.solid(width: 20, height: 10), pointScale: 1)
    }

    private func line(_ x: CGFloat) -> Annotation {
        Annotation(shape: .line(from: .zero, to: CGPoint(x: x, y: 0)), color: .red, width: .medium)
    }

    @Test func undoAndRedoStepThroughAnnotations() throws {
        let document = try makeDocument()
        let first = line(5)
        let second = line(10)
        document.add(first)
        document.add(second)
        #expect(document.annotations == [first, second])

        document.undo()
        #expect(document.annotations == [first])
        document.undo()
        #expect(document.annotations.isEmpty)
        document.undo() // Nothing left; must not crash.

        document.redo()
        #expect(document.annotations == [first])
        document.redo()
        #expect(document.annotations == [first, second])
    }

    @Test func newEditClearsRedo() throws {
        let document = try makeDocument()
        document.add(line(5))
        document.undo()
        document.add(line(7))
        #expect(!document.undoManager.canRedo)
        #expect(document.annotations.count == 1)
    }

    @Test func notifiesOnChange() throws {
        let document = try makeDocument()
        var changes = 0
        document.onChange = { changes += 1 }
        document.add(line(5))
        document.tool = .text
        document.undo()
        #expect(changes == 3)
    }
}
