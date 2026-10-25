import AppKit
import Carbon.HIToolbox
import Testing
@testable import Airink

enum TestImages {
    struct CreationFailed: Error {}

    /// A white sRGB image of the given pixel size.
    static func solid(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw CreationFailed() }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw CreationFailed() }
        return image
    }

    /// Left half black, right half white.
    static func split(width: Int, height: Int) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw CreationFailed() }
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        guard let image = context.makeImage() else { throw CreationFailed() }
        return image
    }

    /// RGBA bytes of the pixel at (x, y), with y measured from the bottom.
    static func pixel(of image: CGImage, x: Int, y: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            context?.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        }
        return bytes
    }
}

struct RendererTests {
    @Test func outputKeepsFullResolution() throws {
        let image = try TestImages.solid(width: 300, height: 200)
        let output = try #require(Renderer.render(image: image, annotations: [], pointScale: 2))
        #expect(output.width == 300)
        #expect(output.height == 200)
    }

    @Test func drawsRectangleStrokeInAnnotationColor() throws {
        let image = try TestImages.solid(width: 100, height: 100)
        let rectangle = Annotation(
            shape: .rectangle(CGRect(x: 20, y: 20, width: 60, height: 60)), color: .blue, width: .thick
        )
        let output = try #require(Renderer.render(image: image, annotations: [rectangle], pointScale: 1))

        let onStroke = TestImages.pixel(of: output, x: 20, y: 50)
        #expect(onStroke[2] > 200 && onStroke[0] < 60) // Blue.
        let inside = TestImages.pixel(of: output, x: 50, y: 50)
        #expect(inside == [255, 255, 255, 255]) // Untouched.
    }

    @Test func lineWidthScalesWithPointScale() throws {
        let image = try TestImages.solid(width: 100, height: 100)
        let line = Annotation(shape: .line(from: CGPoint(x: 0, y: 50), to: CGPoint(x: 100, y: 50)), color: .black, width: .thin)
        // Thin = 2pt → 4px at 2x, so a pixel 1.5px off the centerline is covered only at 2x.
        let at1x = try #require(Renderer.render(image: image, annotations: [line], pointScale: 1))
        let at2x = try #require(Renderer.render(image: image, annotations: [line], pointScale: 2))
        #expect(TestImages.pixel(of: at1x, x: 50, y: 51)[0] > 200)
        #expect(TestImages.pixel(of: at2x, x: 50, y: 51)[0] < 50)
    }

    @Test func drawsText() throws {
        let image = try TestImages.solid(width: 200, height: 60)
        let text = Annotation(shape: .text("MMMM", origin: CGPoint(x: 10, y: 20)), color: .black, width: .thick)
        let output = try #require(Renderer.render(image: image, annotations: [text], pointScale: 1))
        let darkPixels = (10..<150).filter { TestImages.pixel(of: output, x: $0, y: 30)[0] < 100 }
        #expect(!darkPixels.isEmpty)
    }

    @Test func drawsEachLineOfMultilineTextBelowThePrevious() throws {
        let image = try TestImages.solid(width: 200, height: 200)
        let font = Renderer.font(for: .thick, pointScale: 1)
        let step = Renderer.lineHeight(for: font)
        let text = Annotation(shape: .text("MMMM\n\nMMMM", origin: CGPoint(x: 10, y: 160)), color: .black, width: .thick)
        let output = try #require(Renderer.render(image: image, annotations: [text], pointScale: 1))

        func hasInk(atBaseline y: CGFloat) -> Bool {
            (10..<150).contains { TestImages.pixel(of: output, x: $0, y: Int(y + 10))[0] < 100 }
        }
        #expect(hasInk(atBaseline: 160))
        #expect(!hasInk(atBaseline: 160 - step)) // Empty middle line.
        #expect(hasInk(atBaseline: 160 - 2 * step))
    }
}

struct PixelateTests {
    @Test func blocksAverageTheAreaUnderneath() throws {
        // A 20px block centered on the black/white edge averages to mid gray.
        let image = try TestImages.split(width: 100, height: 40)
        let mosaic = Annotation(shape: .pixelate(CGRect(x: 40, y: 0, width: 20, height: 20)), color: .red, width: .thick)
        let output = try #require(Renderer.render(image: image, annotations: [mosaic], pointScale: 1))

        for x in [42, 50, 58] {
            let pixel = TestImages.pixel(of: output, x: x, y: 10)
            #expect((90...170).contains(Int(pixel[0])), "x=\(x) value \(pixel[0])")
        }
        // Outside the area the image is untouched.
        #expect(TestImages.pixel(of: output, x: 45, y: 30)[0] < 10)
        #expect(TestImages.pixel(of: output, x: 80, y: 10)[0] > 245)
    }

