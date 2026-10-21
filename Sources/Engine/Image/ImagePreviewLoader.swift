import CoreImage
import Foundation
import ImageIO

/// Downsampled, orientation-corrected previews for thumbnails and the crop editor.
enum ImagePreviewLoader {
    struct Preview: Sendable {
        let image: CGImage
        /// Full-resolution size of the upright (orientation-corrected) image.
        let uprightSize: CGSize
    }

    /// Shared renderer for editor previews (CIContext is thread-safe and costly to create).
    private static let context = CIContext()

    @concurrent
    static func load(_ url: URL, maxPixelSize: Int) async -> Preview? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let index = CGImageSourceGetPrimaryImageIndex(source)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
        let width = properties[kCGImagePropertyPixelWidth] as? Double ?? Double(thumbnail.width)
        let height = properties[kCGImagePropertyPixelHeight] as? Double ?? Double(thumbnail.height)
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let upright = orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        return Preview(image: thumbnail, uprightSize: upright)
    }

    /// Applies the editor's rotation/flip to a preview image.
    @concurrent
    static func transformed(_ preview: Preview, quarterTurns: Int, flipHorizontal: Bool) async -> Preview {
        let image = ImageGeometry.apply(CIImage(cgImage: preview.image), quarterTurns: quarterTurns, flipHorizontal: flipHorizontal)
        let rendered = context.createCGImage(image, from: image.extent) ?? preview.image
        return Preview(image: rendered, uprightSize: ImageGeometry.rotatedSize(preview.uprightSize, quarterTurns: quarterTurns))
    }
}
