import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Background pictures, kept in the App Group container so the widgets can read them.
///
/// Widgets cannot read the photo library, and they refuse images much larger than they draw.
/// So a chosen picture is copied in once, scaled so its longer side is at most `maxPixels`.
enum BackgroundImageStore {
    static let maxPixels = 1000

    /// The folder in the App Group container, or a folder in Application Support if the
    /// container is unavailable, such as in a build without the entitlement.
    static var directory: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedSettings.appGroup)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Backgrounds", isDirectory: true)
    }

    /// Scales `data` (any image format ImageIO reads, including HEIC) and saves it as a JPEG.
    /// Returns the new file's name, which is what `Appearance.Background.image` stores.
    static func importImage(_ data: Data) throws -> String {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            ] as CFDictionary)
        else {
            throw StoreError("That file is not an image this app can read.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(name)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw StoreError("The picture could not be saved.")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw StoreError("The picture could not be saved.")
        }
        return name
    }

    static func load(_ name: String) -> CGImage? {
        let url = directory.appendingPathComponent(name)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Deletes every stored picture except `keeping`, so replaced backgrounds do not pile up.
    static func removeAll(except keeping: String?) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where file != keeping {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    struct StoreError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