    @Test func mosaicSamplesOriginalImageAndStaysUnderOtherAnnotations() throws {
        let image = try TestImages.solid(width: 100, height: 100)
        // Arrow drawn first, mosaic added afterwards on top of it.
        let line = Annotation(shape: .line(from: CGPoint(x: 0, y: 50), to: CGPoint(x: 100, y: 50)), color: .black, width: .thick)
        let mosaic = Annotation(shape: .pixelate(CGRect(x: 0, y: 0, width: 100, height: 100)), color: .red, width: .thick)
        let output = try #require(Renderer.render(image: image, annotations: [line, mosaic], pointScale: 1))

        #expect(TestImages.pixel(of: output, x: 50, y: 50)[0] < 50) // Line still visible.
        #expect(TestImages.pixel(of: output, x: 50, y: 10)[0] > 245) // Mosaic of white is white.
    }

    @Test func areaOutsideImageIsClipped() throws {
        let image = try TestImages.solid(width: 50, height: 50)
        let mosaic = Annotation(shape: .pixelate(CGRect(x: -100, y: -100, width: 120, height: 120)), color: .red, width: .medium)
        let output = try #require(Renderer.render(image: image, annotations: [mosaic], pointScale: 2))
        #expect(output.width == 50)
        #expect(TestImages.pixel(of: output, x: 5, y: 5)[0] > 245)
    }

    @Test func dragCreatesPixelateArea() {
        let shape = Annotation.Shape.make(
            tool: .pixelate, from: CGPoint(x: 30, y: 30), to: CGPoint(x: 10, y: 5), constrained: false, minimumLength: 3
        )
        #expect(shape == .pixelate(CGRect(x: 10, y: 5, width: 20, height: 25)))
    }
}

struct ClipboardTests {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("dev.airink.tests.\(UUID().uuidString)"))
    }

    @Test @MainActor func roundTripsImageAndScale() throws {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        let image = try TestImages.solid(width: 64, height: 32)
        #expect(Clipboard.write(image, pointScale: 2, to: pasteboard))

        let read = try Clipboard.readImage(from: pasteboard).get()
        #expect(read.cgImage.width == 64)
        #expect(read.cgImage.height == 32)
        #expect(read.pointScale == 2)
    }

    @Test @MainActor func reportsMissingImage() {
        let pasteboard = makePasteboard()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)
        #expect(throws: Clipboard.ReadError.noImage) { try Clipboard.readImage(from: pasteboard).get() }
    }

    @Test func missingDPIMeansOneToOne() throws {
        let image = try TestImages.solid(width: 8, height: 8)
        let data = try #require(Clipboard.pngData(image, pointScale: 1))
        #expect(Clipboard.decode(data)?.pointScale == 1)
    }
}

struct EditorLayoutTests {
    @Test func retinaScreenshotFitsWithoutUpscaling() {
        let size = EditorController.canvasSize(
            imagePoints: CGSize(width: 400, height: 300), fitting: CGSize(width: 1000, height: 800)
        )
        #expect(size == CGSize(width: 400, height: 300))
    }

    @Test func largeImageScalesDownPreservingAspect() {
        let size = EditorController.canvasSize(
            imagePoints: CGSize(width: 3000, height: 1000), fitting: CGSize(width: 1500, height: 800)
        )
        #expect(size == CGSize(width: 1500, height: 500))
    }
}

struct EditorCommandTests {
    @Test func mapsKeyboardShortcuts() {
        func command(_ keyCode: Int, _ flags: NSEvent.ModifierFlags = [], _ chars: String? = nil) -> EditorCommand? {
            EditorCommand(keyCode: UInt16(keyCode), modifierFlags: flags, characters: chars)
        }
        #expect(command(kVK_ANSI_C, .command, "c") == .copy)
        #expect(command(kVK_Return, [], "\r") == .copy)
        #expect(command(kVK_Escape, [], "\u{1b}") == .cancel)
        #expect(command(kVK_ANSI_Z, .command, "z") == .undo)
        #expect(command(kVK_ANSI_Z, [.command, .shift], "z") == .redo)
        #expect(command(kVK_ANSI_R, [], "r") == .tool(.rectangle))
        #expect(command(kVK_ANSI_3, [], "3") == .width(.thick))
        #expect(command(kVK_ANSI_P, [], "p") == .tool(.pixelate))
        #expect(command(kVK_ANSI_R, .option, "r") == nil)
        #expect(command(kVK_ANSI_Q, [], "q") == nil)
    }
}
