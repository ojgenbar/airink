import AppKit
import ImageIO
import UniformTypeIdentifiers

/// An image read from the pasteboard, at full pixel resolution.
nonisolated struct ClipboardImage: @unchecked Sendable {
    let cgImage: CGImage
    /// Pixels per point (2 for a Retina screenshot), derived from the image's DPI metadata.
    let pointScale: CGFloat
}

/// Reads and writes images on a pasteboard. Never called except in direct response to the user.
enum Clipboard {
    enum ReadError: Error, Equatable {
        case noImage
        /// The user has set Airink to "Deny" in System Settings › Privacy & Security › Paste from Other Apps.
        case accessDenied
    }

    private static let imageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        NSPasteboard.PasteboardType(UTType.jpeg.identifier),
        NSPasteboard.PasteboardType(UTType.heic.identifier),
    ]

    static func readImage(from pasteboard: NSPasteboard = .general) -> Result<ClipboardImage, ReadError> {
        if pasteboard.accessBehavior == .alwaysDeny { return .failure(.accessDenied) }
        // Checking available types inspects metadata only; reading the data below is what
        // triggers the system's paste-permission prompt on first use.
        guard let type = pasteboard.availableType(from: imageTypes) else { return .failure(.noImage) }
        guard let data = pasteboard.data(forType: type) else {
            return .failure(pasteboard.accessBehavior == .alwaysDeny ? .accessDenied : .noImage)
        }
        guard let image = decode(data) else { return .failure(.noImage) }
        return .success(image)
    }

    @discardableResult
    static func write(_ image: CGImage, pointScale: CGFloat, to pasteboard: NSPasteboard = .general) -> Bool {
        guard let data = pngData(image, pointScale: pointScale) else { return false }
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: .png)
    }

    nonisolated static func decode(_ data: Data) -> ClipboardImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let dpi = (properties?[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 72
        let scale = min(max((dpi / 72).rounded(), 1), 4)
        return ClipboardImage(cgImage: image, pointScale: scale)
    }

    nonisolated static func pngData(_ image: CGImage, pointScale: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        let dpi = 72 * pointScale
        let properties: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
