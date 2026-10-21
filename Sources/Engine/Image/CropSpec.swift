import CoreGraphics

/// How to crop the upright (orientation-corrected, rotated/flipped) image.
/// Rectangles use a top-left origin.
enum CropSpec: Equatable, Sendable {
    /// Fractions (0…1) of the upright image.
    case normalized(CGRect)
    /// Exact pixels of the upright image.
    case pixels(CGRect)
    /// Largest centred rectangle with this aspect ratio.
    case aspect(AspectPreset)

    func pixelRect(width: Int, height: Int) -> CGRect {
        let full = CGRect(x: 0, y: 0, width: width, height: height)
        let w = Double(width), h = Double(height)
        let rect: CGRect = switch self {
        case .normalized(let n):
            CGRect(x: (n.minX * w).rounded(), y: (n.minY * h).rounded(),
                   width: (n.width * w).rounded(), height: (n.height * h).rounded())
        case .pixels(let p):
            p.integral
        case .aspect(let preset):
            preset.ratio(width: w, height: h).map { ImageGeometry.centeredRect(ratio: $0, width: w, height: h) } ?? full
        }
        let clipped = rect.intersection(full)
        return clipped.isNull || clipped.width < 1 || clipped.height < 1 ? full : clipped
    }
}
