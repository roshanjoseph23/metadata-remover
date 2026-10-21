import CoreImage
import ImageIO

/// The geometry applied to a frame: EXIF orientation, then the user's rotate/flip, then the crop.
/// Shared by the base image and its gain map so both stay aligned.
struct ImageFrameGeometry: Sendable {
    let orientation: CGImagePropertyOrientation
    let edit: ImageEdit

    var isIdentity: Bool { orientation == .up && edit.isIdentity }

    /// Orients and rotates/flips `image`, returning it with its origin at (0, 0).
    func upright(_ image: CIImage) -> CIImage {
        let oriented = image.oriented(orientation)
        return ImageGeometry.apply(oriented.transformed(by: CGAffineTransform(translationX: -oriented.extent.minX, y: -oriented.extent.minY)),
                                   quarterTurns: edit.quarterTurns, flipHorizontal: edit.flipHorizontal)
    }

    /// The crop in upright pixels (top-left origin), or nil for no crop.
    func cropRect(uprightWidth: Int, uprightHeight: Int) -> CGRect? {
        edit.crop?.pixelRect(width: uprightWidth, height: uprightHeight)
    }

    /// Crops an upright image to `rect` (top-left origin), returning it with its origin at (0, 0).
    static func crop(_ image: CIImage, to rect: CGRect) -> CIImage {
        let height = image.extent.height
        let ciRect = CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
        return image.cropped(to: ciRect).transformed(by: CGAffineTransform(translationX: -ciRect.minX, y: -ciRect.minY))
    }

    /// Scales a base-image crop rect into another image's upright pixel space (e.g. a half-size gain map).
    static func scale(_ rect: CGRect, from base: CGSize, to other: CGSize) -> CGRect {
        let sx = other.width / base.width, sy = other.height / base.height
        let scaled = CGRect(x: rect.minX * sx, y: rect.minY * sy, width: rect.width * sx, height: rect.height * sy)
        let bounds = CGRect(origin: .zero, size: other)
        let integral = scaled.integral.intersection(bounds)
        return integral.isNull || integral.width < 1 || integral.height < 1 ? bounds : integral
    }
}

extension ImageFrameGeometry {
    /// Lossless geometry with Core Graphics: whole-pixel quarter turns, flips and an integral crop,
    /// drawn without interpolation or colour conversion, so 16-bit and float values pass through exactly.
    /// Returns nil when Core Graphics can't create a matching bitmap (the caller then uses Core Image).
    func renderLossless(_ image: CGImage, bitsPerComponent: Int, isFloat: Bool, alpha: Bool, colorSpace: CGColorSpace) -> CGImage? {
        let (mirrorFirst, orientationTurns) = Self.decompose(orientation)
        var ops: [Bool] = []                       // true = horizontal flip, false = 90° clockwise turn
        if mirrorFirst { ops.append(true) }
        ops += Array(repeating: false, count: orientationTurns + edit.normalizedQuarterTurns)
        if edit.flipHorizontal { ops.append(true) }

        var transform = CGAffineTransform.identity
        var width = CGFloat(image.width), height = CGFloat(image.height)
        for isFlip in ops {
            if isFlip {
                transform = transform.concatenating(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0))
            } else {
                transform = transform.concatenating(CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width))
                swap(&width, &height)
            }
        }

        let isGray = colorSpace.model == .monochrome
        if isGray && alpha { return nil }
        var info: UInt32 = isGray ? CGImageAlphaInfo.none.rawValue
            : (alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue
        if isFloat { info |= CGBitmapInfo.floatComponents.rawValue }
        if bitsPerComponent == 16 { info |= CGBitmapInfo.byteOrder16Little.rawValue }
        if bitsPerComponent == 32 { info |= CGBitmapInfo.byteOrder32Little.rawValue }
        guard let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: 0, space: colorSpace, bitmapInfo: info) else { return nil }
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.concatenate(transform)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let upright = context.makeImage() else { return nil }
        guard let crop = cropRect(uprightWidth: upright.width, uprightHeight: upright.height) else { return upright }
        return upright.cropping(to: crop)
    }

    /// EXIF orientation as "optional horizontal mirror, then N clockwise quarter turns".
    private static func decompose(_ orientation: CGImagePropertyOrientation) -> (mirror: Bool, turns: Int) {
        switch orientation {
        case .up: (false, 0)
        case .upMirrored: (true, 0)
        case .down: (false, 2)
        case .downMirrored: (true, 2)
        case .right: (false, 1)
        case .rightMirrored: (true, 1)
        case .left: (false, 3)
        case .leftMirrored: (true, 3)
        @unknown default: (false, 0)
        }
    }
}
