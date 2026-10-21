import CoreImage
import CoreVideo
import ImageIO

/// Carries an HDR gain map (Apple HDRGainMap or ISO 21496-1) from the source to the output.
///
/// The gain map's pixels get exactly the same orientation, rotate/flip and (scaled) crop as the base image,
/// and its metadata is rebuilt from a whitelist of technical HDR parameters only (version, headroom,
/// gain-map min/max, gamma, offsets). Nothing else from the source is kept.
struct GainMapTransfer {
    let auxiliaryType: CFString
    let info: [CFString: Any]

    /// Only these namespaces (all purely technical HDR tone-mapping parameters) survive.
    private static let allowedPrefixes: Set<String> = ["HDRGainMap", "HDRToneMap", "hdrgm"]
    private static let allowedAppleTags: Set<String> = ["HDRGainMapVersion", "HDRGainMapHeadroom"]
    /// Shared renderer for gain-map geometry (CIContext is thread-safe and costly to create).
    private static let context = CIContext(options: [.workingFormat: CIFormat.RGBAf, .cacheIntermediates: false])

    static func read(from source: CGImageSource, index: Int) -> GainMapTransfer? {
        var types: [CFString] = []
        if #available(macOS 15.0, *) { types.append(kCGImageAuxiliaryDataTypeISOGainMap) }
        types.append(kCGImageAuxiliaryDataTypeHDRGainMap)
        for type in types {
            if let info = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, index, type) as? [CFString: Any] {
                return GainMapTransfer(auxiliaryType: type, info: info)
            }
        }
        return nil
    }

    /// Returns the transformed auxiliary info ready for `CGImageDestinationAddAuxiliaryDataInfo`,
    /// or nil if the gain map's pixel format isn't one we can safely transform.
    func transformed(geometry: ImageFrameGeometry, baseUprightSize: CGSize, baseCrop: CGRect?) -> [CFString: Any]? {
        guard let data = info[kCGImageAuxiliaryDataInfoData] as? Data,
              let description = info[kCGImageAuxiliaryDataInfoDataDescription] as? [CFString: Any],
              let width = description[kCGImagePropertyWidth] as? Int,
              let height = description[kCGImagePropertyHeight] as? Int,
              let bytesPerRow = description[kCGImagePropertyBytesPerRow] as? Int,
              let pixelFormat = (description[kCGImagePropertyPixelFormat] as? NSNumber)?.uint32Value,
              let layout = Self.layout(for: pixelFormat),
              width > 0, height > 0,
              bytesPerRow >= width * layout.bytesPerPixel,   // a short stride would make Core Image read past the buffer
              data.count >= bytesPerRow * height else { return nil }

        var newData = data, newWidth = width, newHeight = height, newBytesPerRow = bytesPerRow
        if !geometry.isIdentity {
            let image = CIImage(bitmapData: data, bytesPerRow: bytesPerRow, size: CGSize(width: width, height: height),
                                format: layout.format, colorSpace: nil)
            var upright = geometry.upright(image)
            if let baseCrop {
                let rect = ImageFrameGeometry.scale(baseCrop, from: baseUprightSize, to: upright.extent.size)
                upright = ImageFrameGeometry.crop(upright, to: rect)
            }
            newWidth = Int(upright.extent.width.rounded())
            newHeight = Int(upright.extent.height.rounded())
            newBytesPerRow = newWidth * layout.bytesPerPixel
            var buffer = Data(count: newBytesPerRow * newHeight)
            buffer.withUnsafeMutableBytes { pointer in
                guard let base = pointer.baseAddress else { return }
                Self.context.render(upright, toBitmap: base, rowBytes: newBytesPerRow,
                               bounds: CGRect(x: 0, y: 0, width: newWidth, height: newHeight), format: layout.format, colorSpace: nil)
            }
            newData = buffer
        }

        var result: [CFString: Any] = [
            kCGImageAuxiliaryDataInfoData: newData,
            kCGImageAuxiliaryDataInfoDataDescription: [
                kCGImagePropertyWidth: newWidth,
                kCGImagePropertyHeight: newHeight,
                kCGImagePropertyBytesPerRow: newBytesPerRow,
                kCGImagePropertyPixelFormat: pixelFormat,
            ] as [CFString: Any],
        ]
        if let metadata = Self.technicalMetadata(info[kCGImageAuxiliaryDataInfoMetadata]) {
            result[kCGImageAuxiliaryDataInfoMetadata] = metadata
        }
        if #available(macOS 15.0, *), let value = info[kCGImageAuxiliaryDataInfoColorSpace],
           CFGetTypeID(value as CFTypeRef) == CGColorSpace.typeID {
            // The ISO "alternate" (HDR) colour space: re-embed the equivalent standard space.
            // The type ID is checked first, so this CF downcast cannot fail.
            let colorSpace = value as! CGColorSpace
            result[kCGImageAuxiliaryDataInfoColorSpace] = ColorSpaceStandardizer.standardize(colorSpace).colorSpace
        }
        return result
    }

    // MARK: Pixel formats

    private struct Layout { let format: CIFormat; let bytesPerPixel: Int }

    private static func layout(for pixelFormat: UInt32) -> Layout? {
        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8: Layout(format: .L8, bytesPerPixel: 1)
        case kCVPixelFormatType_OneComponent16: Layout(format: .L16, bytesPerPixel: 2)
        case kCVPixelFormatType_OneComponent16Half: Layout(format: .Lh, bytesPerPixel: 2)
        case kCVPixelFormatType_OneComponent32Float: Layout(format: .Lf, bytesPerPixel: 4)
        case kCVPixelFormatType_32BGRA: Layout(format: .BGRA8, bytesPerPixel: 4)
        case kCVPixelFormatType_32RGBA: Layout(format: .RGBA8, bytesPerPixel: 4)
        case kCVPixelFormatType_64RGBAHalf: Layout(format: .RGBAh, bytesPerPixel: 8)
        default: nil
        }
    }

    // MARK: Metadata whitelist

    private static func technicalMetadata(_ value: Any?) -> CGImageMetadata? {
        guard let value, CFGetTypeID(value as CFTypeRef) == CGImageMetadataGetTypeID() else { return nil }
        let source = value as! CGImageMetadata   // type ID checked above, so this CF downcast cannot fail
        guard let tags = CGImageMetadataCopyTags(source) as? [CGImageMetadataTag] else { return nil }
        let result = CGImageMetadataCreateMutable()
        var count = 0
        for tag in tags {
            guard let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
                  let name = CGImageMetadataTagCopyName(tag) as String?,
                  let namespace = CGImageMetadataTagCopyNamespace(tag),
                  allowedPrefixes.contains(prefix),
                  prefix != "HDRGainMap" || allowedAppleTags.contains(name) else { continue }
            CGImageMetadataRegisterNamespaceForPrefix(result, namespace, prefix as CFString, nil)
            if CGImageMetadataSetTagWithPath(result, nil, "\(prefix):\(name)" as CFString, tag) { count += 1 }
        }
        return count > 0 ? result : nil
    }
}
