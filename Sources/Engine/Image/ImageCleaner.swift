import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Strips all metadata from images by decoding to pixels and encoding a brand-new file.
///
/// Only pixels (plus, optionally, the HDR gain map) are carried over. EXIF/GPS/TIFF/IPTC/XMP, maker notes,
/// thumbnails, C2PA/JUMBF manifests, PNG text chunks, depth maps, portrait mattes and Live Photo identifiers
/// never reach the output. EXIF orientation is baked into the pixels. Bit depth is preserved where the output
/// format allows it, and the colour space is re-embedded as Apple's standard profile for that space.
enum ImageCleaner {
    static let defaultQuality = 0.92

    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "jpe", "heic", "heif", "hif", "png", "tif", "tiff", "webp", "gif", "avif", "bmp",
        "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2", "pef", "srw", "raw",
    ]

    static func isImage(_ url: URL) -> Bool {
        if imageExtensions.contains(url.pathExtension.lowercased()) { return true }
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private static let avif = UTType("public.avif")

    /// Output type for a source type. ImageIO cannot write WebP, so WebP becomes lossless PNG; RAW and
    /// other formats become JPEG.
    static func outputType(for sourceType: UTType?, format: ImageOutputFormat) -> (type: UTType, fileExtension: String) {
        guard format == .original, let sourceType else { return (.jpeg, "jpg") }
        if sourceType.conforms(to: .jpeg) { return (.jpeg, "jpg") }
        if sourceType.conforms(to: .heic) || sourceType.conforms(to: .heif) { return (.heic, "heic") }
        if let avif, sourceType.conforms(to: avif) { return (avif, "avif") }
        if sourceType.conforms(to: .png) { return (.png, "png") }
        if sourceType.conforms(to: .tiff) && !sourceType.conforms(to: .rawImage) { return (.tiff, "tiff") }
        if sourceType.conforms(to: .gif) { return (.gif, "gif") }
        if sourceType.conforms(to: .webP) { return (.png, "png") }
        return (.jpeg, "jpg")
    }

    @concurrent
    static func clean(_ input: URL, outputDirectory: URL, format: ImageOutputFormat,
                      quality: Double = defaultQuality, keepHDR: Bool = true, edit: ImageEdit = ImageEdit()) async throws -> URL {
        let name = input.lastPathComponent
        guard let source = CGImageSourceCreateWithURL(input as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) > 0 else {
            throw CleanError("\(name): not a readable image")
        }
        let sourceType = (CGImageSourceGetType(source) as String?).flatMap { UTType($0) }
        let (outputType, fileExtension) = outputType(for: sourceType, format: format)
        let frameCount = CGImageSourceGetCount(source)
        let isAnimatedGIF = outputType == .gif && frameCount > 1
        let primary = CGImageSourceGetPrimaryImageIndex(source)
        let target = OutputTarget(type: outputType, quality: quality)

        var frames: [EncodedFrame] = []
        if isAnimatedGIF {
            for index in 0..<frameCount {
                try Task.checkCancellation()
                let decoded = try decode(source, index: index, request: nil, name: name)
                var frame = try render(decoded, geometry: decoded.geometry(edit), target: target, name: name)
                frame.gifDelay = gifDelay(source: source, index: index)
                frames.append(frame)
            }
        } else {
            frames.append(try encodePrimary(source, index: primary, target: target, keepHDR: keepHDR, edit: edit, name: name))
        }
        try Task.checkCancellation()

        let output = try OutputNaming.newURL(in: outputDirectory, fileExtension: fileExtension)
        do {
            try write(frames, to: output, target: target, loopCount: isAnimatedGIF ? gifLoopCount(source) : nil)
            try ContainerSanitizer.sanitize(output)
            try Task.checkCancellation()
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        FileScrubber.scrub(output)
        return output
    }

    // MARK: Routing

    private static func encodePrimary(_ source: CGImageSource, index: Int, target: OutputTarget, keepHDR: Bool,
                                      edit: ImageEdit, name: String) throws -> EncodedFrame {
        let gainMap = GainMapTransfer.read(from: source, index: index)
        let plain = try decode(source, index: index, request: nil, name: name)
        let isEncodedHDR = ColorSpaceStandardizer.isHDR(plain.image.colorSpace)
        let geometry = plain.geometry(edit)

        guard keepHDR else {
            // Flatten to SDR: tone-map PQ/HLG; for gain-map images the base image already is the SDR rendition.
            guard isEncodedHDR else { return try render(plain, geometry: geometry, target: target, name: name) }
            if plain.image.bitsPerComponent > 8, target.supportsHighBitDepthLossy || !target.isEightBitOnly,
               let toneMapped = toneMappedToSDR(source, index: index, plain: plain) {
                return try render(toneMapped, geometry: geometry, target: target, name: name)
            }
            let sdr = try decode(source, index: index, request: kCGImageSourceDecodeToSDR, name: name)
            return try render(sdr, geometry: geometry, target: target, name: name)
        }

        if let gainMap, target.supportsGainMap {
            var frame = try render(plain, geometry: geometry, target: target, name: name)
            let uprightBase = plain.uprightSize(geometry)
            let crop = geometry.cropRect(uprightWidth: Int(uprightBase.width), uprightHeight: Int(uprightBase.height))
            if let info = gainMap.transformed(geometry: geometry, baseUprightSize: uprightBase, baseCrop: crop) {
                frame.auxiliary = (gainMap.auxiliaryType, info)
                return frame
            }
            // Unusual gain-map pixel format: rebuild an ISO gain map from the HDR rendition instead.
            if let rebuilt = try encodeAsISOGainMap(source, index: index, geometry: geometry, target: target, name: name) { return rebuilt }
            return frame
        }

        if isEncodedHDR && !target.supportsHDREncoding {
            // PQ/HLG source written as JPEG: keep HDR as an ISO gain map (Ultra HDR) instead.
            if let rebuilt = try encodeAsISOGainMap(source, index: index, geometry: geometry, target: target, name: name) { return rebuilt }
            let sdr = try decode(source, index: index, request: kCGImageSourceDecodeToSDR, name: name)
            return try render(sdr, geometry: geometry, target: target, name: name)
        }

        return try render(plain, geometry: geometry, target: target, name: name)
    }

    /// Decodes the HDR rendition and lets ImageIO encode an SDR base plus an ISO 21496-1 gain map.
    private static func encodeAsISOGainMap(_ source: CGImageSource, index: Int, geometry: ImageFrameGeometry,
                                           target: OutputTarget, name: String) throws -> EncodedFrame? {
        guard #available(macOS 15.0, *), target.supportsGainMap else { return nil }
        let hdr = try decode(source, index: index, request: kCGImageSourceDecodeToHDR, name: name)
        let headroom = hdr.image.contentHeadroom
        guard headroom > 1 else { return nil }
        let working = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        var image = CIImage(cgImage: hdr.image)
        image = geometry.upright(image)
        if let crop = geometry.cropRect(uprightWidth: Int(image.extent.width.rounded()), uprightHeight: Int(image.extent.height.rounded())) {
            image = ImageFrameGeometry.crop(image, to: crop)
        }
        guard let working, let rendered = context.createCGImage(image, from: image.extent, format: .RGBAh, colorSpace: working),
              let withHeadroom = CGImage.copy(rendered, contentHeadroom: headroom) else {
            throw CleanError("\(name): could not render HDR image")
        }
        return EncodedFrame(image: withHeadroom, encodeToISOGainMap: true)
    }

    /// Tone-maps a PQ/HLG image to SDR at 16 bits per channel so a 10/12-bit source keeps its precision.
    private static func toneMappedToSDR(_ source: CGImageSource, index: Int, plain: Decoded) -> Decoded? {
        guard #available(macOS 15.0, *),
              let hdr = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR] as CFDictionary),
              let filter = CIFilter(name: "CIToneMapHeadroom"),
              let sdrSpace = CGColorSpace(name: CGColorSpace.displayP3) else { return nil }
        filter.setValue(CIImage(cgImage: plain.image), forKey: kCIInputImageKey)
        filter.setValue(max(1, hdr.contentHeadroom), forKey: "inputSourceHeadroom")
        filter.setValue(1, forKey: "inputTargetHeadroom")
        guard let output = filter.outputImage,
              let rendered = context.createCGImage(output, from: output.extent, format: .RGBA16, colorSpace: sdrSpace) else { return nil }
        return Decoded(image: rendered, orientation: plain.orientation, isFloat: false, isGray: false)
    }

    // MARK: Decoding

    private struct Decoded {
        let image: CGImage
        let orientation: CGImagePropertyOrientation
        let isFloat: Bool
        let isGray: Bool

        func geometry(_ edit: ImageEdit) -> ImageFrameGeometry { ImageFrameGeometry(orientation: orientation, edit: edit) }

        func uprightSize(_ geometry: ImageFrameGeometry) -> CGSize {
            let swapsOrientation = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
            let size = swapsOrientation ? CGSize(width: image.height, height: image.width) : CGSize(width: image.width, height: image.height)
            return ImageGeometry.rotatedSize(size, quarterTurns: geometry.edit.normalizedQuarterTurns)
        }
    }

    private static func decode(_ source: CGImageSource, index: Int, request: CFString?, name: String) throws -> Decoded {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32).flatMap(CGImagePropertyOrientation.init) ?? .up
        let isFloat = (properties[kCGImagePropertyIsFloat] as? Bool) ?? false
        var options: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: true, kCGImageSourceShouldAllowFloat: isFloat]
        if let request { options[kCGImageSourceDecodeRequest] = request }
        guard let image = CGImageSourceCreateImageAtIndex(source, index, options as CFDictionary) else {
            throw CleanError("\(name): could not decode image")
        }
        return Decoded(image: image, orientation: orientation, isFloat: isFloat || image.bitmapInfo.contains(.floatComponents),
                       isGray: image.colorSpace?.model == .monochrome)
    }

    // MARK: Rendering

    private static let context = CIContext(options: [.workingFormat: CIFormat.RGBAf, .cacheIntermediates: false])

    private static func render(_ decoded: Decoded, geometry: ImageFrameGeometry, target: OutputTarget, name: String) throws -> EncodedFrame {
        let source = decoded.image
        let standard = ColorSpaceStandardizer.standardize(source.colorSpace)
        let hasAlpha = source.hasAlpha && target.supportsAlpha
        let keepGray = decoded.isGray && target.type != .gif
        let colorSpace = keepGray ? standard.colorSpace : (standard.colorSpace.model == .rgb ? standard.colorSpace : rgbFallback)
        let pixel = PixelLayout(sourceBits: source.bitsPerComponent, isFloat: decoded.isFloat, target: target,
                                gray: keepGray && colorSpace.model == .monochrome, alpha: hasAlpha)

        // Fast path: nothing to transform and the colourimetry already matches a standard space —
        // retag with Apple's profile and keep the decoded pixels bit-for-bit.
        if geometry.isIdentity, standard.isExactMatch, colorSpace === standard.colorSpace,
           pixel.matches(source), !(source.hasAlpha && !target.supportsAlpha),
           let retagged = source.copy(colorSpace: colorSpace) {
            return EncodedFrame(image: retagged, sourceBits: source.bitsPerComponent)
        }

        // When the colourimetry matches a standard space, work in that exact space so pixels round-trip losslessly.
        // Already in a standard space: do the geometry losslessly with Core Graphics (Core Image would
        // round 16-bit/float values through half-float textures).
        if standard.isExactMatch, colorSpace === standard.colorSpace, !(source.hasAlpha && !hasAlpha),
           let lossless = geometry.renderLossless(source, bitsPerComponent: pixel.bits, isFloat: pixel.isFloat,
                                                  alpha: hasAlpha, colorSpace: colorSpace) {
            return EncodedFrame(image: lossless, sourceBits: source.bitsPerComponent)
        }

        var image = geometry.upright(CIImage(cgImage: source))
        let width = Int(image.extent.width.rounded()), height = Int(image.extent.height.rounded())
        if let crop = geometry.cropRect(uprightWidth: width, uprightHeight: height) {
            image = ImageFrameGeometry.crop(image, to: crop)
        }
        if source.hasAlpha && !hasAlpha {
            image = image.composited(over: CIImage(color: .white).cropped(to: image.extent))
        }
        guard let rendered = context.createCGImage(image, from: image.extent, format: pixel.ciFormat, colorSpace: colorSpace) else {
            throw CleanError("\(name): could not render image")
        }
        let final = hasAlpha || pixel.gray ? rendered : (opaqueCopy(rendered, colorSpace: colorSpace) ?? rendered)
        return EncodedFrame(image: final, sourceBits: source.bitsPerComponent)
    }

    private static let rgbFallback = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

    /// Drops the (fully opaque) alpha channel so the encoder writes an RGB file, keeping the bit depth.
    private static func opaqueCopy(_ image: CGImage, colorSpace: CGColorSpace) -> CGImage? {
        let bits = image.bitsPerComponent
        var info = CGImageAlphaInfo.noneSkipLast.rawValue
        if image.bitmapInfo.contains(.floatComponents) { info |= CGBitmapInfo.floatComponents.rawValue }
        if bits == 16 { info |= CGBitmapInfo.byteOrder16Little.rawValue } else if bits == 32 { info |= CGBitmapInfo.byteOrder32Little.rawValue }
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: bits, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: info) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    // MARK: Writing

    private static func write(_ frames: [EncodedFrame], to url: URL, target: OutputTarget, loopCount: Int?) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, target.type.identifier as CFString, frames.count, nil) else {
            throw CleanError("Could not create \(target.type.preferredFilenameExtension ?? "image") file")
        }
        if let loopCount {
            CGImageDestinationSetProperties(destination,
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]] as CFDictionary)
        }
        for frame in frames {
            // Only encoder settings — no metadata dictionaries are ever passed.
            var options: [CFString: Any] = [kCGImageDestinationEmbedThumbnail: false]
            if target.isLossy { options[kCGImageDestinationLossyCompressionQuality] = target.quality }
            if target.supportsHighBitDepthLossy && frame.image.bitsPerComponent > 8 && frame.sourceBits > 8 {
                options[kCGImagePropertyDepth] = 10
            }
            if let delay = frame.gifDelay { options[kCGImagePropertyGIFDictionary] = [kCGImagePropertyGIFDelayTime: delay] }
            if frame.encodeToISOGainMap, #available(macOS 15.0, *) {
                options[kCGImageDestinationEncodeRequest] = kCGImageDestinationEncodeToISOGainmap
            }
            CGImageDestinationAddImage(destination, frame.image, options as CFDictionary)
            if let (type, info) = frame.auxiliary {
                CGImageDestinationAddAuxiliaryDataInfo(destination, type, info as CFDictionary)
            }
        }
        guard CGImageDestinationFinalize(destination) else { throw CleanError("Could not write image") }
    }

    private static func gifDelay(source: CGImageSource, index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        return (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
    }

    private static func gifLoopCount(_ source: CGImageSource) -> Int {
        let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        return gif?[kCGImagePropertyGIFLoopCount] as? Int ?? 0
    }
}
